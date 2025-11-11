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
        // Helper to check if value is effectively empty
        func isEmpty(_ val: Any?) -> Bool {
            if val == nil {
                return true
            }
            if let str = val as? String, str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return true
            }
            return false
        }
        
        // Check required - must check before other validations
        if !column.isNullable {
            if isEmpty(value) {
                return column.requiredError ?? "\(column.name) is required"
            }
            
            // For integer/double types, also check if empty string can't be converted
            if column.swiftType == .integer || column.swiftType == .double {
                if let strValue = value as? String, strValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return column.requiredError ?? "\(column.name) is required"
                }
            }
        }
        
        guard let value = value else { return nil }
        
        // Skip further validation if value is empty and nullable
        if isEmpty(value) {
            return nil
        }
        
        // Email validation
        if column.isEmail == true {
            if let email = value as? String, !isValidEmail(email) {
                return column.emailError ?? "Please enter a valid email address"
            }
        }
        
        // URL validation
        if column.isUrl == true {
            if let url = value as? String, !isValidURL(url) {
                return column.urlError ?? "Please enter a valid URL"
            }
        }
        
        // HTTP URL validation
        if column.isHttpUrl == true {
            if let url = value as? String {
                guard let urlObj = URL(string: url),
                      let scheme = urlObj.scheme?.lowercased(),
                      (scheme == "http" || scheme == "https"),
                      urlObj.host != nil else {
                    return column.httpUrlError ?? "Please enter a valid HTTP/HTTPS URL"
                }
            }
        }
        
        // String length validation
        if let strValue = value as? String {
            if let minLength = column.minLength, strValue.count < minLength {
                return column.minLengthError ?? "\(column.name) must be at least \(minLength) characters"
            }
            if let maxLength = column.maxLength, strValue.count > maxLength {
                return column.maxLengthError ?? "\(column.name) must be \(maxLength) characters or less"
            }
            if let exactLength = column.exactLength, strValue.count != exactLength {
                return "\(column.name) must be exactly \(exactLength) characters"
            }
            
            // String pattern validation
            if let startsWith = column.startsWith, !strValue.hasPrefix(startsWith) {
                return column.startsWithError ?? "\(column.name) must start with '\(startsWith)'"
            }
            if let endsWith = column.endsWith, !strValue.hasSuffix(endsWith) {
                return column.endsWithError ?? "\(column.name) must end with '\(endsWith)'"
            }
            if let includes = column.includes, !strValue.contains(includes) {
                return column.includesError ?? "\(column.name) must include '\(includes)'"
            }
            
            // Case validation
            if column.isUppercase == true, strValue != strValue.uppercased() {
                return column.uppercaseError ?? "\(column.name) must be uppercase"
            }
            if column.isLowercase == true, strValue != strValue.lowercased() {
                return column.lowercaseError ?? "\(column.name) must be lowercase"
            }
        }
        
        // Integer validation
        if column.swiftType == .integer {
            if let intValue = value as? Int {
                // Positive/Negative validation
                if column.isPositive == true, intValue <= 0 {
                    return column.positiveError ?? "\(column.name) must be positive"
                }
                if column.isNegative == true, intValue >= 0 {
                    return column.negativeError ?? "\(column.name) must be negative"
                }
                
                // Even/Odd validation
                if column.isEven == true, intValue % 2 != 0 {
                    return column.evenError ?? "\(column.name) must be an even number"
                }
                if column.isOdd == true, intValue % 2 == 0 {
                    return column.oddError ?? "\(column.name) must be an odd number"
                }
                
                // Min/Max validation
                if let intMin = column.intMin, intValue < intMin {
                    return column.intMinError ?? "\(column.name) must be at least \(intMin)"
                }
                if let intMax = column.intMax, intValue > intMax {
                    return column.intMaxError ?? "\(column.name) must be \(intMax) or less"
                }
            } else if let strValue = value as? String {
                let trimmed = strValue.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Check if empty string
                if trimmed.isEmpty {
                    if !column.isNullable {
                        return column.requiredError ?? "\(column.name) is required"
                    }
                    return nil // Empty and nullable, skip validation
                }
                
                // Try to convert string to Int
                guard let intValue = Int(trimmed) else {
                    return "\(column.name) must be a valid number"
                }
                
                // Positive/Negative validation
                if column.isPositive == true, intValue <= 0 {
                    return column.positiveError ?? "\(column.name) must be positive"
                }
                if column.isNegative == true, intValue >= 0 {
                    return column.negativeError ?? "\(column.name) must be negative"
                }
                
                // Even/Odd validation
                if column.isEven == true, intValue % 2 != 0 {
                    return column.evenError ?? "\(column.name) must be an even number"
                }
                if column.isOdd == true, intValue % 2 == 0 {
                    return column.oddError ?? "\(column.name) must be an odd number"
                }
                
                // Min/Max validation
                if let intMin = column.intMin, intValue < intMin {
                    return column.intMinError ?? "\(column.name) must be at least \(intMin)"
                }
                if let intMax = column.intMax, intValue > intMax {
                    return column.intMaxError ?? "\(column.name) must be \(intMax) or less"
                }
            } else if value == nil {
                // Nil value - check required
                if !column.isNullable {
                    return column.requiredError ?? "\(column.name) is required"
                }
            }
        }
        
        // Double validation
        if column.swiftType == .double {
            if let doubleValue = value as? Double {
                // Positive/Negative validation
                if column.isPositive == true, doubleValue <= 0 {
                    return column.positiveError ?? "\(column.name) must be positive"
                }
                if column.isNegative == true, doubleValue >= 0 {
                    return column.negativeError ?? "\(column.name) must be negative"
                }
                
                // Min/Max validation
                if let min = column.minimum, doubleValue < min {
                    return column.minimumError ?? "\(column.name) must be at least \(min)"
                }
                if let max = column.maximum, doubleValue > max {
                    return column.maximumError ?? "\(column.name) must be \(max) or less"
                }
            } else if let strValue = value as? String, !strValue.isEmpty {
                // Convert string to Double and validate
                guard let doubleValue = Double(strValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                    return "\(column.name) must be a valid number"
                }
                
                // Positive/Negative validation
                if column.isPositive == true, doubleValue <= 0 {
                    return column.positiveError ?? "\(column.name) must be positive"
                }
                if column.isNegative == true, doubleValue >= 0 {
                    return column.negativeError ?? "\(column.name) must be negative"
                }
                
                // Min/Max validation
                if let min = column.minimum, doubleValue < min {
                    return column.minimumError ?? "\(column.name) must be at least \(min)"
                }
                if let max = column.maximum, doubleValue > max {
                    return column.maximumError ?? "\(column.name) must be \(max) or less"
                }
            } else if let strValue = value as? String, strValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Empty string for double field - check required
                if !column.isNullable {
                    return column.requiredError ?? "\(column.name) is required"
                }
            }
        }
        
        // Enum validation
        if let enumType = column.enumType {
            if let strValue = value as? String {
                if strValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Empty enum value - check required
                    if !column.isNullable {
                        return column.requiredError ?? "\(column.name) is required"
                    }
                } else if !enumType.values.contains(strValue) {
                    return column.enumError ?? "\(column.name) must be one of: \(enumType.values.joined(separator: ", "))"
                }
            } else if value == nil {
                // Nil enum value - check required
                if !column.isNullable {
                    return column.requiredError ?? "\(column.name) is required"
                }
            }
        }
        
        // Regex validation
        if let pattern = column.regexPattern {
            if let strValue = value as? String {
                let regex = try? NSRegularExpression(pattern: pattern, options: [])
                let range = NSRange(location: 0, length: strValue.utf16.count)
                if regex?.firstMatch(in: strValue, options: [], range: range) == nil {
                    return column.regexError ?? "\(column.name) does not match the required pattern"
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

