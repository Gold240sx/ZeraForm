//
//  EmployeesListView.swift
//  ZyraForm
//
//  Created by Michael Martell on 11/4/25.
//

import SwiftUI
import ZyraForm

// MARK: - Table Registry

struct TableRegistry {
    static let shared = TableRegistry()
    
    var tables: [ZyraTable] {
        return [schema] // Start with just employees, can add more tables here
    }
    
    func table(named name: String) -> ZyraTable? {
        return tables.first { $0.name == name }
    }
    
    func displayName(for table: ZyraTable) -> String {
        // Remove prefix and convert to readable name
        let nameWithoutPrefix = table.name.replacingOccurrences(of: AppConfig.dbPrefix, with: "")
        return nameWithoutPrefix.capitalized
    }
}

struct EmployeesListView: View {
    @State private var selectedTable: ZyraTable
    @State private var service: ZyraSync
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasLoadedOnce = false
    @State private var showingAddSheet = false
    @State private var selectedEmployeeId: String?
    @State private var showingEditSheet = false
    @State private var showingSchemaViewer = false
    @State private var selectedSchemaFormat: SchemaFormat = .zyra
    
    // Cache the config to avoid accessing schema during view updates
    private var config: TableFieldConfig {
        return selectedTable.toTableFieldConfig()
    }
    
    init() {
        let initialTable = TableRegistry.shared.tables.first ?? schema
        guard let manager = ZyraFormManager.shared else {
            fatalError("ZyraFormManager must be initialized before using EmployeesListView")
        }
        let initialService = ZyraSync(
            tableName: initialTable.name,
            userId: manager.config.userId,
            database: manager.database
        )
        _selectedTable = State(initialValue: initialTable)
        _service = State(initialValue: initialService)
    }
    
    var body: some View {
        NavigationSplitView {
            // Left sidebar: List of names
            sidebarView
        } detail: {
            // Right side: Selected employee details
            detailView
        }
        .sheet(isPresented: $showingAddSheet) {
            EmployeeFormView(
                table: selectedTable,
                service: service,
                onSave: {
                    Task { await loadRecords() }
                    showingAddSheet = false
                }
            )
        }
        .sheet(isPresented: $showingEditSheet) {
            if let employeeId = selectedEmployeeId {
                EmployeeFormView(
                    table: selectedTable,
                    service: service,
                    recordId: employeeId,
                    onSave: {
                        Task { await loadRecords() }
                        showingEditSheet = false
                    }
                )
            }
        }
        .sheet(isPresented: $showingSchemaViewer) {
            SchemaFormatSelector(
                selectedFormat: $selectedSchemaFormat,
                schema: selectedTable
            )
        }
        .onChange(of: selectedTable) { oldTable, newTable in
            // Recreate service when table changes
            guard let manager = ZyraFormManager.shared else { return }
            service = ZyraSync(
                tableName: newTable.name,
                userId: manager.config.userId,
                database: manager.database
            )
            // Reset state and reload
            hasLoadedOnce = false
            selectedEmployeeId = nil
            Task {
                await loadRecords()
            }
        }
        .task {
            if !hasLoadedOnce {
                await loadRecords()
            }
        }
    }
    
    // MARK: - Sidebar View
    
    private var sidebarView: some View {
        VStack(spacing: 0) {
            // Table selector dropdown
            Picker("Table", selection: $selectedTable) {
                ForEach(TableRegistry.shared.tables, id: \.name) { table in
                    Text(TableRegistry.shared.displayName(for: table))
                        .tag(table)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal)
            .padding(.top, 8)
            
            Divider()
            
            // Content
            Group {
                if isLoading && !hasLoadedOnce {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text("Error loading records")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Retry") {
                            Task {
                                await loadRecords()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if service.records.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tablecells")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No records yet")
                            .font(.headline)
                        Text("Add your first record to get started")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $selectedEmployeeId) {
                        ForEach(Array(service.records.enumerated()), id: \.offset) { index, record in
                            EmployeeNameRow(
                                employee: record,
                                onDelete: {
                                    if let id = record["id"] as? String {
                                        Task {
                                            await deleteRecord(id: id)
                                        }
                                    }
                                }
                            )
                            .tag(record["id"] as? String)
                            .id(record["id"] as? String ?? "\(index)")
                        }
                    }
                    .refreshable {
                        await loadRecords()
                    }
                }
            }
        }
        .navigationTitle(TableRegistry.shared.displayName(for: selectedTable))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showingAddSheet = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
    }
    
    @ViewBuilder
    private var detailView: some View {
        if showingSchemaViewer {
            SchemaCodeView(
                schema: selectedTable,
                service: service,
                selectedFormat: $selectedSchemaFormat,
                onClose: {
                    showingSchemaViewer = false
                }
            )
        } else if let selectedId = selectedEmployeeId,
           let record = service.records.first(where: { ($0["id"] as? String) == selectedId }) {
            EmployeeDetailView(
                employee: record,
                onEdit: {
                    selectedEmployeeId = selectedId
                    showingEditSheet = true
                },
                onSchemaView: {
                    showingSchemaViewer = true
                }
            )
        } else {
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 50))
                    .foregroundColor(.secondary)
                Text("Select a record")
                    .font(.headline)
                Text("Choose a record from the list to view details")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingSchemaViewer = true
                    }) {
                        Label("Schema", systemImage: "doc.text")
                    }
                }
            }
        }
    }
    
    private func loadRecords() async {
        guard !isLoading else { return } // Prevent concurrent loads
        isLoading = true
        errorMessage = nil
        
        do {
            try await service.loadRecords(
                fields: config.allFields,
                whereClause: "1 = 1", // Always true condition to load all records (no user_id filter)
                orderBy: config.defaultOrderBy,
                encryptedFields: config.encryptedFields,
                integerFields: config.integerFields,
                booleanFields: config.booleanFields
            )
            
            await MainActor.run {
                isLoading = false
                hasLoadedOnce = true
                selectedEmployeeId = nil // Clear selection when switching tables
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
                hasLoadedOnce = true
            }
            PrintDebug("Failed to load records: \(error)", debug: true)
        }
    }
    
    private func deleteRecord(id: String) async {
        do {
            try await service.deleteRecord(id: id)
            
            // Clear selection if deleted record was selected
            if selectedEmployeeId == id {
                await MainActor.run {
                    selectedEmployeeId = nil
                }
            }
            
            // Reload records after deletion
            await loadRecords()
        } catch {
            PrintDebug("Failed to delete record \(id): \(error)", debug: true)
            await MainActor.run {
                errorMessage = "Failed to delete record: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Employee Name Row (Left Sidebar)

struct EmployeeNameRow: View {
    let employee: [String: Any]
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Text(employee["name"] as? String ?? "Unknown")
                .font(.headline)
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Employee Detail View (Right Side)

struct EmployeeDetailView: View {
    let employee: [String: Any]
    let onEdit: () -> Void
    let onSchemaView: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(employee["name"] as? String ?? "Unknown")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        if let email = employee["email"] as? String, !email.isEmpty {
                            Text(email)
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                
                Divider()
                
                // Details
                VStack(alignment: .leading, spacing: 16) {
                    // Age
                    if let age = employee["age"] as? Int {
                        DetailRow(label: "Age", value: "\(age)")
                    }
                    
                    // Website
                    if let website = employee["website"] as? String, !website.isEmpty {
                        DetailRow(label: "Website") {
                            Link(website, destination: URL(string: website) ?? URL(string: "https://example.com")!)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Divider()
                    
                    // Dates
                    if let createdAt = employee["created_at"] as? String {
                        DetailRow(label: "Created", value: formatDate(createdAt))
                    }
                    
                    if let updatedAt = employee["updated_at"] as? String {
                        DetailRow(label: "Updated", value: formatDate(updatedAt))
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Employee Details")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onSchemaView) {
                    Label("Schema", systemImage: "doc.text")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - Detail Row Component

struct DetailRow<Content: View>: View {
    let label: String
    let content: Content
    
    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension DetailRow where Content == Text {
    init(label: String, value: String) {
        self.label = label
        self.content = Text(value)
    }
}

#Preview {
    EmployeesListView()
}

