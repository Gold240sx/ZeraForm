//
//  EncryptionManager.swift
//  ZyraForm
//
//  Created by Michael Martell on 11/4/25.
//

/// Encryption Manager
import Foundation
import CryptoKit
import Security

/// Secure encryption manager with per-user key derivation
final class SecureEncryptionManager {
    static let shared = SecureEncryptionManager()
    
    private init() {}
    
    // MARK: - Master Key Management
    
    /// Get or create master encryption key from Keychain
    private func getMasterKey() throws -> SymmetricKey {
        let keyData = try getMasterKeyFromKeychain()
        return SymmetricKey(data: keyData)
    }
    
    /// Get master key from Keychain or create new one
    private func getMasterKeyFromKeychain() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "devspace.master.encryption.key",
            kSecAttrService as String: "DevSpace-Desktop",
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status == errSecSuccess {
            // Key exists, return it
            guard let keyData = item as? Data else {
                throw SecureEncryptionError.keyRetrievalFailed
            }
            return keyData
        } else if status == errSecItemNotFound {
            // Create new master key
            let newKey = SymmetricKey(size: .bits256)
            let keyData = newKey.withUnsafeBytes { Data($0) }
            
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: "devspace.master.encryption.key",
                kSecAttrService as String: "DevSpace-Desktop",
                kSecValueData as String: keyData,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus == errSecSuccess {
                return keyData
            } else {
                throw SecureEncryptionError.keyStorageFailed
            }
        } else {
            throw SecureEncryptionError.keyRetrievalFailed
        }
    }
    
    // MARK: - Per-User Key Derivation
    
    /// Derive a user-specific encryption key using HKDF
    private func deriveUserKey(userId: String) throws -> SymmetricKey {
        let masterKey = try getMasterKey()
        let masterKeyData = masterKey.withUnsafeBytes { Data($0) }
        
        // Use user ID as salt for key derivation
        let salt = userId.data(using: .utf8)!
        
        // Derive key using HKDF (more secure than PBKDF2)
        let derivedKeyData = try PBKDF2.derive(
            password: masterKeyData,
            salt: salt,
            iterations: 1, // HKDF doesn't use iterations, but we keep the parameter for compatibility
            keyLength: 32 // 256 bits for AES-256
        )
        
        return SymmetricKey(data: derivedKeyData)
    }
    
    // MARK: - Encryption/Decryption
    
    /// Encrypt a string value for a specific user
    func encrypt(_ plaintext: String, for userId: String) throws -> String {
        guard !plaintext.isEmpty else { return plaintext }
        
        let userKey = try deriveUserKey(userId: userId)
        let data = plaintext.data(using: .utf8)!
        
        let sealedBox = try AES.GCM.seal(data, using: userKey)
        let encryptedData = sealedBox.combined!
        
        return encryptedData.base64EncodedString()
    }
    
    /// Decrypt a string value for a specific user
    func decrypt(_ encryptedText: String, for userId: String) throws -> String {
        guard !encryptedText.isEmpty else { return encryptedText }
        
        let userKey = try deriveUserKey(userId: userId)
        guard let encryptedData = Data(base64Encoded: encryptedText) else {
            throw SecureEncryptionError.invalidEncryptedData
        }
        
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: userKey)
        
        guard let plaintext = String(data: decryptedData, encoding: .utf8) else {
            throw SecureEncryptionError.decryptionFailed
        }
        
        return plaintext
    }
    
    /// Encrypt a value only if encryption is enabled
    func encryptIfEnabled(_ plaintext: String, for userId: String) throws -> String {
        let enabled = isEncryptionEnabled
        
        guard enabled else {
            return plaintext
        }
        
        return try encrypt(plaintext, for: userId)
    }
    
    /// Decrypt a value only if encryption is enabled
    func decryptIfEnabled(_ encryptedText: String, for userId: String) throws -> String {
        let enabled = isEncryptionEnabled
        
        guard enabled else {
            return encryptedText
        }
        
        // Check if the text appears to be encrypted (base64 and longer than original)
        if encryptedText.count > 20 && encryptedText.range(of: "^[A-Za-z0-9+/]*={0,2}$", options: .regularExpression) != nil {
            do {
                // Try new per-user decryption first
                return try decrypt(encryptedText, for: userId)
            } catch {
                // If new decryption fails, try old global decryption for backward compatibility
                do {
                    let oldEncryptionManager = EncryptionManager.shared
                    let decrypted = try oldEncryptionManager.decryptIfEnabled(encryptedText)
                    PrintDebug("[SecureEncryptionManager] Successfully decrypted with old encryption system", debug: true)
                    return decrypted
                } catch {
                    // If both fail, assume it's unencrypted
//                    PrintDebug("[SecureEncryptionManager] Text appears to be unencrypted, returning as-is: '\(encryptedText.prefix(20))...' \(enabled)", debug: true)
                    return encryptedText
                }
            }
        } else {
//            PrintDebug("[SecureEncryptionManager] Text appears to be unencrypted, returning as-is: '\(encryptedText.prefix(20))...' \(enabled)", debug: true)
            return encryptedText
        }
    }
    
    /// Check if encryption is enabled in user settings
    var isEncryptionEnabled: Bool {
        // Check if the key exists in UserDefaults
        if UserDefaults.standard.object(forKey: "useEncryptedStorage") == nil {
            // Key doesn't exist, set default to true (encryption enabled by default)
            UserDefaults.standard.set(true, forKey: "useEncryptedStorage")
            PrintDebug("[SecureEncryptionManager] UserDefaults key not found - setting default to true", debug: false)
            return true
        }
        
        let value = UserDefaults.standard.bool(forKey: "useEncryptedStorage")
        
        // TEMPORARY: Force enable encryption for security (remove this after testing)
        if !value {
            UserDefaults.standard.set(true, forKey: "useEncryptedStorage")
            PrintDebug("[SecureEncryptionManager] Encryption was disabled - force enabling for security", debug: false)
            return true
        }
        return value
    }
    
    /// Export master encryption key for cross-platform use (base64 encoded)
    func exportMasterKey() throws -> String {
        let keyData = try getMasterKeyFromKeychain()
        return keyData.base64EncodedString()
    }
    
    /// Import master encryption key from another platform (replaces current key)
    func importMasterKey(_ base64Key: String) throws {
        guard let keyData = Data(base64Encoded: base64Key) else {
            throw SecureEncryptionError.invalidEncryptedData
        }
        
        // Verify key is correct length (32 bytes for AES-256)
        guard keyData.count == 32 else {
            throw SecureEncryptionError.invalidEncryptedData
        }
        
        // Delete existing key
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "devspace.master.encryption.key",
            kSecAttrService as String: "DevSpace-Desktop"
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Store new key
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "devspace.master.encryption.key",
            kSecAttrService as String: "DevSpace-Desktop",
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            throw SecureEncryptionError.keyStorageFailed
        }
    }
    
    /// Clear all encryption keys (for testing or security purposes)
    func clearAllKeys() throws {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "DevSpace-Desktop"
        ]
        
        let status = SecItemDelete(deleteQuery as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw SecureEncryptionError.keyRetrievalFailed
        }
    }
}

// MARK: - PBKDF2 Implementation using CryptoKit
struct PBKDF2 {
    static func derive(password: Data, salt: Data, iterations: Int, keyLength: Int) throws -> Data {
        // Use CryptoKit's HKDF for key derivation instead of PBKDF2
        // This is more secure and doesn't require CommonCrypto
        let symmetricKey = SymmetricKey(data: password)
        
        // Use HKDF with the salt and iterations
        let info = Data("DevSpace-KeyDerivation".utf8)
        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: symmetricKey,
            salt: salt,
            info: info,
            outputByteCount: keyLength
        )
        
        return derivedKey.withUnsafeBytes { Data($0) }
    }
}

// MARK: - Secure Encryption Errors
enum SecureEncryptionError: LocalizedError {
    case keyRetrievalFailed
    case keyStorageFailed
    case keyDerivationFailed
    case invalidEncryptedData
    case decryptionFailed
    
    var errorDescription: String? {
        switch self {
        case .keyRetrievalFailed:
            return "Failed to retrieve encryption key from Keychain"
        case .keyStorageFailed:
            return "Failed to store encryption key in Keychain"
        case .keyDerivationFailed:
            return "Failed to derive user-specific encryption key"
        case .invalidEncryptedData:
            return "Invalid encrypted data format"
        case .decryptionFailed:
            return "Failed to decrypt data"
        }
    }
}

/// Encryption manager for sensitive project data
final class EncryptionManager {
    static let shared = EncryptionManager()
    
    private init() {}
    
    // MARK: - Encryption Key Management
    
    /// Get or create encryption key from Keychain
    private func getEncryptionKey() throws -> SymmetricKey {
        let keyData = try getKeyFromKeychain()
        return SymmetricKey(data: keyData)
    }
    
    /// Get encryption key from Keychain or create new one
    private func getKeyFromKeychain() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "devspace.encryption.key",
            kSecAttrService as String: "DevSpace-Desktop",
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status == errSecSuccess {
            // Key exists, return it
            guard let keyData = item as? Data else {
                throw EncryptionError.keyRetrievalFailed
            }
            return keyData
        } else if status == errSecItemNotFound {
            // Key doesn't exist, create new one
            let newKey = SymmetricKey(size: .bits256)
            let keyData = newKey.withUnsafeBytes { Data($0) }
            
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: "devspace.encryption.key",
                kSecAttrService as String: "DevSpace-Desktop",
                kSecValueData as String: keyData
            ]
            
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus == errSecSuccess {
                return keyData
            } else {
                throw EncryptionError.keyStorageFailed
            }
        } else {
            throw EncryptionError.keyRetrievalFailed
        }
    }
    
    // MARK: - Encryption/Decryption
    
    /// Encrypt a string value
    func encrypt(_ plaintext: String) throws -> String {
        guard !plaintext.isEmpty else { return plaintext }
        
        let key = try getEncryptionKey()
        let data = plaintext.data(using: .utf8)!
        
        let sealedBox = try AES.GCM.seal(data, using: key)
        let encryptedData = sealedBox.combined!
        
        return encryptedData.base64EncodedString()
    }
    
    /// Decrypt a string value
    func decrypt(_ encryptedText: String) throws -> String {
        guard !encryptedText.isEmpty else { return encryptedText }
        
        let key = try getEncryptionKey()
        guard let encryptedData = Data(base64Encoded: encryptedText) else {
            throw EncryptionError.invalidEncryptedData
        }
        
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        guard let plaintext = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.decryptionFailed
        }
        
        return plaintext
    }
    
    /// Check if encryption is enabled in user settings
    var isEncryptionEnabled: Bool {
        // Check if the key exists in UserDefaults
        if UserDefaults.standard.object(forKey: "useEncryptedStorage") == nil {
            // Key doesn't exist, set default to true (encryption enabled by default)
            UserDefaults.standard.set(true, forKey: "useEncryptedStorage")
            PrintDebug("[EncryptionManager] UserDefaults key not found - setting default to true", debug: false)
            return true
        }
        
        let value = UserDefaults.standard.bool(forKey: "useEncryptedStorage")
        
        // TEMPORARY: Force enable encryption for security (remove this after testing)
        if !value {
            UserDefaults.standard.set(true, forKey: "useEncryptedStorage")
            PrintDebug("[EncryptionManager] Encryption was disabled - force enabling for security", debug: false)
            return true
        }
        return value
    }
    
    /// Export encryption key for cross-platform use (base64 encoded)
    func exportEncryptionKey() throws -> String {
        let keyData = try getKeyFromKeychain()
        return keyData.base64EncodedString()
    }
    
    /// Import encryption key from another platform (replaces current key)
    func importEncryptionKey(_ base64Key: String) throws {
        guard let keyData = Data(base64Encoded: base64Key) else {
            throw EncryptionError.invalidEncryptedData
        }
        
        // Verify key is correct length (32 bytes for AES-256)
        guard keyData.count == 32 else {
            throw EncryptionError.invalidEncryptedData
        }
        
        // Delete existing key
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "devspace.encryption.key",
            kSecAttrService as String: "DevSpace-Desktop"
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Store new key
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "devspace.encryption.key",
            kSecAttrService as String: "DevSpace-Desktop",
            kSecValueData as String: keyData
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            throw EncryptionError.keyStorageFailed
        }
    }
    
    /// Encrypt a value only if encryption is enabled
    func encryptIfEnabled(_ plaintext: String) throws -> String {
        let enabled = isEncryptionEnabled
        
        guard enabled else {
            return plaintext
        }
        
        return try encrypt(plaintext)
    }
    
    /// Decrypt a value only if encryption is enabled
    func decryptIfEnabled(_ encryptedText: String) throws -> String {
        guard isEncryptionEnabled else { return encryptedText }
        
        // Check if the text is actually encrypted (base64 encoded)
        // If it's not encrypted (plain text), return it as-is for backward compatibility
        if !isBase64Encoded(encryptedText) {
            PrintDebug("[EncryptionManager] Text appears to be unencrypted, returning as-is: '\(encryptedText)'", false)
            return encryptedText
        }
        
        do {
            let decrypted = try decrypt(encryptedText)
            PrintDebug("[EncryptionManager] Successfully decrypted text", debug: false)
            return decrypted
        } catch {
            PrintDebug("[EncryptionManager] Decryption failed, assuming unencrypted: '\(encryptedText)'", false)
            // If decryption fails, assume it's unencrypted data and return as-is
            return encryptedText
        }
    }
    
    /// Check if a string is base64 encoded (rough heuristic for encrypted data)
    private func isBase64Encoded(_ string: String) -> Bool {
        // Base64 strings are typically longer and contain specific characters
        // This is a simple heuristic - encrypted data should be base64 encoded
        guard string.count > 20 else { return false } // Encrypted data should be longer
        
        let base64Pattern = "^[A-Za-z0-9+/]*={0,2}$"
        let regex = try? NSRegularExpression(pattern: base64Pattern)
        let range = NSRange(location: 0, length: string.count)
        return regex?.firstMatch(in: string, options: [], range: range) != nil
    }
}

// MARK: - Encryption Errors
enum EncryptionError: LocalizedError {
    case keyRetrievalFailed
    case keyStorageFailed
    case invalidEncryptedData
    case decryptionFailed
    
    var errorDescription: String? {
        switch self {
        case .keyRetrievalFailed:
            return "Failed to retrieve encryption key from Keychain"
        case .keyStorageFailed:
            return "Failed to store encryption key in Keychain"
        case .invalidEncryptedData:
            return "Invalid encrypted data format"
        case .decryptionFailed:
            return "Failed to decrypt data"
        }
    }
}

