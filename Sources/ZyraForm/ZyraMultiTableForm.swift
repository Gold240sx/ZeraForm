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
}


