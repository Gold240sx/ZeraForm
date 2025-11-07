//
//  ZyraValidation.swift
//  ZyraForm
//
//  Shared validation utilities for schema-based validation
//

import Foundation

// MARK: - Validation Utilities

/// Shared validation utilities for ZyraForm
public enum ZyraValidation {
    /// Validate a value against a column's schema rules
    /// - Parameters:
    ///   - column: The column metadata containing validation rules
    ///   - value: The value to validate
    /// - Returns: Error message if validation fails, nil if valid
    public static func validate(_ value: Any?, against column: ColumnMetadata) -> String? {
        // Check required
        if !column.isNullable && (value == nil || (value as? String)?.isEmpty == true) {
            return "\(column.name) is required"
        }
        
        guard let value = value else { return nil }
        
        // Email validation
        if column.isEmail == true {
            if let email = value as? String, !isValidEmail(email) {
                return "Please enter a valid email address"
            }
        }
        
        // URL validation
        if column.isUrl == true {
            if let url = value as? String, !isValidURL(url) {
                return "Please enter a valid URL"
            }
        }
        
        // String length validation
        if let strValue = value as? String {
            if let minLength = column.minLength, strValue.count < minLength {
                return "\(column.name) must be at least \(minLength) characters"
            }
            if let maxLength = column.maxLength, strValue.count > maxLength {
                return "\(column.name) must be \(maxLength) characters or less"
            }
        }
        
        // Integer validation
        if column.swiftType == .integer {
            if let intValue = value as? Int {
                if let intMin = column.intMin, intValue < intMin {
                    return "\(column.name) must be at least \(intMin)"
                }
                if let intMax = column.intMax, intValue > intMax {
                    return "\(column.name) must be \(intMax) or less"
                }
            } else if let strValue = value as? String, !strValue.isEmpty {
                if Int(strValue) == nil {
                    return "\(column.name) must be a valid number"
                }
            }
        }
        
        // Double validation
        if column.swiftType == .double {
            if let doubleValue = value as? Double {
                if let min = column.minimum, doubleValue < min {
                    return "\(column.name) must be at least \(min)"
                }
                if let max = column.maximum, doubleValue > max {
                    return "\(column.name) must be \(max) or less"
                }
            }
        }
        
        // Custom validation
        if let customValidation = column.customValidation {
            if !customValidation.1(value) {
                return customValidation.0
            }
        }
        
        return nil
    }
    
    /// Validate email format
    public static func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    /// Validate URL format
    public static func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              url.scheme != nil,
              url.host != nil else {
            return false
        }
        return true
    }
}

