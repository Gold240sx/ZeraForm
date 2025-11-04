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
    /// PowerSync backend connector (users provide their own implementation)
    public let connector: PowerSyncBackendConnectorProtocol
    
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
        connector: PowerSyncBackendConnectorProtocol,
        powerSyncPassword: String,
        dbPrefix: String = "",
        userId: String,
        schema: ZyraSchema,
        dbFilename: String = "ZyraForm.sqlite"
    ) {
        self.connector = connector
        self.powerSyncPassword = powerSyncPassword
        self.dbPrefix = dbPrefix
        self.userId = userId
        self.schema = schema
        self.dbFilename = dbFilename
    }
}

