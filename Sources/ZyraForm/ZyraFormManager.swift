//
//  ZyraFormManager.swift
//  ZyraForm
//
//  Main entry point for ZyraForm package
//

import Foundation
import PowerSync
import Supabase

/// Main manager for ZyraForm - initialize once with your configuration
@MainActor
public class ZyraFormManager {
    public static var shared: ZyraFormManager?
    
    public let config: ZyraFormConfig
    public let database: PowerSyncDatabase
    public let supabaseConnector: SupabaseConnector
    
    private init(config: ZyraFormConfig) {
        self.config = config
        
        // Initialize PowerSync database
        let powerSyncSchema = PowerSync.Schema(
            tables: config.schema.tables.map { $0.toPowerSyncTable() }
        )
        
        self.database = PowerSyncDatabase(
            schema: powerSyncSchema,
            dbFilename: config.dbFilename
        )
        
        // Initialize Supabase connector
        self.supabaseConnector = SupabaseConnector(
            supabaseURL: config.supabaseURL,
            supabaseKey: config.supabaseKey,
            powerSyncEndpoint: config.powerSyncEndpoint,
            powerSyncPassword: config.powerSyncPassword
        )
        
        // Set encryption password
        SecureEncryptionManager.shared.setPassword(config.powerSyncPassword)
    }
    
    /// Initialize ZyraForm with your configuration
    public static func initialize(with config: ZyraFormConfig) async throws {
        ZyraFormLogger.info("🚀 Initializing ZyraForm...")
        ZyraFormLogger.info("📋 Supabase URL: \(config.supabaseURL.absoluteString)")
        ZyraFormLogger.info("📋 PowerSync Endpoint: \(config.powerSyncEndpoint)")
        ZyraFormLogger.info("📋 Database: \(config.dbFilename)")
        ZyraFormLogger.info("📋 User ID: \(config.userId)")
        
        shared = ZyraFormManager(config: config)
        
        // Connect to PowerSync/Supabase
        do {
            ZyraFormLogger.info("🔄 Connecting to PowerSync...")
            try await shared?.database.connect(connector: shared!.supabaseConnector)
            ZyraFormLogger.info("✅ Successfully connected to PowerSync and Supabase")
        } catch {
            ZyraFormLogger.error("❌ Failed to connect to PowerSync/Supabase")
            ZyraFormLogger.error("📋 Error: \(error.localizedDescription)")
            
            // Check for PowerSync-specific errors
            let errorString = String(describing: error).lowercased()
            
            if errorString.contains("invalid") || errorString.contains("unauthorized") || errorString.contains("401") {
                ZyraFormLogger.error("🔑 [POWERSYNC KEY ERROR]")
                ZyraFormLogger.error("💡 Possible causes:")
                ZyraFormLogger.error("   1. PowerSync endpoint URL is incorrect")
                ZyraFormLogger.error("   2. PowerSync password/key is incorrect")
                ZyraFormLogger.error("   3. Supabase session token is invalid")
                ZyraFormLogger.error("💡 Check your PowerSync endpoint URL format: https://ID.powersync.journeyapps.com")
            }
            
            if errorString.contains("cannot connect") || errorString.contains("host") {
                ZyraFormLogger.error("🌐 [CONNECTION ERROR]")
                ZyraFormLogger.error("💡 Possible causes:")
                ZyraFormLogger.error("   1. PowerSync endpoint URL is incorrect")
                ZyraFormLogger.error("   2. Network connectivity issues")
                ZyraFormLogger.error("   3. Firewall blocking connection")
                ZyraFormLogger.error("💡 Verify your PowerSync endpoint: \(config.powerSyncEndpoint)")
            }
            
            if errorString.contains("404") || errorString.contains("not found") {
                ZyraFormLogger.error("❌ [404 ERROR]")
                ZyraFormLogger.error("💡 PowerSync endpoint not found")
                ZyraFormLogger.error("💡 Verify your PowerSync endpoint URL is correct")
                ZyraFormLogger.error("💡 Format should be: https://YOUR-ID.powersync.journeyapps.com")
            }
            
            throw error
        }
    }
    
    /// Get a service for a specific table
    public func service(for tableName: String) -> GenericPowerSyncService {
        return GenericPowerSyncService(
            tableName: tableName,
            userId: config.userId,
            database: database
        )
    }
    
    /// Get a form for a specific table
    public func form<Values: FormValues>(
        for table: ExtendedTable,
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

