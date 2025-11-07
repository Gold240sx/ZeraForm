//
//  ZyraSync.swift
//  ZyraForm
//
//  CRUD service for PowerSync database operations
//


import Foundation
import PowerSync
import Combine
import SwiftUI

/// ZyraSync service for CRUD operations on any table
@MainActor
public class ZyraSync: ObservableObject {
    private let powerSync: PowerSync.PowerSyncDatabaseProtocol
    private let userId: String
    private let encryptionManager: SecureEncryptionManager
    private let tableName: String

    @Published public var records: [[String: Any]] = []
    
    private var watchTask: Task<Void, Never>?
    private var currentWatchQuery: String?
    private var currentWatchParams: [Any] = []
    private var currentWatchFields: [String] = []
    private var currentWatchConfig: (encryptedFields: [String], integerFields: [String], booleanFields: [String]) = ([], [], [])
    
    /// Initialize with table name, user ID, database, and optional encryption manager
    public init(tableName: String, userId: String, database: PowerSync.PowerSyncDatabaseProtocol, encryptionManager: SecureEncryptionManager? = nil) {
        self.tableName = tableName
        self.userId = userId
        self.powerSync = database
        // Note: SecureEncryptionManager needs to be moved to package or made available
        self.encryptionManager = encryptionManager ?? SecureEncryptionManager.shared
    }
    
    deinit {
        watchTask?.cancel()
    }

    // MARK: - Read Operations

    /// Load all records for the current user
    /// - Parameters:
    ///   - fields: Array of field names to retrieve (use ["*"] for all fields)
    ///   - whereClause: Optional WHERE clause (without "WHERE" keyword), e.g., "user_id = ? AND is_active = ?"
    ///   - parameters: Parameters for the WHERE clause
    ///   - orderBy: Optional ORDER BY clause, e.g., "created_at DESC"
    ///   - encryptedFields: Array of field names that should be decrypted
    ///   - integerFields: Array of field names that are integers (stored as encrypted text)
    ///   - booleanFields: Array of field names that are booleans (stored as encrypted text)
    public func loadRecords(
        fields: [String] = ["*"],
        whereClause: String? = nil,
        parameters: [Any] = [],
        orderBy: String = "created_at DESC",
        encryptedFields: [String] = [],
        integerFields: [String] = [],
        booleanFields: [String] = []
    ) async throws {
        // Build SELECT clause
        let selectClause = fields.contains("*") ? "*" : fields.map { "\"\($0)\"" }.joined(separator: ", ")
        var query = "SELECT \(selectClause) FROM \"\(tableName)\""
        var queryParams: [Any] = []

        // Add WHERE clause if provided
        if let whereClause = whereClause, !whereClause.isEmpty {
            query += " WHERE \(whereClause)"
            queryParams.append(contentsOf: parameters)
        } else {
            // Default: filter by user_id
            query += " WHERE user_id = ?"
            queryParams.append(userId)
        }

        // Add ORDER BY
        query += " ORDER BY \(orderBy)"

        // Build list of fields to read from cursor
        let fieldsToRead: [String]
        if fields.contains("*") {
            var commonFields = ["id", "user_id", "owner_id", "created_at", "updated_at"]
            commonFields.append(contentsOf: encryptedFields)
            commonFields.append(contentsOf: integerFields)
            commonFields.append(contentsOf: booleanFields)
            fieldsToRead = Array(Set(commonFields))
        } else {
            fieldsToRead = fields
        }

        // Store watch configuration for continuous watching
        currentWatchQuery = query
        currentWatchParams = queryParams
        currentWatchFields = fieldsToRead
        currentWatchConfig = (encryptedFields, integerFields, booleanFields)

        // Cancel existing watch if query changed
        let queryString = "\(query)|\(queryParams.map { "\($0)" }.joined(separator: ","))"
        if watchTask != nil {
            watchTask?.cancel()
        }

        // Start continuous watch in background task
        watchTask = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                ZyraFormLogger.debug("🔍 Starting PowerSync watch for \(self.tableName)")
                
                for try await results in try self.powerSync.watch(
                    sql: query,
                    parameters: queryParams,
                    mapper: { cursor in
                        var dict: [String: Any] = [:]

                        // Read each field
                        for fieldName in fieldsToRead {
                            if encryptedFields.contains(fieldName) {
                                if let encryptedValue = try? cursor.getStringOptional(name: fieldName) {
                                    if let decrypted = try? self.encryptionManager.decryptIfEnabled(encryptedValue, for: self.userId) {
                                        if integerFields.contains(fieldName), let intValue = Int(decrypted) {
                                            dict[fieldName] = intValue
                                        } else if booleanFields.contains(fieldName) {
                                            dict[fieldName] = decrypted == "true" || decrypted == "1"
                                        } else {
                                            dict[fieldName] = decrypted
                                        }
                                    } else {
                                        dict[fieldName] = encryptedValue
                                    }
                                } else {
                                    dict[fieldName] = nil
                                }
                            } else if integerFields.contains(fieldName) {
                                dict[fieldName] = try? cursor.getIntOptional(name: fieldName)
                            } else if booleanFields.contains(fieldName) {
                                if let intValue = try? cursor.getIntOptional(name: fieldName) {
                                    dict[fieldName] = intValue == 1
                                } else if let strValue = try? cursor.getStringOptional(name: fieldName) {
                                    dict[fieldName] = strValue == "true" || strValue == "1"
                                }
                            } else {
                                if let strValue = try? cursor.getStringOptional(name: fieldName) {
                                    dict[fieldName] = strValue
                                } else if let intValue = try? cursor.getIntOptional(name: fieldName) {
                                    dict[fieldName] = intValue
                                } else if let doubleValue = try? cursor.getDoubleOptional(name: fieldName) {
                                    dict[fieldName] = doubleValue
                                }
                            }
                        }

                        return dict
                    }
                ) {
                    // Update records whenever PowerSync emits new data
                    await MainActor.run {
                        self.records = results
                        ZyraFormLogger.debug("🔄 PowerSync watch updated: \(results.count) records from \(self.tableName)")
                    }
                }
            } catch {
                if !(error is CancellationError) {
                    ZyraFormLogger.error("❌ PowerSync watch error for \(self.tableName): \(error.localizedDescription)")
                }
            }
        }
        
        // Wait for initial load
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        ZyraFormLogger.debug("✅ Watch started for \(tableName)")
    }


    // MARK: - Create Operations

    /// Create a new record
    /// - Parameters:
    ///   - fields: Dictionary of field names to values
    ///   - encryptedFields: Array of field names that should be encrypted
    ///   - autoGenerateId: Whether to auto-generate a UUID for the id field
    ///   - autoTimestamp: Whether to automatically add created_at and updated_at timestamps
    public func createRecord(
        fields: [String: Any],
        encryptedFields: [String] = [],
        autoGenerateId: Bool = true,
        autoTimestamp: Bool = true
    ) async throws -> String {
        let id = autoGenerateId ? UUID().uuidString : (fields["id"] as? String ?? UUID().uuidString)
        let now = ISO8601DateFormatter().string(from: Date())

        var allFields = fields
        if autoGenerateId && allFields["id"] == nil {
            allFields["id"] = id
        }
        if autoTimestamp {
            allFields["created_at"] = allFields["created_at"] ?? now
            allFields["updated_at"] = allFields["updated_at"] ?? now
        }

        // Note: user_id is only added if the table has a user_id column
        // Remove this if your table doesn't support user_id filtering
        // if allFields["user_id"] == nil {
        //     allFields["user_id"] = userId
        // }

        // Build INSERT query
        let fieldNames = Array(allFields.keys)
        let placeholders = fieldNames.map { _ in "?" }.joined(separator: ", ")
        let columns = fieldNames.map { "\"\($0)\"" }.joined(separator: ", ")

        var parameters: [Any] = []
        for fieldName in fieldNames {
            if let value = allFields[fieldName] {
                // Encrypt if needed
                if encryptedFields.contains(fieldName) {
                    let stringValue: String
                    if let str = value as? String {
                        stringValue = str
                    } else if let intValue = value as? Int {
                        stringValue = String(intValue)
                    } else if let boolValue = value as? Bool {
                        stringValue = boolValue ? "true" : "false"} else {
                        stringValue = String(describing: value)
                    }
                    let encrypted = try encryptionManager.encryptIfEnabled(stringValue, for: userId)
                    parameters.append(encrypted)
                } else {
                    parameters.append(value)
                }
            } else {
                parameters.append(NSNull())
            }
        }

        let query = """
            INSERT INTO "\(tableName)"
            (\(columns))
            VALUES (\(placeholders))
            """

        try await powerSync.execute(sql: query, parameters: parameters)

        // No need to reload - PowerSync watch will automatically update records
        ZyraFormLogger.info("✅ Created record in \(tableName): \(id)")
        return id
    }

    // MARK: - Update Operations

    /// Update an existing record
    /// - Parameters:
    ///   - id: The ID of the record to update
    ///   - fields: Dictionary of field names to values (only provided fields will be updated)
    ///   - encryptedFields: Array of field names that should be encrypted
    ///   - autoTimestamp: Whether to automatically update updated_at timestamp
    public func updateRecord(
        id: String,
        fields: [String: Any],
        encryptedFields: [String] = [],
        autoTimestamp: Bool = true
    ) async throws {
        let now = ISO8601DateFormatter().string(from: Date())

        var updateFields: [String] = []
        var parameters: [Any] = []

        // Build dynamic UPDATE query
        for (fieldName, value) in fields {
            if fieldName == "id" {
                continue // Skip ID field
            }

            updateFields.append("\"\(fieldName)\" = ?")

            // Encrypt if needed
            if encryptedFields.contains(fieldName) {
                let stringValue: String
                if let str = value as? String {
                    stringValue = str
                } else if let intValue = value as? Int {
                    stringValue = String(intValue)
                } else if let boolValue = value as? Bool {
                    stringValue = boolValue ? "true" : "false"} else {
                    stringValue = String(describing: value)
                }
                let encrypted = try encryptionManager.encryptIfEnabled(stringValue, for: userId)
                parameters.append(encrypted)
            } else {
                parameters.append(value)
            }
        }

        // Always update updated_at if autoTimestamp is enabled
        if autoTimestamp {
            updateFields.append("\"updated_at\" = ?")
            parameters.append(now)
        }

        // Add ID parameter for WHERE clause
        parameters.append(id)

        // Build query
        let query = "UPDATE \"\(tableName)\" SET \(updateFields.joined(separator: ", ")) WHERE id = ?"

        try await powerSync.execute(sql: query, parameters: parameters)

        // No need to reload - PowerSync watch will automatically update records
        ZyraFormLogger.info("✅ Updated record in \(tableName): \(id)")
    }

    // MARK: - Delete Operations

    /// Delete a record by ID
    /// - Parameter id: The ID of the record to delete
    /// - Parameter caseInsensitive: Whether to use case-insensitive ID matching
    public func deleteRecord(id: String, caseInsensitive: Bool = true) async throws {
        ZyraFormLogger.debug("🗑️ Deleting record from \(tableName) with ID: \(id)")

        // Optional: Check if record exists
        let checkQuery = caseInsensitive
            ? "SELECT COUNT(*) as count FROM \"\(tableName)\" WHERE LOWER(id) = LOWER(?)": "SELECT COUNT(*) as count FROM \"\(tableName)\" WHERE id = ?"

        do {
            for try await results in try powerSync.watch(
                sql: checkQuery,
                parameters: [id],
                mapper: { cursor in
                    return try cursor.getInt(name: "count")
                }
            ) {
                if let count = results.first {
                    ZyraFormLogger.debug("🔍 Found \(count) record(s) matching ID")
                }
                break
            }
        } catch {
            ZyraFormLogger.warning("⚠️ Error checking record existence: \(error.localizedDescription)")
        }

        // Execute DELETE
        let deleteQuery = caseInsensitive
            ? "DELETE FROM \"\(tableName)\" WHERE LOWER(id) = LOWER(?)": "DELETE FROM \"\(tableName)\" WHERE id = ?"

        try await powerSync.execute(sql: deleteQuery, parameters: [id])

        // No need to reload - PowerSync watch will automatically update records
        ZyraFormLogger.debug("✅ DELETE SQL executed")
        ZyraFormLogger.info("✅ Record deletion completed - PowerSync will handle sync")
    }

    // MARK: - Batch Operations

    /// Create multiple records at once
    public func createRecords(
        records: [[String: Any]],
        encryptedFields: [String] = [],
        autoGenerateId: Bool = true,
        autoTimestamp: Bool = true
    ) async throws -> [String] {
        var createdIds: [String] = []

        for record in records {
            let id = try await createRecord(
                fields: record,
                encryptedFields: encryptedFields,
                autoGenerateId: autoGenerateId,
                autoTimestamp: autoTimestamp
            )
            createdIds.append(id)
        }

        return createdIds
    }

    /// Delete multiple records by IDs
    public func deleteRecords(ids: [String], caseInsensitive: Bool = true) async throws {
        for id in ids {
            try await deleteRecord(id: id, caseInsensitive: caseInsensitive)
        }
    }
}

// MARK: - Generic ZyraSync for ZyraModel

/// Generic ZyraSync service that works with ZyraModel types
@MainActor
public class TypedZyraSync<Model: ZyraModel>: ObservableObject {
    internal let baseService: ZyraSync
    
    @Published public var records: [Model] = []
    
    /// Initialize with model type (infers table name from schema)
    public init(
        userId: String,
        database: PowerSync.PowerSyncDatabaseProtocol,
        encryptionManager: SecureEncryptionManager? = nil
    ) {
        let tableName = Model.schema.name
        self.baseService = ZyraSync(
            tableName: tableName,
            userId: userId,
            database: database,
            encryptionManager: encryptionManager
        )
    }
    
    /// Initialize with explicit table name override
    public init(
        tableName: String,
        userId: String,
        database: PowerSync.PowerSyncDatabaseProtocol,
        encryptionManager: SecureEncryptionManager? = nil
    ) {
        self.baseService = ZyraSync(
            tableName: tableName,
            userId: userId,
            database: database,
            encryptionManager: encryptionManager
        )
    }
    
    /// Load records as typed models
    public func loadRecords(
        fields: [String]? = nil,
        whereClause: String? = nil,
        parameters: [Any] = [],
        orderBy: String? = nil
    ) async throws {
        let schema = Model.schema
        let config = schema.toTableFieldConfig()
        
        let fieldsToLoad = fields ?? config.allFields
        let orderByClause = orderBy ?? config.defaultOrderBy
        
        try await baseService.loadRecords(
            fields: fieldsToLoad,
            whereClause: whereClause,
            parameters: parameters,
            orderBy: orderByClause,
            encryptedFields: config.encryptedFields,
            integerFields: config.integerFields,
            booleanFields: config.booleanFields
        )
        
        // Convert dictionaries to typed models
        records = try baseService.records.map { record in
            try Model(from: record)
        }
    }
    
    /// Create a record from a model
    public func createRecord(
        _ model: Model,
        autoGenerateId: Bool = true,
        autoTimestamp: Bool = true
    ) async throws -> String {
        let schema = Model.schema
        let config = schema.toTableFieldConfig()
        
        var dict = model.toDictionary()
        
        return try await baseService.createRecord(
            fields: dict,
            encryptedFields: config.encryptedFields,
            autoGenerateId: autoGenerateId,
            autoTimestamp: autoTimestamp
        )
    }
    
    /// Update a record from a model
    public func updateRecord(
        _ model: Model,
        autoTimestamp: Bool = true
    ) async throws {
        let schema = Model.schema
        let config = schema.toTableFieldConfig()
        
        var dict = model.toDictionary(excluding: ["id", "created_at"])
        
        try await baseService.updateRecord(
            id: model.id as! String,
            fields: dict,
            encryptedFields: config.encryptedFields,
            autoTimestamp: autoTimestamp
        )
    }
    
    /// Delete a record
    public func deleteRecord(_ model: Model) async throws {
        try await baseService.deleteRecord(id: model.id as! String)
    }
}
