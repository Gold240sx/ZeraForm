//
//  SchemaRecord.swift
//  ZyraForm
//
//  Generic record type that works directly with ZyraTable schemas
//  No code generation needed - use your schema directly!
//

import Foundation
import PowerSync

/// A generic record that works directly with any ZyraTable schema
/// Provides type-safe access to fields using the schema definition
/// Use this when you don't want to generate model structs - just use your schema!
public struct SchemaRecord: Identifiable {
    /// The schema this record conforms to
    public let schema: ZyraTable
    
    /// The underlying data dictionary
    private let data: [String: Any]
    
    /// Initialize with schema and data
    public init(schema: ZyraTable, data: [String: Any]) {
        self.schema = schema
        self.data = data
    }
    
    /// Get the ID (required by Identifiable)
    public var id: String {
        return data[schema.primaryKey] as? String ?? UUID().uuidString
    }
    
    /// Get a value for a field with type conversion
    public func get<T>(_ field: String, as type: T.Type) -> T? {
        guard let column = schema.columns.first(where: { $0.name == field }) else {
            return nil
        }
        
        let value = data[field]
        
        // Handle nil
        guard let value = value else {
            return column.isNullable ? nil : (column.defaultValue as? T)
        }
        
        // Type conversion based on schema
        if T.self == Bool.self {
            if let boolValue = value as? Bool {
                return boolValue as? T
            } else if let strValue = value as? String {
                return (strValue.lowercased() == "true" || strValue == "1") as? T
            } else if let intValue = value as? Int {
                return (intValue != 0) as? T
            }
            return (column.defaultValue?.lowercased() == "true") as? T
        } else if T.self == Int.self {
            if let intValue = value as? Int {
                return intValue as? T
            } else if let strValue = value as? String, let intValue = Int(strValue) {
                return intValue as? T
            }
            return column.defaultValue.flatMap { Int($0) } as? T
        } else if T.self == Double.self {
            if let doubleValue = value as? Double {
                return doubleValue as? T
            } else if let strValue = value as? String, let doubleValue = Double(strValue) {
                return doubleValue as? T
            }
            return column.defaultValue.flatMap { Double($0) } as? T
        } else if T.self == Date.self {
            if let dateValue = value as? Date {
                return dateValue as? T
            } else if let strValue = value as? String {
                return ISO8601DateFormatter().date(from: strValue) as? T
            }
            return nil
        } else if T.self == String.self {
            if let strValue = value as? String {
                return strValue as? T
            }
            return String(describing: value) as? T
        }
        
        return value as? T
    }
    
    /// Get a value with a default
    public func get<T>(_ field: String, as type: T.Type, default defaultValue: T) -> T {
        return get(field, as: type) ?? defaultValue
    }
    
    /// Set a value (creates a new record)
    public func setting(_ field: String, to value: Any) -> SchemaRecord {
        var newData = data
        newData[field] = value
        return SchemaRecord(schema: schema, data: newData)
    }
    
    /// Set multiple values at once (creates a new record)
    public func setting(_ values: [String: Any]) -> SchemaRecord {
        var newData = data
        for (key, value) in values {
            newData[key] = value
        }
        return SchemaRecord(schema: schema, data: newData)
    }
    
    /// Convenience: Create record from dictionary
    public static func from(_ data: [String: Any], schema: ZyraTable) -> SchemaRecord {
        return SchemaRecord(schema: schema, data: data)
    }
    
    /// Convert to dictionary for database operations
    public func toDictionary(excluding columns: [String] = []) -> [String: Any] {
        var result = data
        
        // Convert types based on schema
        for column in schema.columns {
            guard let value = result[column.name] else { continue }
            
            switch column.swiftType {
            case .bool:
                if let boolValue = value as? Bool {
                    result[column.name] = boolValue ? "true" : "false"
                }
            case .date:
                if let dateValue = value as? Date {
                    result[column.name] = ISO8601DateFormatter().string(from: dateValue)
                }
            default:
                break
            }
        }
        
        // Remove excluded columns
        for column in columns {
            result.removeValue(forKey: column)
        }
        
        return result
    }
    
    /// Subscript access for convenience
    public subscript(field: String) -> Any? {
        return data[field]
    }
}

// MARK: - Factory Methods

extension ZyraTable {
    /// Create a SchemaRecord from this table's schema
    public func createRecord(from data: [String: Any]) -> SchemaRecord {
        return SchemaRecord(schema: self, data: data)
    }
    
    /// Create an empty record with default values
    public func createEmptyRecord() -> SchemaRecord {
        var data: [String: Any] = [:]
        
        for column in columns {
            if let defaultValue = column.defaultValue {
                data[column.name] = defaultValue
            } else if !column.isNullable {
                // Set non-nullable defaults
                switch column.swiftType {
                case .bool:
                    data[column.name] = "false"
                case .integer:
                    data[column.name] = 0
                case .double:
                    data[column.name] = 0.0
                case .string:
                    data[column.name] = ""
                default:
                    break
                }
            }
        }
        
        return SchemaRecord(schema: self, data: data)
    }
}

// MARK: - Schema-Based Sync (No Model Generation Needed)

/// Sync service that works directly with schemas (no model generation needed)
/// Automatically syncs with PowerSync for real-time updates from Supabase
@MainActor
public class SchemaBasedSync: ObservableObject {
    private let service: ZyraSync
    public let schema: ZyraTable
    private var watchTask: Task<Void, Never>?
    
    @Published public var records: [SchemaRecord] = []
    
    public init(
        schema: ZyraTable,
        userId: String,
        database: PowerSync.PowerSyncDatabaseProtocol,
        encryptionManager: SecureEncryptionManager? = nil,
        watchForUpdates: Bool = true
    ) {
        self.schema = schema
        self.service = ZyraSync(
            tableName: schema.name,
            userId: userId,
            database: database,
            encryptionManager: encryptionManager
        )
        
        // Set up real-time watching if enabled
        if watchForUpdates {
            setupWatch()
        }
    }
    
    deinit {
        watchTask?.cancel()
    }
    
    /// Set up real-time watch for PowerSync updates
    private func setupWatch() {
        watchTask = Task { [weak self] in
            guard let self = self else { return }
            
            // Watch the service's records for changes
            for await _ in self.service.$records.values {
                // Convert dictionaries to SchemaRecords whenever records update
                await MainActor.run {
                    self.records = self.service.records.map { record in
                        self.schema.createRecord(from: record)
                    }
                }
            }
        }
    }
    
    /// Load records as SchemaRecords
    /// This will also set up real-time watching if not already active
    public func loadRecords(
        fields: [String]? = nil,
        whereClause: String? = nil,
        parameters: [Any] = [],
        orderBy: String? = nil
    ) async throws {
        let config = schema.toTableFieldConfig()
        
        let fieldsToLoad = fields ?? config.allFields
        let orderByClause = orderBy ?? config.defaultOrderBy
        
        try await service.loadRecords(
            fields: fieldsToLoad,
            whereClause: whereClause,
            parameters: parameters,
            orderBy: orderByClause,
            encryptedFields: config.encryptedFields,
            integerFields: config.integerFields,
            booleanFields: config.booleanFields
        )
        
        // Convert dictionaries to SchemaRecords
        // Note: If watch is active, this will also update automatically
        records = service.records.map { record in
            schema.createRecord(from: record)
        }
    }
    
    /// Create a record
    public func createRecord(
        _ record: SchemaRecord,
        autoGenerateId: Bool = true,
        autoTimestamp: Bool = true
    ) async throws -> String {
        let config = schema.toTableFieldConfig()
        
        var dict = record.toDictionary()
        
        return try await service.createRecord(
            fields: dict,
            encryptedFields: config.encryptedFields,
            autoGenerateId: autoGenerateId,
            autoTimestamp: autoTimestamp
        )
    }
    
    /// Update a record
    public func updateRecord(
        _ record: SchemaRecord,
        autoTimestamp: Bool = true
    ) async throws {
        let config = schema.toTableFieldConfig()
        
        var dict = record.toDictionary(excluding: ["id", "created_at"])
        
        try await service.updateRecord(
            id: record.id,
            fields: dict,
            encryptedFields: config.encryptedFields,
            autoTimestamp: autoTimestamp
        )
    }
    
    /// Delete a record
    public func deleteRecord(_ record: SchemaRecord) async throws {
        try await service.deleteRecord(id: record.id)
    }
    
    // MARK: - Convenience Query Methods
    
    /// Get all records (for current user by default)
    /// - Returns: Array of all SchemaRecords
    public func getAll() async throws -> [SchemaRecord] {
        try await loadRecords()
        return records
    }
    
    /// Get all records matching a WHERE clause
    /// - Parameters:
    ///   - whereClause: SQL WHERE clause (without "WHERE" keyword), e.g., "is_completed = ?"
    ///   - parameters: Parameters for the WHERE clause
    ///   - orderBy: Optional ORDER BY clause, e.g., "created_at DESC"
    /// - Returns: Array of matching SchemaRecords
    public func getAll(where whereClause: String, parameters: [Any] = [], orderBy: String? = nil) async throws -> [SchemaRecord] {
        try await loadRecords(whereClause: whereClause, parameters: parameters, orderBy: orderBy)
        return records
    }
    
    /// Get one record by ID
    /// - Parameter id: Record ID
    /// - Returns: SchemaRecord if found, nil otherwise
    public func getOne(id: String) async throws -> SchemaRecord? {
        try await loadRecords(
            whereClause: "\(schema.primaryKey) = ?",
            parameters: [id]
        )
        return records.first
    }
    
    /// Get first record matching a WHERE clause
    /// - Parameters:
    ///   - whereClause: SQL WHERE clause (without "WHERE" keyword), e.g., "is_completed = ?"
    ///   - parameters: Parameters for the WHERE clause
    ///   - orderBy: Optional ORDER BY clause, e.g., "created_at DESC"
    /// - Returns: First matching SchemaRecord, or nil if none found
    public func getFirst(where whereClause: String, parameters: [Any] = [], orderBy: String? = nil) async throws -> SchemaRecord? {
        let orderByClause = orderBy ?? schema.defaultOrderBy
        try await loadRecords(whereClause: whereClause, parameters: parameters, orderBy: orderByClause)
        return records.first
    }
}

