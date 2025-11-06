//
//  EmployeeFormView.swift
//  ZyraForm
//
//  Created by Michael Martell on 11/4/25.
//

import SwiftUI
import Foundation
import ZyraForm

// MARK: - Generic Form View

struct EmployeeFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var service: ZyraSync
    let table: ZyraTable
    
    let recordId: String?
    let onSave: (() -> Void)?
    
    @State private var formValues: [String: String] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let config: TableFieldConfig
    private let displayName: String
    
    init(table: ZyraTable, service: ZyraSync, recordId: String? = nil, onSave: (() -> Void)? = nil) {
        self.table = table
        self.service = service
        self.recordId = recordId
        self.onSave = onSave
        self.config = table.toTableFieldConfig()
        self.displayName = TableRegistry.shared.displayName(for: table)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("\(displayName) Information") {
                    ForEach(getEditableColumns(), id: \.name) { column in
                        fieldView(for: column)
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(recordId == nil ? "New \(displayName)" : "Edit \(displayName)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveRecord()
                        }
                    }
                    .disabled(!isFormValid || isLoading)
                }
            }
            .task {
                if let recordId = recordId {
                    await loadRecord(id: recordId)
                } else {
                    // Initialize form values for new record
                    initializeFormValues()
                }
            }
        }
    }
    
    private func getEditableColumns() -> [ColumnMetadata] {
        // Skip system columns (id, user_id, created_at, updated_at)
        return table.columns.filter { column in
            let name = column.name
            return name != "id" && 
                   name != table.primaryKey && 
                   name != "user_id" && 
                   name != "created_at" && 
                   name != "updated_at"
        }
    }
    
    @ViewBuilder
    private func fieldView(for column: ColumnMetadata) -> some View {
        let binding = Binding(
            get: { formValues[column.name] ?? "" },
            set: { formValues[column.name] = $0 }
        )
        
        VStack(alignment: .leading, spacing: 4) {
            Text(column.name.capitalized + (column.isNullable ? " (Optional)" : ""))
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextField(placeholder(for: column), text: binding)
                .textContentType(textContentType(for: column))
                .autocorrectionDisabled(shouldDisableAutocorrection(for: column))
            
            if let error = validationError(for: column, value: binding.wrappedValue) {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    private func placeholder(for column: ColumnMetadata) -> String {
        if column.isEmail == true {
            return "email@example.com"
        } else if column.isUrl == true {
            return "https://example.com"
        } else if column.swiftType == .integer {
            return "0"
        } else {
            return column.name
        }
    }
    
    private func textContentType(for column: ColumnMetadata) -> UITextContentType? {
        if column.isEmail == true {
            return .emailAddress
        } else if column.isUrl == true {
            return .URL
        }
        return nil
    }
    
    private func shouldDisableAutocorrection(for column: ColumnMetadata) -> Bool {
        return column.isEmail == true || column.isUrl == true
    }
    
    private func validationError(for column: ColumnMetadata, value: String) -> String? {
        // Skip validation for empty optional fields
        if column.isNullable && value.isEmpty {
            return nil
        }
        
        // Required field validation
        if !column.isNullable && value.isEmpty {
            return "\(column.name.capitalized) is required"
        }
        
        // Email validation
        if column.isEmail == true && !value.isEmpty && !isValidEmail(value) {
            return "Please enter a valid email address"
        }
        
        // URL validation
        if column.isUrl == true && !value.isEmpty && !isValidURL(value) {
            return "Please enter a valid URL"
        }
        
        // Integer validation
        if column.swiftType == .integer && !value.isEmpty {
            if let intValue = Int(value) {
                if let min = column.intMin, intValue < min {
                    return "Must be at least \(min)"
                }
                if let max = column.intMax, intValue > max {
                    return "Must be \(max) or less"
                }
                if column.isPositive == true && intValue <= 0 {
                    return "Must be positive"
                }
            } else {
                return "Please enter a valid number"
            }
        }
        
        // Length validation
        if let minLength = column.minLength, value.count < minLength {
            return "Must be at least \(minLength) characters"
        }
        if let maxLength = column.maxLength, value.count > maxLength {
            return "Must be \(maxLength) characters or less"
        }
        
        return nil
    }
    
    private var isFormValid: Bool {
        for column in getEditableColumns() {
            let value = formValues[column.name] ?? ""
            
            // Check required fields
            if !column.isNullable && value.isEmpty {
                return false
            }
            
            // Skip validation if empty and nullable
            if column.isNullable && value.isEmpty {
                continue
            }
            
            // Email validation
            if column.isEmail == true && !isValidEmail(value) {
            return false
        }
        
            // URL validation
            if column.isUrl == true && !isValidURL(value) {
                return false
            }
            
            // Integer validation
            if column.swiftType == .integer, let intValue = Int(value) {
                if let min = column.intMin, intValue < min {
                    return false
                }
                if let max = column.intMax, intValue > max {
                    return false
                }
                if column.isPositive == true && intValue <= 0 {
                    return false
                }
            } else if column.swiftType == .integer && !value.isEmpty {
                return false // Invalid integer
            }
            
            // Length validation
            if let minLength = column.minLength, value.count < minLength {
                return false
            }
            if let maxLength = column.maxLength, value.count > maxLength {
                return false
            }
        }
        
        return true
    }
    
    private func initializeFormValues() {
        formValues = [:]
        for column in getEditableColumns() {
            if let defaultValue = column.defaultValue {
                formValues[column.name] = defaultValue
            } else {
                formValues[column.name] = ""
            }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              url.scheme != nil,
              url.host != nil else {
            return false
        }
        return true
    }
    
    private func loadRecord(id: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await service.loadRecords(
                fields: config.allFields,
                whereClause: "id = ?",
                parameters: [id],
                orderBy: config.defaultOrderBy,
                encryptedFields: config.encryptedFields,
                integerFields: config.integerFields,
                booleanFields: config.booleanFields
            )
            
            if let record = service.records.first {
                await MainActor.run {
                    // Convert record to form values
                    formValues = [:]
                    for column in getEditableColumns() {
                        if let value = record[column.name] {
                            if let intValue = value as? Int {
                                formValues[column.name] = String(intValue)
                            } else if let boolValue = value as? Bool {
                                formValues[column.name] = boolValue ? "true" : "false"
                            } else {
                                formValues[column.name] = String(describing: value)
                            }
                        } else {
                            formValues[column.name] = ""
                        }
                    }
                    isLoading = false
                }
            } else {
                await MainActor.run {
                    errorMessage = "Record not found"
                    isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
            PrintDebug("Failed to load record: \(error)", debug: true)
        }
    }
    
    private func saveRecord() async {
        guard isFormValid else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            var fields: [String: Any] = [:]
            
            // Convert form values to dictionary
            for column in getEditableColumns() {
                let value = formValues[column.name] ?? ""
                
                if value.isEmpty && column.isNullable {
                    continue // Skip empty nullable fields
                }
                
                if column.swiftType == .integer, let intValue = Int(value) {
                    fields[column.name] = intValue
                } else if column.swiftType == .boolean {
                    fields[column.name] = value.lowercased() == "true" || value == "1"
                } else if !value.isEmpty {
                    fields[column.name] = value
                }
            }
            
            if let recordId = recordId {
                // Update existing record
                try await service.updateRecord(
                    id: recordId,
                    fields: fields,
                    encryptedFields: config.encryptedFields,
                    autoTimestamp: true
                )
            } else {
                // Create new record
                _ = try await service.createRecord(
                    fields: fields,
                    encryptedFields: config.encryptedFields,
                    autoGenerateId: true,
                    autoTimestamp: true
                )
            }
            
            await MainActor.run {
                isLoading = false
                dismiss()
                onSave?() // Trigger list refresh
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
            PrintDebug("Failed to save record: \(error)", debug: true)
        }
    }
}

#Preview {
    EmployeeFormView(
        table: schema,
        service: ZyraSync(
            tableName: "\(AppConfig.dbPrefix)employees",
            userId: AppConfig.userId,
            database: ZyraFormManager.shared?.database ?? PowerSyncDatabase(
                schema: PowerSync.Schema(tables: []),
                dbFilename: "preview.sqlite"
            )
        )
    )
}

