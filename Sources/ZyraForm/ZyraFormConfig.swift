//
//  ZyraFormConfig.swift
//  ZyraForm
//
//  Configuration for ZyraForm - users provide this
//

import Foundation
import PowerSync

/// Configuration for ZyraForm
public struct ZyraFormConfig {
    /// Supabase URL
    public let supabaseURL: URL
    
    /// Supabase anon key
    public let supabaseKey: String
    
    /// PowerSync endpoint (from PowerSync dashboard: https://ID.powersync.journeyapps.com)
    public let powerSyncEndpoint: String
    
    /// PowerSync encryption password
    public let powerSyncPassword: String
    
    /// Database prefix for table names
    public let dbPrefix: String
    
    /// Current user ID
    public let userId: String
    
    /// Database schema (tables)
    public let schema: ZyraSchema
    
    /// Database filename (optional, defaults to "ZyraForm.sqlite")
    public let dbFilename: String
    
    public init(
        supabaseURL: URL,
        supabaseKey: String,
        powerSyncEndpoint: String,
        powerSyncPassword: String,
        dbPrefix: String = "",
        userId: String,
        schema: ZyraSchema,
        dbFilename: String = "ZyraForm.sqlite"
    ) {
        self.supabaseURL = supabaseURL
        self.supabaseKey = supabaseKey
        self.powerSyncEndpoint = powerSyncEndpoint
        self.powerSyncPassword = powerSyncPassword
        self.dbPrefix = dbPrefix
        self.userId = userId
        self.schema = schema
        self.dbFilename = dbFilename
    }
}

