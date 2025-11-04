//
//  SupabaseConnector.swift
//  ZyraFormSupabase
//
//  Optional Supabase connector for PowerSync backend
//  Users who want Supabase support should import ZyraFormSupabase
//

import Foundation
import PowerSync
import Supabase
import ZyraForm

public final class SupabaseConnector: PowerSyncBackendConnectorProtocol {
    private let supabaseURL: URL
    private let supabaseKey: String
    private let powerSyncEndpoint: String
    
    public let client: SupabaseClient
    
    public init(
        supabaseURL: URL,
        supabaseKey: String,
        powerSyncEndpoint: String,
        powerSyncPassword: String
    ) {
        self.supabaseURL = supabaseURL
        self.supabaseKey = supabaseKey
        self.powerSyncEndpoint = powerSyncEndpoint
        
        self.client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
    }
    
    // MARK: - PowerSyncBackendConnectorProtocol
    
    public func fetchCredentials() async throws -> PowerSync.PowerSyncCredentials? {
        do {
            let session = try await getSession()
            
            ZyraFormLogger.info("✅ Successfully obtained Supabase session")
            
            return PowerSyncCredentials(
                endpoint: powerSyncEndpoint,
                token: session.accessToken
            )
        } catch {
            ZyraFormLogger.error("❌ Failed to fetch PowerSync credentials: \(error.localizedDescription)")
            ZyraFormLogger.error("📋 Supabase URL: \(supabaseURL.absoluteString)")
            ZyraFormLogger.error("📋 PowerSync Endpoint: \(powerSyncEndpoint)")
            
            // Check for specific error types
            if let httpError = error as? URLError {
                switch httpError.code {
                case .notConnectedToInternet:
                    ZyraFormLogger.error("🌐 No internet connection")
                case .cannotConnectToHost:
                    ZyraFormLogger.error("🔌 Cannot connect to Supabase host - check your Supabase URL")
                case .timedOut:
                    ZyraFormLogger.error("⏱️ Connection timeout - check your network")
                default:
                    ZyraFormLogger.error("🌐 Network error: \(httpError.localizedDescription)")
                }
            }
            
            throw error
        }
    }
    
    public func uploadData(database: any PowerSync.PowerSyncDatabaseProtocol) async throws {
        guard let transaction = try await database.getNextCrudTransaction() else {
            ZyraFormLogger.debug("No pending transactions to upload")
            return
        }
        
        let session = try await getSession()
        var lastEntry: CrudEntry?
        
        do {
            for entry in transaction.crud {
                lastEntry = entry
                let tableName = entry.table
                let table = client.from(tableName)
                
                ZyraFormLogger.debug("📤 Uploading \(entry.op) to table '\(tableName)' with id '\(entry.id)'")
                
                switch entry.op {
                case .put:
                    var data = entry.opData ?? [:]
                    data["id"] = entry.id
                    try await table.upsert(data).execute()
                    ZyraFormLogger.debug("✅ Successfully upserted record '\(entry.id)' to '\(tableName)'")
                    
                case .patch:
                    guard let opData = entry.opData else {
                        ZyraFormLogger.warning("⚠️ PATCH operation skipped - no data provided for '\(entry.id)'")
                        continue
                    }
                    try await table.update(opData).eq("id", value: entry.id).execute()
                    ZyraFormLogger.debug("✅ Successfully updated record '\(entry.id)' in '\(tableName)'")
                    
                case .delete:
                    try await table.delete().eq("id", value: entry.id).execute()
                    ZyraFormLogger.debug("✅ Successfully deleted record '\(entry.id)' from '\(tableName)'")
                }
            }
            
            try await transaction.complete()
            ZyraFormLogger.info("✅ Successfully completed transaction with \(transaction.crud.count) entries")
            
        } catch {
            // Check for 404 errors specifically
            let errorString = String(describing: error).lowercased()
            
            // Check for Supabase/PostgREST errors
            if errorString.contains("404") || errorString.contains("not found") || errorString.contains("pgrst116") {
                ZyraFormLogger.error("❌ [SUPABASE 404] Resource not found")
                ZyraFormLogger.error("📋 Table: \(lastEntry?.table ?? "unknown")")
                ZyraFormLogger.error("📋 Record ID: \(lastEntry?.id ?? "unknown")")
                ZyraFormLogger.error("📋 Operation: \(lastEntry?.op.rawValue ?? "unknown")")
                ZyraFormLogger.error("💡 Possible causes:")
                ZyraFormLogger.error("   1. Table '\(lastEntry?.table ?? "unknown")' does not exist in Supabase")
                ZyraFormLogger.error("   2. Record with id '\(lastEntry?.id ?? "unknown")' was already deleted")
                ZyraFormLogger.error("   3. Row Level Security (RLS) policy is blocking access")
                ZyraFormLogger.error("   4. Table name mismatch - check your schema definition")
            }
            
            // Check HTTP status codes
            if let httpError = extractHTTPError(from: error) {
                if httpError.statusCode == 404 {
                    ZyraFormLogger.error("❌ [HTTP 404] Not Found")
                    ZyraFormLogger.error("📋 URL: \(httpError.url ?? "unknown")")
                    ZyraFormLogger.error("📋 Table: \(lastEntry?.table ?? "unknown")")
                    ZyraFormLogger.error("💡 Check if the table exists in your Supabase database")
                } else if httpError.statusCode == 401 {
                    ZyraFormLogger.error("❌ [HTTP 401] Unauthorized")
                    ZyraFormLogger.error("💡 Your Supabase key may be incorrect or expired")
                    ZyraFormLogger.error("💡 Check your supabaseKey in ZyraFormConfig")
                } else if httpError.statusCode == 403 {
                    ZyraFormLogger.error("❌ [HTTP 403] Forbidden")
                    ZyraFormLogger.error("💡 Your Supabase key may not have the required permissions")
                    ZyraFormLogger.error("💡 Check Row Level Security (RLS) policies")
                }
            }
            
            if let errorCode = PostgresFatalCodes.extractErrorCode(from: error),
               PostgresFatalCodes.isFatalError(errorCode)
            {
                ZyraFormLogger.error("❌ [FATAL ERROR] \(errorCode)")
                ZyraFormLogger.error("📋 Discarding entry: \(lastEntry?.id ?? "unknown")")
                ZyraFormLogger.error("📋 Error: \(error.localizedDescription)")
                try await transaction.complete()
                return
            }
            
            ZyraFormLogger.error("❌ Data upload error - retrying last entry")
            ZyraFormLogger.error("📋 Entry: \(lastEntry?.id ?? "unknown")")
            ZyraFormLogger.error("📋 Error: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func signOut() async throws {
        do {
            try await client.auth.signOut()
            ZyraFormLogger.info("✅ Successfully signed out from Supabase")
        } catch {
            ZyraFormLogger.error("❌ Failed to sign out: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func getSession() async throws -> Session {
        do {
            if let session = try? await client.auth.session {
                ZyraFormLogger.debug("✅ Using existing Supabase session")
                return session
            } else {
                ZyraFormLogger.info("🔄 No existing session - signing in anonymously")
                let session = try await client.auth.signInAnonymously()
                ZyraFormLogger.info("✅ Successfully signed in anonymously")
                return session
            }
        } catch {
            ZyraFormLogger.error("❌ Failed to get Supabase session: \(error.localizedDescription)")
            ZyraFormLogger.error("💡 Ensure anonymous sign-in is enabled in your Supabase dashboard")
            ZyraFormLogger.error("💡 Check your Supabase URL and key")
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    private func extractHTTPError(from error: Error) -> (statusCode: Int, url: String?)? {
        let errorString = String(describing: error)
        
        // Try to extract HTTP status code
        if let statusRange = errorString.range(of: "status code: (\\d+)", options: .regularExpression),
           let statusCode = Int(errorString[statusRange].components(separatedBy: ": ").last ?? "") {
            var url: String? = nil
            if let urlRange = errorString.range(of: "URL: ([^\\s]+)", options: .regularExpression) {
                url = String(errorString[urlRange].components(separatedBy: ": ").last ?? "")
            }
            return (statusCode, url)
        }
        
        return nil
    }
}

private enum PostgresFatalCodes {
    static let fatalResponseCodes: [String] = [
        "0001",
        "22...",
        "23...",
        "42501",
    ]
    
    static func isFatalError(_ code: String) -> Bool {
        return fatalResponseCodes.contains { pattern in
            code.range(of: pattern, options: [.regularExpression]) != nil
        }
    }
    
    static func extractErrorCode(from error: any Error) -> String? {
        let errorString = String(describing: error)
        if let range = errorString.range(of: "code: Optional\\(\"([^\"]+)\"\\)", options: .regularExpression),
           let codeRange = errorString[range].range(of: "\"([^\"]+)\"", options: .regularExpression)
        {
            let code = errorString[codeRange].dropFirst().dropLast()
            return String(code)
        }
        return nil
    }
}

