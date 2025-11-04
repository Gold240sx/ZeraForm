//
//  PowerSyncBackendConnector.swift
//  ZyraForm
//
//  Protocol for PowerSync backend connectors - users can implement this
//

import Foundation
import PowerSync

/// Protocol for providing PowerSync credentials (usually from auth)
public protocol PowerSyncCredentialsProvider {
    /// Fetch credentials for PowerSync connection
    func fetchCredentials() async throws -> PowerSync.PowerSyncCredentials?
}

/// Protocol for uploading CRUD operations to backend
public protocol PowerSyncBackendUploader {
    /// Upload a CRUD transaction to the backend
    func uploadTransaction(_ transaction: PowerSync.CrudTransaction) async throws
}

/// Combined protocol for PowerSync backend connector
/// Users can implement this instead of using SupabaseConnector
public protocol PowerSyncBackendConnector: PowerSyncBackendConnectorProtocol, PowerSyncCredentialsProvider {
    /// Sign out from the backend
    func signOut() async throws
}

