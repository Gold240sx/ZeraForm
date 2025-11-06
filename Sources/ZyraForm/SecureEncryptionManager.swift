//
//  SecureEncryptionManager.swift
//  ZyraForm
//
//  Secure encryption manager with per-user key derivation
//

import Foundation
import CryptoKit
import Security

/// Secure encryption manager with per-user key derivation
public final class SecureEncryptionManager {
    public static let shared = SecureEncryptionManager()
    
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
    
    /// Set encryption password (for PowerSync compatibility)
    public func setPassword(_ password: String) {
        // This method is kept for compatibility but doesn't affect the encryption
        // The encryption uses per-user keys derived from the master key
    }
    
    /// Encrypt a string value using shared/master key (light encryption)
    /// Uses the master key directly - anyone with the master key can decrypt
    /// RLS and privacy controls determine access - encryption is just for at-rest protection
    public func encryptShared(_ plaintext: String) throws -> String {
        guard !plaintext.isEmpty else { return plaintext }
        
        let masterKey = try getMasterKey()
        let data = plaintext.data(using: .utf8)!
        
        let sealedBox = try AES.GCM.seal(data, using: masterKey)
        let encryptedData = sealedBox.combined!
        
        return encryptedData.base64EncodedString()
    }
    
    /// Decrypt a string value using shared/master key (light encryption)
    public func decryptShared(_ encryptedText: String) throws -> String {
        guard !encryptedText.isEmpty else { return encryptedText }
        
        let masterKey = try getMasterKey()
        guard let encryptedData = Data(base64Encoded: encryptedText) else {
            throw SecureEncryptionError.invalidEncryptedData
        }
        
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: masterKey)
        
        guard let plaintext = String(data: decryptedData, encoding: .utf8) else {
            throw SecureEncryptionError.decryptionFailed
        }
        
        return plaintext
    }
    
    /// Encrypt a value using shared/master key only if encryption is enabled
    public func encryptSharedIfEnabled(_ plaintext: String) throws -> String {
        let enabled = isEncryptionEnabled
        
        guard enabled else {
            return plaintext
        }
        
        return try encryptShared(plaintext)
    }
    
    /// Decrypt a value using shared/master key only if encryption is enabled
    public func decryptSharedIfEnabled(_ encryptedText: String) throws -> String {
        let enabled = isEncryptionEnabled
        
        guard enabled else {
            return encryptedText
        }
        
        // Check if the text appears to be encrypted (base64 and longer than original)
        if encryptedText.count > 20 && encryptedText.range(of: "^[A-Za-z0-9+/]*={0,2}$", options: .regularExpression) != nil {
            do {
                return try decryptShared(encryptedText)
            } catch {
                // If decryption fails, assume it's unencrypted
                return encryptedText
            }
        } else {
            return encryptedText
        }
    }
    
    /// Encrypt a string value for a specific user
    public func encrypt(_ plaintext: String, for userId: String) throws -> String {
        guard !plaintext.isEmpty else { return plaintext }
        
        let userKey = try deriveUserKey(userId: userId)
        let data = plaintext.data(using: .utf8)!
        
        let sealedBox = try AES.GCM.seal(data, using: userKey)
        let encryptedData = sealedBox.combined!
        
        return encryptedData.base64EncodedString()
    }
    
    /// Decrypt a string value for a specific user
    public func decrypt(_ encryptedText: String, for userId: String) throws -> String {
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
    public func encryptIfEnabled(_ plaintext: String, for userId: String) throws -> String {
        let enabled = isEncryptionEnabled
        
        guard enabled else {
            return plaintext
        }
        
        return try encrypt(plaintext, for: userId)
    }
    
    /// Decrypt a value only if encryption is enabled
    public func decryptIfEnabled(_ encryptedText: String, for userId: String) throws -> String {
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
                // If decryption fails, assume it's unencrypted
                return encryptedText
            }
        } else {
            return encryptedText
        }
    }
    
    /// Check if encryption is enabled in user settings
    public var isEncryptionEnabled: Bool {
        // Check if the key exists in UserDefaults
        if UserDefaults.standard.object(forKey: "useEncryptedStorage") == nil {
            // Key doesn't exist, set default to true (encryption enabled by default)
            UserDefaults.standard.set(true, forKey: "useEncryptedStorage")
            return true
        }
        
        let value = UserDefaults.standard.bool(forKey: "useEncryptedStorage")
        
        // TEMPORARY: Force enable encryption for security (remove this after testing)
        if !value {
            UserDefaults.standard.set(true, forKey: "useEncryptedStorage")
            return true
        }
        return value
    }
    
    /// Export master encryption key for cross-platform use (base64 encoded)
    public func exportMasterKey() throws -> String {
        let keyData = try getMasterKeyFromKeychain()
        return keyData.base64EncodedString()
    }
    
    /// Import master encryption key from another platform (replaces current key)
    public func importMasterKey(_ base64Key: String) throws {
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
    public func clearAllKeys() throws {
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
public enum SecureEncryptionError: LocalizedError {
    case keyRetrievalFailed
    case keyStorageFailed
    case keyDerivationFailed
    case invalidEncryptedData
    case decryptionFailed
    
    public var errorDescription: String? {
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

