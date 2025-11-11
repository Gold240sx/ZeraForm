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
    private let supabaseKey: String // Can be publishable or ANON key
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
                
                // Extract ID for logging - PowerSync opData values are String?
                let logId: String
                if !entry.id.isEmpty {
                    logId = entry.id
                } else if let opData = entry.opData, let idValue = opData["id"], let idString = idValue {
                    logId = idString
                } else {
                    logId = "missing"
                }
                ZyraFormLogger.debug("📤 Uploading \(entry.op) to table '\(tableName)' with id '\(logId)' (entry.id: '\(entry.id)', opData.id: '\(entry.opData?["id"] ?? "nil")')")
                
                switch entry.op {
                case .put:
                    // PowerSync example pattern: var data = entry.opData ?? [:]; data["id"] = entry.id
                    // But entry.id might be empty for new records, so we check opData first
                    var opDataDict = entry.opData ?? [:]
                    
                    // Extract ID - PowerSync should have it in entry.id or opData["id"]
                    // For PUT operations, entry.id should be the record ID
                    let recordId: String
                    if !entry.id.isEmpty {
                        // entry.id is the record ID (PowerSync example pattern)
                        recordId = entry.id
                    } else if let idValue = opDataDict["id"], let idString = idValue, !idString.isEmpty {
                        // ID is in opData
                        recordId = idString
                    } else {
                        // ID is missing - this shouldn't happen if PowerSync is tracking properly
                        // Log all available info for debugging
                        ZyraFormLogger.error("❌ Cannot upload record - ID is missing")
                        ZyraFormLogger.error("📋 Entry ID: '\(entry.id)'")
                        ZyraFormLogger.error("📋 Client ID: \(entry.clientId)")
                        ZyraFormLogger.error("📋 OpData keys: \(opDataDict.keys.joined(separator: ", "))")
                        ZyraFormLogger.error("📋 OpData ID value: \(String(describing: opDataDict["id"]))")
                        ZyraFormLogger.error("💡 This usually means PowerSync isn't tracking the ID properly")
                        ZyraFormLogger.error("💡 Check that your INSERT statement includes the 'id' field")
                        continue
                    }
                    
                    // Ensure ID is in opData (PowerSync example pattern)
                    opDataDict["id"] = recordId
                    
                    // Convert opData from [String: String?] to [String: AnyJSON] for Supabase
                    // Supabase requires Encodable, and AnyJSON is Encodable
                    var data: [String: AnyJSON] = [:]
                    for (key, value) in opDataDict {
                        if let stringValue = value {
                            // Filter out empty strings for UUID fields (like user_id)
                            // Empty strings cause "invalid input syntax for type uuid" errors
                            // Convert empty strings to null instead
                            if stringValue.isEmpty && (key.hasSuffix("_id") || key == "id") {
                                data[key] = .null
                            } else {
                                data[key] = .string(stringValue)
                            }
                        } else {
                            data[key] = .null
                        }
                    }
                    // Ensure ID is set (PowerSync example pattern)
                    data["id"] = .string(recordId)
                    
                    try await table.upsert(data).execute()
                    ZyraFormLogger.debug("✅ Successfully upserted record '\(recordId)' to '\(tableName)'")
                    
                case .patch:
                    guard let opData = entry.opData else {
                        ZyraFormLogger.warning("⚠️ PATCH operation skipped - no data provided for '\(entry.id)'")
                        continue
                    }
                    
                    // Extract ID - PowerSync opData values are String?
                    let recordId: String
                    if !entry.id.isEmpty {
                        recordId = entry.id
                    } else if let idValue = opData["id"], let idString = idValue {
                        recordId = idString
                    } else {
                        ZyraFormLogger.error("❌ Cannot update record - ID is missing")
                        continue
                    }
                    
                    // Convert opData from [String: String?] to [String: AnyJSON] for Supabase
                    var patchData: [String: AnyJSON] = [:]
                    for (key, value) in opData {
                        if let stringValue = value {
                            // Filter out empty strings for UUID fields (like user_id)
                            // Empty strings cause "invalid input syntax for type uuid" errors
                            // Convert empty strings to null instead
                            if stringValue.isEmpty && (key.hasSuffix("_id") || key == "id") {
                                patchData[key] = .null
                            } else {
                                patchData[key] = .string(stringValue)
                            }
                        } else {
                            patchData[key] = .null
                        }
                    }
                    
                    try await table.update(patchData).eq("id", value: recordId).execute()
                    ZyraFormLogger.debug("✅ Successfully updated record '\(recordId)' in '\(tableName)'")
                    
                case .delete:
                    // Extract ID from entry.id or from opData if entry.id is empty
                    let recordId: String
                    if entry.id.isEmpty, let opData = entry.opData, let id = opData["id"] as? String {
                        recordId = id
                    } else {
                        recordId = entry.id
                    }
                    if recordId.isEmpty {
                        ZyraFormLogger.error("❌ Cannot delete record - ID is missing")
                        continue
                    }
                    try await table.delete().eq("id", value: recordId).execute()
                    ZyraFormLogger.debug("✅ Successfully deleted record '\(recordId)' from '\(tableName)'")
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
    
    // MARK: - Authentication Methods
    
    /// Sign in with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    /// - Returns: The authenticated session
    public func signIn(email: String, password: String) async throws -> Session {
        do {
            ZyraFormLogger.info("🔄 Signing in with email: \(email)")
            let session = try await client.auth.signIn(email: email, password: password)
            ZyraFormLogger.info("✅ Successfully signed in")
            return session
        } catch {
            ZyraFormLogger.error("❌ Failed to sign in: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Sign up with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    /// - Returns: The authenticated session
    public func signUp(email: String, password: String) async throws -> Session {
        do {
            ZyraFormLogger.info("🔄 Signing up with email: \(email)")
            let response = try await client.auth.signUp(email: email, password: password)
            ZyraFormLogger.info("✅ Successfully signed up")
            
            // signUp returns AuthResponse, extract the session
            guard let session = response.session else {
                throw NSError(
                    domain: "SupabaseConnector",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Sign up successful but no session returned. Email confirmation may be required."]
                )
            }
            return session
        } catch {
            ZyraFormLogger.error("❌ Failed to sign up: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Sign out the current user
    public func signOut() async throws {
        do {
            try await client.auth.signOut()
            ZyraFormLogger.info("✅ Successfully signed out from Supabase")
        } catch {
            ZyraFormLogger.error("❌ Failed to sign out: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Get the current session (requires user to be signed in)
    /// - Returns: The current session if authenticated
    /// - Throws: Error if no session exists (user must sign in first)
    public func getSession() async throws -> Session {
        do {
            if let session = try? await client.auth.session {
                ZyraFormLogger.debug("✅ Using existing Supabase session")
                return session
            } else {
                ZyraFormLogger.error("❌ No active session - user must sign in first")
                ZyraFormLogger.error("💡 Call signIn(email:password:) or signUp(email:password:) before accessing data")
                throw NSError(
                    domain: "SupabaseConnector",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "No active session. Please sign in first."]
                )
            }
        } catch {
            ZyraFormLogger.error("❌ Failed to get Supabase session: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Check if user is currently signed in
    /// - Returns: True if user has an active session
    public func isSignedIn() async -> Bool {
        do {
            let session = try? await client.auth.session
            return session != nil
        } catch {
            return false
        }
    }
    
    /// Get the current user's ID if signed in
    /// - Returns: User ID string if authenticated, nil otherwise
    public func getCurrentUserId() async -> String? {
        do {
            let session = try? await client.auth.session
            return session?.user.id.uuidString
        } catch {
            return nil
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

