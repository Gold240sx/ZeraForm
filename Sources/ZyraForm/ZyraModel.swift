//
//  ZyraModel.swift
//  ZyraForm
//
//  Protocol for schema-driven models with automatic type inference
//

import Foundation

// MARK: - ZyraModel Protocol

/// Protocol that all schema-driven models conform to
/// Provides automatic validation, type conversion, and schema access
public protocol ZyraModel: Codable, Identifiable {
    /// The schema that defines this model - accessible at runtime
    static var schema: ZyraTable { get }
    
    /// Initialize from a database record dictionary
    init(from record: [String: Any]) throws
    
    /// Convert to dictionary for database operations
    func toDictionary(excluding columns: [String]) -> [String: Any]
}

// MARK: - ZyraModel Default Implementation

extension ZyraModel {
    /// Get validation rules for a specific field from the schema
    public static func validationRules(for field: String) -> ColumnMetadata? {
        return schema.columns.first(where: { $0.name == field })
    }
    
    /// Get all field names from the schema
    public static var allFields: [String] {
        return schema.columns.map { $0.name }
    }
    
    /// Get fields for form (excluding specified columns)
    public static func fieldsForForm(excluding: [String] = ["id", "created_at", "updated_at"]) -> [String] {
        return schema.columns
            .map { $0.name }
            .filter { !excluding.contains($0) }
    }
    
    /// Get required fields from schema
    public static var requiredFields: [String] {
        return schema.columns
            .filter { !$0.isNullable }
            .map { $0.name }
    }
    
    /// Get optional fields from schema
    public static var optionalFields: [String] {
        return schema.columns
            .filter { $0.isNullable }
            .map { $0.name }
    }
}

// MARK: - Type Conversion Helpers

extension ZyraModel {
    /// Convenience method with default empty array
    public func toDictionary(excluding columns: [String] = []) -> [String: Any] {
        // Use Codable to encode to dictionary, then filter
        guard let data = try? JSONEncoder().encode(self),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        
        // Filter out excluded columns
        var result = dict
        for column in columns {
            result.removeValue(forKey: column)
        }
        
        return result
    }
}

extension ZyraModel {
    /// Convert value to appropriate type based on schema column metadata
    public static func convertValue(_ value: Any?, for field: String) -> Any? {
        guard let column = validationRules(for: field) else {
            return value
        }
        
        // Handle nil values
        guard let value = value else {
            return column.isNullable ? nil : (column.defaultValue ?? nil)
        }
        
        // Type conversion based on column metadata
        switch column.swiftType {
        case .bool:
            if let boolValue = value as? Bool {
                return boolValue
            } else if let strValue = value as? String {
                return strValue.lowercased() == "true" || strValue == "1"
            } else if let intValue = value as? Int {
                return intValue != 0
            }
            return false
            
        case .integer:
            if let intValue = value as? Int {
                return intValue
            } else if let strValue = value as? String, let intValue = Int(strValue) {
                return intValue
            }
            return column.defaultValue.flatMap { Int($0) }
            
        case .double:
            if let doubleValue = value as? Double {
                return doubleValue
            } else if let strValue = value as? String, let doubleValue = Double(strValue) {
                return doubleValue
            }
            return column.defaultValue.flatMap { Double($0) }
            
        case .date:
            if let dateValue = value as? Date {
                return dateValue
            } else if let strValue = value as? String {
                return ISO8601DateFormatter().date(from: strValue)
            }
            return nil
            
        case .string:
            if let strValue = value as? String {
                return strValue
            }
            return String(describing: value)
            
        default:
            return value
        }
    }
}

