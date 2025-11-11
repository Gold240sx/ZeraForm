//
//  ZyraMultiTableForm.swift
//  ZyraForm
//
//  Multi-table form support for forms that post to multiple tables
//

import Foundation
import SwiftUI
import Combine
import PowerSync

// MARK: - Multi-Table Form Configuration

/// Configuration for a table in a multi-table form
public struct TableFormConfig {
    public let table: ZyraTable
    public let fields: [String]
    
    public init(table: ZyraTable, fields: [String]) {
        self.table = table
        self.fields = fields
    }
}

/// Relationship configuration between tables in multi-table forms
public enum TableRelationship {
    /// First table's ID is used as foreign key in second table
    case firstToSecond(foreignKey: String)
    /// Custom dependency: second table depends on first table's result
    case custom(dependency: (String, String) -> [String: Any])
}

// MARK: - Multi-Table Form

/// Form that validates and submits to multiple tables
@MainActor
public class ZyraMultiTableForm: ObservableObject {
    // MARK: - Published Properties
    
    @Published public private(set) var values: [String: Any] = [:]
    @Published public private(set) var errors = FormErrors()
    @Published public private(set) var isValid: Bool = false
    @Published public private(set) var isDirty: Bool = false
    @Published public private(set) var isSubmitting: Bool = false
    
    // MARK: - Private Properties
    
    private let tables: [TableFormConfig]
    private let relationship: TableRelationship?
    private var fieldToTable: [String: ZyraTable] = [:]
    private var validationMode: FormValidationMode = .onChange
    private var touchedFields: Set<String> = []
    
    // MARK: - Initialization
    
    /// Initialize with multiple table configurations
    /// - Parameters:
    ///   - tables: Array of table configurations (table schema + fields to include)
    ///   - relationship: Optional relationship between tables (for foreign key handling)
    public init(
        tables: [TableFormConfig],
        relationship: TableRelationship? = nil,
        mode: FormValidationMode = .onChange
    ) {
        self.tables = tables
        self.relationship = relationship
        self.validationMode = mode
        
        // Build field-to-table mapping
        for config in tables {
            for field in config.fields {
                fieldToTable[field] = config.table
            }
        }
    }
    
    /// Convenience initializer with simple table array
    public init(
        schemas: [(table: ZyraTable, fields: [String])],
        relationship: TableRelationship? = nil
    ) {
        self.tables = schemas.map { TableFormConfig(table: $0.table, fields: $0.fields) }
        self.relationship = relationship
        
        for config in self.tables {
            for field in config.fields {
                fieldToTable[field] = config.table
            }
        }
    }
    
    // MARK: - Values Management
    
    public func setValue(_ value: Any?, for field: String) {
        values[field] = value
        isDirty = true
        touchedFields.insert(field)
        
        // Validate based on mode
        switch validationMode {
        case .onChange:
            _ = validateField(field)
        case .onTouched:
            if touchedFields.contains(field) {
                _ = validateField(field)
            }
        default:
            break
        }
    }
    
    public func getValue(for field: String) -> Any? {
        return values[field]
    }
    
    public func getValues() -> [String: Any] {
        return values
    }
    
    // MARK: - Validation
    
    @discardableResult
    public func validate() -> Bool {
        var isValid = true
        
        for (field, _) in fieldToTable {
            if !validateField(field) {
                isValid = false
            }
        }
        
        self.isValid = isValid
        return isValid
    }
    
    @discardableResult
    public func validateField(_ field: String) -> Bool {
        guard let table = fieldToTable[field],
              let column = table.columns.first(where: { $0.name == field }) else {
            return true
        }
        
        let value = getValue(for: field)
        let error = ZyraValidation.validate(value, against: column)
        
        if let error = error {
            errors.set(error, for: field)
            isValid = errors.errors.isEmpty
            return false
        } else {
            errors.remove(field)
            isValid = errors.errors.isEmpty
            return true
        }
    }
    
    // MARK: - Submission
    
    /// Submit form data to multiple tables
    /// Returns a dictionary mapping table names to their created record IDs
    public func submit(
        userId: String,
        database: PowerSync.PowerSyncDatabaseProtocol
    ) async throws -> [String: String] {
        guard validate() else {
            throw NSError(domain: "ZyraMultiTableForm", code: 400, userInfo: [NSLocalizedDescriptionKey: "Form validation failed"])
        }
        
        isSubmitting = true
        defer { isSubmitting = false }
        
        var results: [String: String] = [:]
        
        // Split form data by table
        var tableData: [String: [String: Any]] = [:]
        for config in tables {
            var data: [String: Any] = [:]
            for field in config.fields {
                if let value = values[field] {
                    data[field] = value
                }
            }
            if !data.isEmpty {
                tableData[config.table.name] = data
            }
        }
        
        // Submit to tables in order
        for (index, config) in tables.enumerated() {
            guard let data = tableData[config.table.name] else { continue }
            
            let service = ZyraSync(
                tableName: config.table.name,
                userId: userId,
                database: database
            )
            
            let tableConfig = config.table.toTableFieldConfig()
            
            let recordId = try await service.createRecord(
                fields: data,
                encryptedFields: tableConfig.encryptedFields,
                autoGenerateId: true,
                autoTimestamp: true
            )
            
            results[config.table.name] = recordId
            
            // Handle relationships
            if let relationship = relationship, index < tables.count - 1 {
                let nextConfig = tables[index + 1]
                switch relationship {
                case .firstToSecond(let foreignKey):
                    // Add foreign key to next table's data
                    if var nextData = tableData[nextConfig.table.name] {
                        nextData[foreignKey] = recordId
                        tableData[nextConfig.table.name] = nextData
                    }
                case .custom(let dependency):
                    // Custom dependency handling
                    let dependencyData = dependency(config.table.name, recordId)
                    if var nextData = tableData[nextConfig.table.name] {
                        nextData.merge(dependencyData) { (_, new) in new }
                        tableData[nextConfig.table.name] = nextData
                    }
                }
            }
        }
        
        return results
    }
    
    /// Submit with typed models (requires ZyraModel types)
    public func submit<PublicModel: ZyraModel, PrivateModel: ZyraModel>(
        publicType: PublicModel.Type,
        privateType: PrivateModel.Type,
        userId: String,
        database: PowerSync.PowerSyncDatabaseProtocol
    ) async throws -> (publicId: String, privateId: String) {
        guard tables.count == 2 else {
            throw NSError(domain: "ZyraMultiTableForm", code: 400, userInfo: [NSLocalizedDescriptionKey: "Expected 2 tables for typed submission"])
        }
        
        guard validate() else {
            throw NSError(domain: "ZyraMultiTableForm", code: 400, userInfo: [NSLocalizedDescriptionKey: "Form validation failed"])
        }
        
        isSubmitting = true
        defer { isSubmitting = false }
        
        // Get data for public table
        let publicConfig = tables[0]
        var publicData: [String: Any] = [:]
        for field in publicConfig.fields {
            if let value = values[field] {
                publicData[field] = value
            }
        }
        
        // Create public record first
        let publicService = ZyraSync(
            tableName: publicConfig.table.name,
            userId: userId,
            database: database
        )
        
        let publicId = try await publicService.createRecord(
            fields: publicData,
            encryptedFields: publicConfig.table.toTableFieldConfig().encryptedFields,
            autoGenerateId: true,
            autoTimestamp: true
        )
        
        // Get data for private table
        let privateConfig = tables[1]
        var privateData: [String: Any] = [:]
        for field in privateConfig.fields {
            if let value = values[field] {
                privateData[field] = value
            }
        }
        
        // Add foreign key reference
        if let relationship = relationship {
            switch relationship {
            case .firstToSecond(let foreignKey):
                privateData[foreignKey] = publicId
            case .custom(let dependency):
                let depData = dependency(publicConfig.table.name, publicId)
                privateData.merge(depData) { (_, new) in new }
            }
        }
        
        // Create private record
        let privateService = ZyraSync(
            tableName: privateConfig.table.name,
            userId: userId,
            database: database
        )
        
        let privateId = try await privateService.createRecord(
            fields: privateData,
            encryptedFields: privateConfig.table.toTableFieldConfig().encryptedFields,
            autoGenerateId: true,
            autoTimestamp: true
        )
        
        return (publicId, privateId)
    }
    
    /// Submit form data to multiple tables using SchemaBasedSync
    /// Returns SchemaRecords for each created table
    public func submitWithSchemaRecords(
        userId: String,
        database: PowerSync.PowerSyncDatabaseProtocol
    ) async throws -> [String: SchemaRecord] {
        guard validate() else {
            throw NSError(domain: "ZyraMultiTableForm", code: 400, userInfo: [NSLocalizedDescriptionKey: "Form validation failed"])
        }
        
        isSubmitting = true
        defer { isSubmitting = false }
        
        var results: [String: SchemaRecord] = [:]
        
        // Split form data by table
        var tableData: [String: [String: Any]] = [:]
        for config in tables {
            var data: [String: Any] = [:]
            for field in config.fields {
                if let value = values[field] {
                    data[field] = value
                }
            }
            if !data.isEmpty {
                tableData[config.table.name] = data
            }
        }
        
        // Submit to tables in order using SchemaBasedSync
        for (index, config) in tables.enumerated() {
            guard let data = tableData[config.table.name] else { continue }
            
            let service = SchemaBasedSync(
                schema: config.table,
                userId: userId,
                database: database
            )
            
            // Create SchemaRecord from form data
            let record = config.table.createRecord(from: data)
            
            let recordId = try await service.createRecord(
                record,
                autoGenerateId: true,
                autoTimestamp: true
            )
            
            // Reload to get the full record with generated fields
            try await service.loadRecords(
                whereClause: "\(config.table.primaryKey) = ?",
                parameters: [recordId]
            )
            
            if let createdRecord = service.records.first {
                results[config.table.name] = createdRecord
            }
            
            // Handle relationships
            if let relationship = relationship, index < tables.count - 1 {
                let nextConfig = tables[index + 1]
                switch relationship {
                case .firstToSecond(let foreignKey):
                    // Add foreign key to next table's data
                    if var nextData = tableData[nextConfig.table.name] {
                        nextData[foreignKey] = recordId
                        tableData[nextConfig.table.name] = nextData
                    }
                case .custom(let dependency):
                    // Custom dependency handling
                    let dependencyData = dependency(config.table.name, recordId)
                    if var nextData = tableData[nextConfig.table.name] {
                        nextData.merge(dependencyData) { (_, new) in new }
                        tableData[nextConfig.table.name] = nextData
                    }
                }
            }
        }
        
        return results
    }
    
    /// Get current form values as SchemaRecords (one per table)
    /// Useful for previewing what will be submitted
    public func getCurrentRecords() -> [String: SchemaRecord] {
        var records: [String: SchemaRecord] = [:]
        
        for config in tables {
            var data: [String: Any] = [:]
            for field in config.fields {
                if let value = values[field] {
                    data[field] = value
                }
            }
            if !data.isEmpty {
                records[config.table.name] = config.table.createRecord(from: data)
            }
        }
        
        return records
    }
    
    // MARK: - Simplified Loading & Extraction
    
    /// Load form values from SchemaRecords
    /// Automatically populates form fields based on table configurations
    /// - Parameter records: Dictionary mapping table names to their SchemaRecords
    public func loadFromRecords(_ records: [String: SchemaRecord]) {
        for config in tables {
            guard let record = records[config.table.name] else { continue }
            
            // Populate form fields from record
            for field in config.fields {
                // Get value from record using schema-aware type conversion
                if let column = config.table.columns.first(where: { $0.name == field }) {
                    // Handle different types appropriately
                    if column.type == .integer {
                        if let intValue = record.get(field, as: Int.self) {
                            setValue(intValue, for: field)
                        } else if let strValue = record.get(field, as: String.self), let intValue = Int(strValue) {
                            setValue(intValue, for: field)
                        }
                    } else if column.type == .double {
                        if let doubleValue = record.get(field, as: Double.self) {
                            setValue(doubleValue, for: field)
                        } else if let strValue = record.get(field, as: String.self), let doubleValue = Double(strValue) {
                            setValue(doubleValue, for: field)
                        }
                    } else if column.type == .boolean {
                        if let boolValue = record.get(field, as: Bool.self) {
                            setValue(boolValue ? "true" : "false", for: field)
                        } else if let strValue = record.get(field, as: String.self) {
                            setValue(strValue, for: field)
                        }
                    } else {
                        // String, enum, uuid, etc.
                        if let strValue = record.get(field, as: String.self) {
                            setValue(strValue, for: field)
                        }
                    }
                }
            }
        }
        
        // Validate after loading
        _ = validate()
    }
    
    /// Convenience method to load from an array of records (in table order)
    /// - Parameter records: Array of SchemaRecords matching the table order
    public func loadFromRecords(_ records: [SchemaRecord]) {
        var recordDict: [String: SchemaRecord] = [:]
        for (index, record) in records.enumerated() {
            if index < tables.count {
                recordDict[tables[index].table.name] = record
            }
        }
        loadFromRecords(recordDict)
    }
    
    /// Get form values for a specific table
    /// Automatically extracts only fields that belong to the specified table
    /// - Parameter tableName: The name of the table
    /// - Returns: Dictionary of field names to values for that table
    public func getTableData(tableName: String) -> [String: Any] {
        guard let config = tables.first(where: { $0.table.name == tableName }) else {
            return [:]
        }
        
        var data: [String: Any] = [:]
        for field in config.fields {
            if let value = values[field] {
                data[field] = value
            }
        }
        return data
    }
    
    /// Get form values for all tables
    /// Returns a dictionary mapping table names to their field data
    /// - Returns: Dictionary mapping table names to their field data dictionaries
    public func getAllTableData() -> [String: [String: Any]] {
        var result: [String: [String: Any]] = [:]
        for config in tables {
            result[config.table.name] = getTableData(tableName: config.table.name)
        }
        return result
    }
    
    /// Update existing records using SchemaBasedSync services
    /// Automatically handles multi-table updates with proper foreign key relationships
    /// - Parameters:
    ///   - recordIds: Dictionary mapping table names to their record IDs
    ///   - userId: User ID for the sync services
    ///   - database: PowerSync database instance
    /// - Throws: Error if update fails
    public func updateWithSchemaRecords(
        recordIds: [String: String],
        userId: String,
        database: PowerSync.PowerSyncDatabaseProtocol
    ) async throws {
        guard validate() else {
            throw NSError(domain: "ZyraMultiTableForm", code: 400, userInfo: [NSLocalizedDescriptionKey: "Form validation failed"])
        }
        
        isSubmitting = true
        defer { isSubmitting = false }
        
        // Get all table data
        let allTableData = getAllTableData()
        
        // Update tables in order
        for (index, config) in tables.enumerated() {
            guard let recordId = recordIds[config.table.name],
                  let data = allTableData[config.table.name] else { continue }
            
            let service = SchemaBasedSync(
                schema: config.table,
                userId: userId,
                database: database,
                watchForUpdates: false
            )
            
            // Load existing record
            try await service.loadRecords(
                whereClause: "\(config.table.primaryKey) = ?",
                parameters: [recordId]
            )
            
            guard let existingRecord = service.records.first else {
                throw NSError(domain: "ZyraMultiTableForm", code: 404, userInfo: [NSLocalizedDescriptionKey: "Record not found: \(config.table.name):\(recordId)"])
            }
            
            // Update record with form data
            let updatedRecord = existingRecord.setting(data)
            try await service.updateRecord(updatedRecord)
            
            // Handle relationships for next table
            if let relationship = relationship, index < tables.count - 1 {
                let nextConfig = tables[index + 1]
                // Foreign key is already set in the data, so no action needed
                // The relationship is handled by the form configuration
            }
        }
    }
}


