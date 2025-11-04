//
//  ZyraFormManager.swift
//  ZyraForm
//
//  Main entry point for ZyraForm package
//

import Foundation
import PowerSync

/// Main manager for ZyraForm - initialize once with your configuration
@MainActor
public class ZyraFormManager {
    public static var shared: ZyraFormManager?
    
    public let config: ZyraFormConfig
    public let database: PowerSync.PowerSyncDatabaseProtocol
    public let connector: PowerSyncBackendConnectorProtocol
    
    private init(config: ZyraFormConfig) {
        self.config = config
        self.connector = config.connector
        
        // Initialize PowerSync database
        let powerSyncSchema = PowerSync.Schema(
            tables: config.schema.tables.map { $0.toPowerSyncTable() }
        )
        
        self.database = PowerSyncDatabase(
            schema: powerSyncSchema,
            dbFilename: config.dbFilename
        )
        
        // Set encryption password
        SecureEncryptionManager.shared.setPassword(config.powerSyncPassword)
    }
    
    /// Initialize ZyraForm with your configuration
    public static func initialize(with config: ZyraFormConfig) async throws {
        ZyraFormLogger.info("🚀 Initializing ZyraForm...")
        ZyraFormLogger.info("📋 PowerSync Endpoint: (provided by connector)")
        ZyraFormLogger.info("📋 Database: \(config.dbFilename)")
        ZyraFormLogger.info("📋 User ID: \(config.userId)")
        
        shared = ZyraFormManager(config: config)
        
        // Connect to PowerSync
        do {
            ZyraFormLogger.info("🔄 Connecting to PowerSync...")
            try await shared?.database.connect(connector: shared!.connector)
            ZyraFormLogger.info("✅ Successfully connected to PowerSync")
        } catch {
            ZyraFormLogger.error("❌ Failed to connect to PowerSync")
            ZyraFormLogger.error("📋 Error: \(error.localizedDescription)")
            
            // Check for PowerSync-specific errors
            let errorString = String(describing: error).lowercased()
            
            if errorString.contains("invalid") || errorString.contains("unauthorized") || errorString.contains("401") {
                ZyraFormLogger.error("🔑 [POWERSYNC KEY ERROR]")
                ZyraFormLogger.error("💡 Possible causes:")
                ZyraFormLogger.error("   1. PowerSync endpoint URL is incorrect")
                ZyraFormLogger.error("   2. PowerSync password/key is incorrect")
                ZyraFormLogger.error("   3. Authentication token is invalid")
            }
            
            if errorString.contains("cannot connect") || errorString.contains("host") {
                ZyraFormLogger.error("🌐 [CONNECTION ERROR]")
                ZyraFormLogger.error("💡 Possible causes:")
                ZyraFormLogger.error("   1. PowerSync endpoint URL is incorrect")
                ZyraFormLogger.error("   2. Network connectivity issues")
                ZyraFormLogger.error("   3. Firewall blocking connection")
            }
            
            if errorString.contains("404") || errorString.contains("not found") {
                ZyraFormLogger.error("❌ [404 ERROR]")
                ZyraFormLogger.error("💡 PowerSync endpoint not found")
                ZyraFormLogger.error("💡 Verify your PowerSync endpoint URL is correct")
            }
            
            throw error
        }
    }
    
    /// Get a service for a specific table
    public func service(for tableName: String) -> ZyraSync {
        return ZyraSync(
            tableName: tableName,
            userId: config.userId,
            database: database
        )
    }
    
    /// Get a form for a specific table
    public func form<Values: FormValues>(
        for table: ZyraTable,
        initialValues: Values? = nil,
        mode: FormValidationMode = .onChange
    ) -> ZyraForm<Values> {
        return ZyraForm(
            schema: table,
            initialValues: initialValues,
            mode: mode
        )
    }
}

