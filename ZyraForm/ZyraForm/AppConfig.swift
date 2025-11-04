//
//  AppConfig.swift
//  ZyraForm
//
//  Created by Michael Martell on 11/4/25.
//

import Foundation
import ZyraForm
import ZyraFormSupabase // Added for SupabaseConnector

/// App configuration that pulls values from environment variables
struct AppConfig {
    /// Supabase URL from environment variable or default placeholder
    static var supabaseURL: URL {
        guard let urlString = ProcessInfo.processInfo.environment["SUPABASE_URL"],
              let url = URL(string: urlString) else {
            fatalError("SUPABASE_URL environment variable must be set")
        }
        return url
    }
    
    /// Supabase API key from environment variable
    static var supabaseKey: String {
        guard let key = ProcessInfo.processInfo.environment["SUPABASE_KEY"] else {
            fatalError("SUPABASE_KEY environment variable must be set")
        }
        return key
    }
    
    /// PowerSync endpoint URL from environment variable
    static var powerSyncEndpoint: String {
        guard let endpoint = ProcessInfo.processInfo.environment["POWERSYNC_ENDPOINT"] else {
            fatalError("POWERSYNC_ENDPOINT environment variable must be set")
        }
        return endpoint
    }
    
    /// PowerSync encryption password from environment variable
    static var powerSyncPassword: String {
        guard let password = ProcessInfo.processInfo.environment["POWERSYNC_PASSWORD"] else {
            fatalError("POWERSYNC_PASSWORD environment variable must be set")
        }
        return password
    }
    
    /// Current user ID (can be overridden)
    static var userId: String {
        return ProcessInfo.processInfo.environment["USER_ID"] ?? "default-user"
    }
    
    /// Database prefix
    static var dbPrefix: String {
        return ProcessInfo.processInfo.environment["DB_PREFIX"] ?? "ZyraTest-"
    }
    
    /// Create ZyraFormConfig from environment variables
    static func createZyraFormConfig(schema: ZyraSchema) -> ZyraFormConfig {
        let connector = SupabaseConnector(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey,
            powerSyncEndpoint: powerSyncEndpoint,
            powerSyncPassword: powerSyncPassword
        )
        
        return ZyraFormConfig(
            connector: connector,
            powerSyncPassword: powerSyncPassword,
            dbPrefix: dbPrefix,
            userId: userId,
            schema: schema
        )
    }
}

