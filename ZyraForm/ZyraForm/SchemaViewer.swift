//
//  SchemaViewer.swift
//  ZyraForm
//
//  Created by Michael Martell on 11/4/25.
//

import SwiftUI
import HighlightSwift
import ZyraForm

#if os(macOS)
import AppKit
#endif

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

enum SchemaFormat: String, CaseIterable {
    case zyra = "Zyra"
    case swiftData = "SwiftData"
    case zod = "Zod"
    case drizzle = "Drizzle"
    case postgres = "Postgres"
    
    var highlightLanguage: HighlightLanguage {
        switch self {
        case .zyra, .swiftData:
            return .swift
        case .zod, .drizzle:
            return .typeScript
        case .postgres:
            return .sql
        }
    }
}

struct SchemaViewer: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: SchemaFormat = .zyra
    @State private var showingPostgresContent = false
    
    let schema: ZyraTable
    let service: ZyraSync?
    
    init(schema: ZyraTable, service: ZyraSync? = nil) {
        self.schema = schema
        self.service = service
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Format selector
                Picker("Format", selection: $selectedFormat) {
                    ForEach(SchemaFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                Divider()
                
                // Code display with syntax highlighting
                ScrollView {
                    CodeText(schemaCode)
                        .highlightLanguage(selectedFormat.highlightLanguage)
                        .codeTextStyle(.card(cornerRadius: 8, verticalPadding: 12))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .id(selectedFormat) // Force refresh when format changes
                }
            }
            .background(Color(hex: "13120F"))
            .navigationTitle("Schema Viewer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItemGroup(placement: .primaryAction) {
                    if selectedFormat == .postgres {
                        Button(action: {
                            showingPostgresContent = true
                        }) {
                            Label("Generate DB Content", systemImage: "database")
                        }
                    }
                    
                    Button(action: copyToClipboard) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            }
        }
        .frame(minWidth: 600, idealWidth: 900, maxWidth: .infinity, minHeight: 400, idealHeight: 600, maxHeight: .infinity)
        .background(Color(hex: "13120F"))
        .sheet(isPresented: $showingPostgresContent) {
            PostgresContentView(schema: schema, service: service)
        }
    }
    
    private var schemaCode: String {
        switch selectedFormat {
        case .zyra:
            return generateZyraSchema()
        case .swiftData:
            return schema.generateSwiftModelFile()
        case .zod:
            return schema.generateZodSchema()
        case .drizzle:
            return schema.generateDrizzleSchema(includeImports: true)
        case .postgres:
            return schema.generateCreateTableSQLOnly()
        }
    }
    
    private func generateZyraSchema() -> String {
        var code = "let schema = ZyraTable(\n"
        code += "  name: \"\(schema.name)\",\n"
        code += "  primaryKey: \"\(schema.primaryKey)\",\n"
        code += "  columns: [\n"
        
        var columnDefs: [String] = []
        for column in schema.columns {
            if column.name == schema.primaryKey || column.name == "created_at" || column.name == "updated_at" {
                continue // Skip auto-generated columns
            }
            
            var def = "      zf."
            
            switch column.swiftType {
            case .string, .uuid:
                def += "text(\"\(column.name)\")"
            case .integer:
                def += "integer(\"\(column.name)\")"
            case .double:
                def += "real(\"\(column.name)\")"
            default:
                def += "text(\"\(column.name)\")"
            }
            
            // Add validations
            if column.isEmail == true {
                def += ".email()"
            }
            
            if column.isUrl == true {
                def += ".url()"
            }
            
            if let minLength = column.minLength {
                def += ".minLength(\(minLength))"
            }
            
            if let maxLength = column.maxLength {
                def += ".maxLength(\(maxLength))"
            }
            
            if let intMin = column.intMin {
                def += ".intMin(\(intMin))"
            }
            
            if let intMax = column.intMax {
                def += ".intMax(\(intMax))"
            }
            
            if column.isPositive == true {
                def += ".positive()"
            }
            
            if !column.isNullable {
                def += ".notNull()"
            } else {
                def += ".nullable()"
            }
            
            columnDefs.append(def)
        }
        
        code += columnDefs.joined(separator: ",\n")
        code += "\n  ]\n"
        code += ")\n"
        
        return code
    }
    
    private func copyToClipboard() {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(schemaCode, forType: .string)
        #else
        UIPasteboard.general.string = schemaCode
        #endif
    }
}

// MARK: - Postgres Content View

struct PostgresContentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var generatedContent: String = ""
    @State private var isLoading = true
    
    let schema: ZyraTable
    let service: ZyraSync?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView("Generating Postgres content...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        CodeText(generatedContent)
                            .highlightLanguage(.sql)
                            .codeTextStyle(.card(cornerRadius: 8, verticalPadding: 12))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                }
            }
            .background(Color(hex: "13120F"))
            .navigationTitle("Postgres DB Content")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: copyToClipboard) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            }
        }
        .frame(minWidth: 800, idealWidth: 1000, maxWidth: .infinity, minHeight: 500, idealHeight: 700, maxHeight: .infinity)
        .background(Color(hex: "13120F"))
        .task {
            await generatePostgresContent()
        }
    }
    
    private func generatePostgresContent() async {
        isLoading = true
        
        var content = ""
        
        // Generate CREATE TABLE statement
        content += "-- Create Table\n"
        content += schema.generateCreateTableSQLOnly()
        content += "\n\n"
        
        // Generate trigger if updated_at exists
        if let triggerSQL = schema.generateUpdatedAtTriggerOnly() {
            content += "-- Create Trigger\n"
            content += triggerSQL
            content += "\n\n"
        }
        
        // Generate INSERT statements if service and records are available
        if let service = service, !service.records.isEmpty {
            content += "-- Insert Data\n"
            
            // Get column metadata for type checking
            let columnMap = Dictionary(uniqueKeysWithValues: schema.columns.map { ($0.name, $0) })
            let columnNames = schema.columns.map { $0.name }
            
            for record in service.records {
                var values: [String] = []
                var insertColumns: [String] = []
                
                for columnName in columnNames {
                    guard let column = columnMap[columnName] else { continue }
                    
                    if let value = record[columnName] {
                        insertColumns.append(columnName)
                        
                        // Format value based on column type
                        let formattedValue: String
                        if value is NSNull {
                            formattedValue = "NULL"
                        } else {
                            switch column.swiftType {
                            case .uuid:
                                // UUIDs are stored as TEXT, but we can cast them if they look like UUIDs
                                if let stringValue = value as? String {
                                    let escaped = stringValue.replacingOccurrences(of: "'", with: "''")
                                    formattedValue = "'\(escaped)'"
                                } else {
                                    let stringValue = String(describing: value)
                                    let escaped = stringValue.replacingOccurrences(of: "'", with: "''")
                                    formattedValue = "'\(escaped)'"
                                }
                            case .date:
                                // Dates should be formatted as timestamps
                                if let stringValue = value as? String {
                                    // If it's already ISO8601 format, use it directly
                                    formattedValue = "'\(stringValue)'"
                                } else {
                                    let stringValue = String(describing: value)
                                    formattedValue = "'\(stringValue)'"
                                }
                            case .integer:
                                if let intValue = value as? Int {
                                    formattedValue = "\(intValue)"
                                } else if let stringValue = value as? String, let intValue = Int(stringValue) {
                                    formattedValue = "\(intValue)"
                                } else {
                                    formattedValue = "NULL"
                                }
                            case .double:
                                if let doubleValue = value as? Double {
                                    formattedValue = "\(doubleValue)"
                                } else if let intValue = value as? Int {
                                    formattedValue = "\(Double(intValue))"
                                } else if let stringValue = value as? String, let doubleValue = Double(stringValue) {
                                    formattedValue = "\(doubleValue)"
                                } else {
                                    formattedValue = "NULL"
                                }
                            case .boolean:
                                if let boolValue = value as? Bool {
                                    formattedValue = boolValue ? "true" : "false"
                                } else if let intValue = value as? Int {
                                    formattedValue = intValue != 0 ? "true" : "false"
                                } else if let stringValue = value as? String {
                                    let lowercased = stringValue.lowercased()
                                    formattedValue = (lowercased == "true" || lowercased == "1" || lowercased == "yes") ? "true" : "false"
                                } else {
                                    formattedValue = "false"
                                }
                            default:
                                // String or other types
                                if let stringValue = value as? String {
                                    let escaped = stringValue.replacingOccurrences(of: "'", with: "''")
                                    formattedValue = "'\(escaped)'"
                                } else {
                                    let stringValue = String(describing: value)
                                    let escaped = stringValue.replacingOccurrences(of: "'", with: "''")
                                    formattedValue = "'\(escaped)'"
                                }
                            }
                        }
                        
                        values.append(formattedValue)
                    } else {
                        // Handle NULL values based on column nullability
                        if column.isNullable {
                            insertColumns.append(columnName)
                            values.append("NULL")
                        }
                        // Skip NOT NULL columns if value is missing (might cause error, but user can fix)
                    }
                }
                
                if !insertColumns.isEmpty {
                    let columnsString = insertColumns.map { "\"\($0)\"" }.joined(separator: ", ")
                    let valuesString = values.joined(separator: ", ")
                    
                    content += "INSERT INTO \"\(schema.name)\" (\(columnsString)) VALUES (\(valuesString));\n"
                }
            }
        }
        
        await MainActor.run {
            generatedContent = content
            isLoading = false
        }
    }
    
    private func copyToClipboard() {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(generatedContent, forType: .string)
        #else
        UIPasteboard.general.string = generatedContent
        #endif
    }
}

#Preview {
    SchemaViewer(schema: schema, service: nil)
}

