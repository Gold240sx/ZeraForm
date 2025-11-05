//
//  ZyraTable.swift
//  ZyraForm
//
//  Schema definitions for ZyraForm tables
//


import Foundation
import PowerSync

// MARK: - TableFieldConfig

/// Configuration for table fields used by PowerSync services
public struct TableFieldConfig {
    public let allFields: [String]
    public let encryptedFields: [String]
    public let integerFields: [String]
    public let booleanFields: [String]
    public let defaultOrderBy: String
}

/// Metadata for a PowerSync column
public struct ColumnMetadata {
    public let name: String
    public let powerSyncColumn: PowerSync.Column
    public let isEncrypted: Bool
    public let swiftType: SwiftColumnType
    public let isNullable: Bool
    public let isUnique: Bool
    public let foreignKey: ForeignKey?
    public let defaultValue: String?
    public let enumType: DatabaseEnum?
    public let nestedSchema: NestedSchema?
    
    // Validation properties (like Zod)
    public let isPositive: Bool?
    public let isNegative: Bool?
    public let isEven: Bool?
    public let isOdd: Bool?
    public let minimum: Double?
    public let maximum: Double?
    public let intMin: Int?
    public let intMax: Int?
    public let isEmail: Bool?
    public let isUrl: Bool?
    public let isHttpUrl: Bool?
    public let isUuid: Bool?
    public let isCuid: Bool?
    public let isCuid2: Bool?
    public let isNanoid: Bool?
    public let isEmoji: Bool?
    public let isHex: Bool?
    public let isJwt: Bool?
    public let isDate: Bool?
    public let isTime: Bool?
    public let isIsoDateTime: Bool?
    public let isIsoDate: Bool?
    public let isIsoTime: Bool?
    public let regexPattern: String?
    public let regexError: String?
    public let minLength: Int?
    public let maxLength: Int?
    public let exactLength: Int?
    public let startsWith: String?
    public let endsWith: String?
    public let includes: String?
    public let isUppercase: Bool?
    public let isLowercase: Bool?
    public let isIpv4: Bool?
    public let isIpv6: Bool?
    public let customValidation: (String, (Any) -> Bool)?
    
    public indirect enum SwiftColumnType: Equatable {
        case string
        case integer
        case boolean
        case double
        case uuid
        case date
        case `enum`(DatabaseEnum)
        case object(NestedSchema)
        case array(NestedSchema)
    }
}

extension ColumnMetadata.SwiftColumnType {
    var enumValue: DatabaseEnum? {
        if case .enum(let dbEnum) = self {
            return dbEnum
        }
        return nil
    }
    
    /// Convert to Swift type string
    public func toSwiftType(isNullable: Bool, enumType: DatabaseEnum? = nil) -> String {
        let type: String
        switch self {
        case .string:
            type = "String"
        case .integer:
            type = "Int"
        case .boolean:
            type = "Bool"
        case .double:
            type = "Double"
        case .uuid:
            type = "String"
        case .date:
            type = "String"
        case .enum(let dbEnum):
            // Use the enum name as the Swift type
            // Prefer the passed enumType parameter, otherwise use the associated enum
            let enumToUse = enumType ?? dbEnum
            let enumName = enumToUse.name
                .replacingOccurrences(of: "_", with: " ")
                .split(separator: " ")
                .map { $0.capitalized }
                .joined()
            type = enumName
        case .object:
            type = "String"
        case .array:
            type = "String"
        }
        
        return isNullable ? "\(type)?" : type
    }
}

// MARK: - Nested Schema

/// Nested schema for objects and arrays (supports recursion)
/// Uses indirect enum to break circular reference with ColumnBuilder
public indirect enum NestedSchema: Equatable {
    case object(fields: [String: ColumnBuilder])
    case array(elementType: ColumnBuilder)
    
    public init(fields: [String: ColumnBuilder]) {
        self = .object(fields: fields)
    }
    
    public init(elementType: ColumnBuilder) {
        self = .array(elementType: elementType)
    }
    
    public var isObject: Bool {
        if case .object = self {
            return true
        }
        return false
    }
    
    public var isArray: Bool {
        if case .array = self {
            return true
        }
        return false
    }
    
    public var fields: [String: ColumnBuilder] {
        if case .object(let fields) = self {
            return fields
        }
        return [:]
    }
    
    public var elementType: ColumnBuilder? {
        if case .array(let elementType) = self {
            return elementType
        }
        return nil
    }
    
    // Custom Equatable implementation
    // Note: Compares schema structure, ignoring function closures in ColumnBuilder
    public static func == (lhs: NestedSchema, rhs: NestedSchema) -> Bool {
        switch (lhs, rhs) {
        case (.object(let lhsFields), .object(let rhsFields)):
            // Compare field names and basic properties, ignoring closures
            return lhsFields.keys == rhsFields.keys &&
                   lhsFields.keys.allSatisfy { key in
                       let lhsBuilder = lhsFields[key]!
                       let rhsBuilder = rhsFields[key]!
                       return lhsBuilder.name == rhsBuilder.name &&
                              lhsBuilder.swiftType == rhsBuilder.swiftType &&
                              lhsBuilder.isNullable == rhsBuilder.isNullable
                   }
        case (.array(let lhsElement), .array(let rhsElement)):
            return lhsElement.name == rhsElement.name &&
                   lhsElement.swiftType == rhsElement.swiftType &&
                   lhsElement.isNullable == rhsElement.isNullable
        default:
            return false
        }
    }
}

// MARK: - Column Builder

/// Builder for creating columns with metadata
public struct ColumnBuilder {
    public let name: String
    public let powerSyncColumn: PowerSync.Column
    public var isEncrypted: Bool = false
    public var swiftType: ColumnMetadata.SwiftColumnType = .string
    public var isNullable: Bool = false
    public var isUnique: Bool = false
    public var foreignKey: ForeignKey? = nil
    public var defaultValue: String? = nil
    public var enumType: DatabaseEnum? = nil
    
    // Validation properties
    public var isPositive: Bool? = nil
    public var isNegative: Bool? = nil
    public var isEven: Bool? = nil
    public var isOdd: Bool? = nil
    public var minimum: Double? = nil
    public var maximum: Double? = nil
    public var intMin: Int? = nil
    public var intMax: Int? = nil
    public var isEmail: Bool? = nil
    public var isUrl: Bool? = nil
    public var isHttpUrl: Bool? = nil
    public var isUuid: Bool? = nil
    public var isCuid: Bool? = nil
    public var isCuid2: Bool? = nil
    public var isNanoid: Bool? = nil
    public var isEmoji: Bool? = nil
    public var isHex: Bool? = nil
    public var isJwt: Bool? = nil
    public var isDate: Bool? = nil
    public var isTime: Bool? = nil
    public var isIsoDateTime: Bool? = nil
    public var isIsoDate: Bool? = nil
    public var isIsoTime: Bool? = nil
    public var regexPattern: String? = nil
    public var regexError: String? = nil
    public var minLength: Int? = nil
    public var maxLength: Int? = nil
    public var exactLength: Int? = nil
    public var startsWith: String? = nil
    public var endsWith: String? = nil
    public var includes: String? = nil
    public var isUppercase: Bool? = nil
    public var isLowercase: Bool? = nil
    public var isIpv4: Bool? = nil
    public var isIpv6: Bool? = nil
    public var customValidation: (String, (Any) -> Bool)? = nil
    
    // Use indirect reference to break circular dependency
    private var _nestedSchema: NestedSchema?
    
    public var nestedSchema: NestedSchema? {
        get { _nestedSchema }
        set { _nestedSchema = newValue }
    }
    
    // Many-to-many relationship marker
    var _manyToManyRelationship: ManyToManyRelationship? = nil
    
    public init(name: String, powerSyncColumn: PowerSync.Column) {
        self.name = name
        self.powerSyncColumn = powerSyncColumn
        self._nestedSchema = nil
    }
    
    // MARK: - Type Methods
    
    public func encrypted() -> ColumnBuilder {
        var builder = self
        builder.isEncrypted = true
        return builder
    }
    
    public func int() -> ColumnBuilder {
        var builder = self
        builder.swiftType = .integer
        return builder
    }
    
    public func bool() -> ColumnBuilder {
        var builder = self
        builder.swiftType = .boolean
        return builder
    }
    
    public func double() -> ColumnBuilder {
        var builder = self
        builder.swiftType = .double
        return builder
    }
    
    public func uuid() -> ColumnBuilder {
        var builder = self
        builder.swiftType = .uuid
        builder.isUuid = true
        return builder
    }
    
    public func nullable() -> ColumnBuilder {
        var builder = self
        builder.isNullable = true
        return builder
    }
    
    public func notNull() -> ColumnBuilder {
        var builder = self
        builder.isNullable = false
        return builder
    }
    
    public func unique() -> ColumnBuilder {
        var builder = self
        builder.isUnique = true
        return builder
    }
    
    // MARK: - Default Values
    
    public func `default`(_ value: String) -> ColumnBuilder {
        var builder = self
        builder.defaultValue = value
        return builder
    }
    
    public func `default`(_ value: Int) -> ColumnBuilder {
        var builder = self
        builder.defaultValue = String(value)
        return builder
    }
    
    public func `default`(_ value: Bool) -> ColumnBuilder {
        var builder = self
        builder.defaultValue = value ? "true" : "false"
        return builder
    }
    
    public func `default`(_ value: DefaultTimestamp) -> ColumnBuilder {
        var builder = self
        switch value {
        case .now:
            builder.defaultValue = "NOW()"
            builder.swiftType = .date
        }
        return builder
    }
    
    public func defaultSQL(_ sqlExpression: String) -> ColumnBuilder {
        var builder = self
        builder.defaultValue = sqlExpression
        return builder
    }
    
    // MARK: - Enum and Foreign Key
    
    public func `enum`(_ enumType: DatabaseEnum) -> ColumnBuilder {
        var builder = self
        builder.enumType = enumType
        builder.swiftType = .enum(enumType)
        return builder
    }
    
    /// Create a foreign key relationship
    /// - Parameters:
    ///   - table: The referenced table name
    ///   - column: The referenced column name (defaults to "id")
    ///   - referenceUpdated: Action when referenced row is updated (defaults to .cascade)
    ///   - referenceRemoved: Action when referenced row is deleted (defaults to .setNull)
    /// - Returns: ColumnBuilder with foreign key relationship
    public func references(
        _ table: String,
        column: String = "id",
        referenceUpdated: ForeignKeyAction = .cascade,
        referenceRemoved: ForeignKeyAction = .setNull
    ) -> ColumnBuilder {
        var builder = self
        builder.foreignKey = ForeignKey(
            referencedTable: table,
            referencedColumn: column,
            onDelete: referenceRemoved,
            onUpdate: referenceUpdated
        )
        return builder
    }
    
    /// Legacy method name for backward compatibility
    /// - Parameters:
    ///   - table: The referenced table name
    ///   - column: The referenced column name (defaults to "id")
    ///   - onDelete: Action when referenced row is deleted (defaults to .setNull)
    ///   - onUpdate: Action when referenced row is updated (defaults to .cascade)
    /// - Returns: ColumnBuilder with foreign key relationship
    @available(*, deprecated, renamed: "references(_:column:referenceUpdated:referenceRemoved:)")
    public func references(
        _ table: String,
        column: String = "id",
        onDelete: ForeignKeyAction = .setNull,
        onUpdate: ForeignKeyAction = .cascade
    ) -> ColumnBuilder {
        return self.references(table, column: column, referenceUpdated: onUpdate, referenceRemoved: onDelete)
    }
    
    /// Create a many-to-many relationship
    /// This automatically creates a join/pivot table
    /// - Parameters:
    ///   - table: The other table in the many-to-many relationship
    ///   - joinTableName: Optional custom name for the join table (auto-generated if nil)
    ///   - otherTableColumn: Column name in join table for the other table (auto-generated if nil)
    ///   - referenceRemoved: Action when referenced row is deleted (defaults to .cascade)
    ///   - referenceUpdated: Action when referenced row is updated (defaults to .cascade)
    ///   - otherReferenceRemoved: Action when other table row is deleted (defaults to .cascade)
    ///   - otherReferenceUpdated: Action when other table row is updated (defaults to .cascade)
    ///   - additionalColumns: Additional columns for the join table (e.g., timestamps, metadata)
    /// - Returns: ColumnBuilder marked for many-to-many relationship
    /// - Note: The actual join table is created when building the schema, not at column definition time
    public func belongsToMany(
        _ table: String,
        joinTableName: String? = nil,
        otherTableColumn: String? = nil,
        referenceRemoved: ForeignKeyAction = .cascade,
        referenceUpdated: ForeignKeyAction = .cascade,
        otherReferenceRemoved: ForeignKeyAction = .cascade,
        otherReferenceUpdated: ForeignKeyAction = .cascade,
        additionalColumns: [ColumnBuilder] = []
    ) -> ColumnBuilder {
        var builder = self
        // Store many-to-many relationship info
        // Note: This will be processed by ZyraSchema to create the join table
        builder._manyToManyRelationship = ManyToManyRelationship(
            table1: "", // Will be set by ZyraSchema when processing
            table2: table,
            joinTableName: joinTableName,
            table2Column: otherTableColumn,
            table1ReferenceRemoved: referenceRemoved,
            table1ReferenceUpdated: referenceUpdated,
            table2ReferenceRemoved: otherReferenceRemoved,
            table2ReferenceUpdated: otherReferenceUpdated,
            additionalColumns: additionalColumns
        )
        return builder
    }
    
    // MARK: - Validation Methods
    
    public func email() -> ColumnBuilder {
        var builder = self
        builder.isEmail = true
        return builder
    }
    
    public func url() -> ColumnBuilder {
        var builder = self
        builder.isUrl = true
        return builder
    }
    
    public func httpUrl() -> ColumnBuilder {
        var builder = self
        builder.isHttpUrl = true
        return builder
    }
    
    public func cuid() -> ColumnBuilder {
        var builder = self
        builder.isCuid = true
        return builder
    }
    
    public func cuid2() -> ColumnBuilder {
        var builder = self
        builder.isCuid2 = true
        return builder
    }
    
    public func nanoid() -> ColumnBuilder {
        var builder = self
        builder.isNanoid = true
        return builder
    }
    
    public func emoji() -> ColumnBuilder {
        var builder = self
        builder.isEmoji = true
        return builder
    }
    
    public func hex() -> ColumnBuilder {
        var builder = self
        builder.isHex = true
        return builder
    }
    
    public func jwt() -> ColumnBuilder {
        var builder = self
        builder.isJwt = true
        return builder
    }
    
    public func date() -> ColumnBuilder {
        var builder = self
        builder.swiftType = .date
        builder.isDate = true
        return builder
    }
    
    public func time() -> ColumnBuilder {
        var builder = self
        builder.isTime = true
        return builder
    }
    
    public func isoDateTime() -> ColumnBuilder {
        var builder = self
        builder.isIsoDateTime = true
        return builder
    }
    
    public func isoDate() -> ColumnBuilder {
        var builder = self
        builder.isIsoDate = true
        return builder
    }
    
    public func isoTime() -> ColumnBuilder {
        var builder = self
        builder.isIsoTime = true
        return builder
    }
    
    public func regex(_ pattern: String, error: String? = nil) -> ColumnBuilder {
        var builder = self
        builder.regexPattern = pattern
        builder.regexError = error
        return builder
    }
    
    public func minLength(_ value: Int) -> ColumnBuilder {
        var builder = self
        builder.minLength = value
        return builder
    }
    
    public func maxLength(_ value: Int) -> ColumnBuilder {
        var builder = self
        builder.maxLength = value
        return builder
    }
    
    public func length(_ value: Int) -> ColumnBuilder {
        var builder = self
        builder.exactLength = value
        return builder
    }
    
    public func startsWith(_ prefix: String) -> ColumnBuilder {
        var builder = self
        builder.startsWith = prefix
        return builder
    }
    
    public func endsWith(_ suffix: String) -> ColumnBuilder {
        var builder = self
        builder.endsWith = suffix
        return builder
    }
    
    public func includes(_ substring: String) -> ColumnBuilder {
        var builder = self
        builder.includes = substring
        return builder
    }
    
    public func uppercase() -> ColumnBuilder {
        var builder = self
        builder.isUppercase = true
        return builder
    }
    
    public func lowercase() -> ColumnBuilder {
        var builder = self
        builder.isLowercase = true
        return builder
    }
    
    public func ipv4() -> ColumnBuilder {
        var builder = self
        builder.isIpv4 = true
        return builder
    }
    
    public func ipv6() -> ColumnBuilder {
        var builder = self
        builder.isIpv6 = true
        return builder
    }
    
    public func positive() -> ColumnBuilder {
        var builder = self
        builder.isPositive = true
        return builder
    }
    
    public func negative() -> ColumnBuilder {
        var builder = self
        builder.isNegative = true
        return builder
    }
    
    public func even() -> ColumnBuilder {
        var builder = self
        builder.isEven = true
        return builder
    }
    
    public func odd() -> ColumnBuilder {
        var builder = self
        builder.isOdd = true
        return builder
    }
    
    public func minimum(_ value: Double) -> ColumnBuilder {
        var builder = self
        builder.minimum = value
        return builder
    }
    
    public func maximum(_ value: Double) -> ColumnBuilder {
        var builder = self
        builder.maximum = value
        return builder
    }
    
    public func intMin(_ value: Int) -> ColumnBuilder {
        var builder = self
        builder.intMin = value
        return builder
    }
    
    public func intMax(_ value: Int) -> ColumnBuilder {
        var builder = self
        builder.intMax = value
        return builder
    }
    
    func custom(_ error: String, validator: @escaping (Any) -> Bool) -> ColumnBuilder {
        var builder = self
        builder.customValidation = (error, validator)
        return builder
    }
    
    // MARK: - Nested Schema Methods
    
    public func object(_ schema: [String: ColumnBuilder]) -> ColumnBuilder {
        var builder = self
        builder.nestedSchema = NestedSchema(fields: schema)
        builder.swiftType = .object(NestedSchema(fields: schema))
        return builder
    }
    
    public func array(_ elementType: ColumnBuilder) -> ColumnBuilder {
        var builder = self
        let nested = NestedSchema(elementType: elementType)
        builder.nestedSchema = nested
        builder.swiftType = .array(nested)
        return builder
    }
    
    // MARK: - Build
    
    public func build() -> ColumnMetadata {
        return ColumnMetadata(
            name: name,
            powerSyncColumn: powerSyncColumn,
            isEncrypted: isEncrypted,
            swiftType: swiftType,
            isNullable: isNullable,
            isUnique: isUnique,
            foreignKey: foreignKey,
            defaultValue: defaultValue,
            enumType: enumType ?? swiftType.enumValue,
            nestedSchema: nestedSchema,
            isPositive: isPositive,
            isNegative: isNegative,
            isEven: isEven,
            isOdd: isOdd,
            minimum: minimum,
            maximum: maximum,
            intMin: intMin,
            intMax: intMax,
            isEmail: isEmail,
            isUrl: isUrl,
            isHttpUrl: isHttpUrl,
            isUuid: isUuid,
            isCuid: isCuid,
            isCuid2: isCuid2,
            isNanoid: isNanoid,
            isEmoji: isEmoji,
            isHex: isHex,
            isJwt: isJwt,
            isDate: isDate,
            isTime: isTime,
            isIsoDateTime: isIsoDateTime,
            isIsoDate: isIsoDate,
            isIsoTime: isIsoTime,
            regexPattern: regexPattern,
            regexError: regexError,
            minLength: minLength,
            maxLength: maxLength,
            exactLength: exactLength,
            startsWith: startsWith,
            endsWith: endsWith,
            includes: includes,
            isUppercase: isUppercase,
            isLowercase: isLowercase,
            isIpv4: isIpv4,
            isIpv6: isIpv6,
            customValidation: customValidation
        )
    }
}

// MARK: - Enum Support

/// Database enum definition
public struct DatabaseEnum: Hashable {
    public let name: String
    public let values: [String]
    
    public init(name: String, values: [String]) {
        self.name = name
        self.values = values
    }
    
    /// Generate CREATE TYPE SQL for PostgreSQL
    public func generateCreateEnumSQL() -> String {
        let valuesSQL = values.map { "'\($0)'" }.joined(separator: ", ")
        return """
        CREATE TYPE "\(name)" AS ENUM (\(valuesSQL));
        """
    }
}

// MARK: - Foreign Key Types

/// Default timestamp options
public enum DefaultTimestamp {
    case now
}

/// Foreign key relationship definition
public struct ForeignKey {
    public let referencedTable: String
    public let referencedColumn: String
    public let onDelete: ForeignKeyAction
    public let onUpdate: ForeignKeyAction
}

/// Many-to-many relationship definition
/// Automatically creates a join/pivot table
public struct ManyToManyRelationship {
    /// First table name
    public let table1: String
    /// Second table name
    public let table2: String
    /// Join table name (auto-generated if nil)
    public let joinTableName: String?
    /// Column name in join table for table1 (defaults to table1 name + "_id")
    public let table1Column: String
    /// Column name in join table for table2 (defaults to table2 name + "_id")
    public let table2Column: String
    /// Foreign key action for table1
    public let table1ReferenceRemoved: ForeignKeyAction
    public let table1ReferenceUpdated: ForeignKeyAction
    /// Foreign key action for table2
    public let table2ReferenceRemoved: ForeignKeyAction
    public let table2ReferenceUpdated: ForeignKeyAction
    /// Additional columns for the join table
    public let additionalColumns: [ColumnBuilder]
    
    public init(
        table1: String,
        table2: String,
        joinTableName: String? = nil,
        table1Column: String? = nil,
        table2Column: String? = nil,
        table1ReferenceRemoved: ForeignKeyAction = .cascade,
        table1ReferenceUpdated: ForeignKeyAction = .cascade,
        table2ReferenceRemoved: ForeignKeyAction = .cascade,
        table2ReferenceUpdated: ForeignKeyAction = .cascade,
        additionalColumns: [ColumnBuilder] = []
    ) {
        self.table1 = table1
        self.table2 = table2
        self.joinTableName = joinTableName
        self.table1Column = table1Column ?? "\(table1.replacingOccurrences(of: "_", with: "").singularized())_id"
        self.table2Column = table2Column ?? "\(table2.replacingOccurrences(of: "_", with: "").singularized())_id"
        self.table1ReferenceRemoved = table1ReferenceRemoved
        self.table1ReferenceUpdated = table1ReferenceUpdated
        self.table2ReferenceRemoved = table2ReferenceRemoved
        self.table2ReferenceUpdated = table2ReferenceUpdated
        self.additionalColumns = additionalColumns
    }
    
    /// Generate the join table name
    var generatedJoinTableName: String {
        if let joinTableName = joinTableName {
            return joinTableName
        }
        
        // Generate join table name: sort table names alphabetically and combine
        let sortedTables = [table1, table2].sorted()
        return "\(sortedTables[0])_\(sortedTables[1])"
    }
    
    /// Generate the join table ZyraTable
    public func generateJoinTable(dbPrefix: String = "") -> ZyraTable {
        let joinTableName = "\(dbPrefix)\(generatedJoinTableName)"
        
        var columns: [ColumnBuilder] = []
        
        // Add foreign key columns
        columns.append(
            zf.text(table1Column)
                .references(table1,
                           referenceUpdated: table1ReferenceUpdated,
                           referenceRemoved: table1ReferenceRemoved)
                .notNull()
        )
        
        columns.append(
            zf.text(table2Column)
                .references(table2,
                           referenceUpdated: table2ReferenceUpdated,
                           referenceRemoved: table2ReferenceRemoved)
                .notNull()
        )
        
        // Add additional columns
        columns.append(contentsOf: additionalColumns)
        
        return ZyraTable(
            name: joinTableName,
            primaryKey: "id",
            columns: columns
        )
    }
}

extension String {
    /// Simple singularization (handles common cases)
    func singularized() -> String {
        if self.hasSuffix("ies") {
            return String(self.dropLast(3)) + "y"
        } else if self.hasSuffix("es") && self.count > 3 {
            return String(self.dropLast(2))
        } else if self.hasSuffix("s") && self.count > 1 {
            return String(self.dropLast())
        }
        return self
    }
}

/// Foreign key action when referenced row is updated or deleted
/// Maps to PostgreSQL ON UPDATE / ON DELETE actions
public enum ForeignKeyAction {
    /// CASCADE: Delete/update the row when the referenced row is deleted/updated
    case cascade
    
    /// RESTRICT: Prevent deletion/update if any rows reference it
    case restrict
    
    /// SET NULL: Set the foreign key column to NULL when referenced row is deleted/updated
    case setNull
    
    /// SET DEFAULT: Set the foreign key column to its default value when referenced row is deleted/updated
    case setDefault
    
    /// NO ACTION: Similar to RESTRICT but checked at end of statement
    case noAction
    
    public var sqlString: String {
        switch self {
        case .cascade: return "CASCADE"
        case .restrict: return "RESTRICT"
        case .setNull: return "SET NULL"
        case .setDefault: return "SET DEFAULT"
        case .noAction: return "NO ACTION"
        }
    }
    
    public var drizzleString: String {
        switch self {
        case .cascade: return "cascade"
        case .restrict: return "restrict"
        case .setNull: return "setNull"
        case .setDefault: return "setDefault"
        case .noAction: return "noAction"
        }
    }
}

// MARK: - PowerSync Column Extensions

/// ZyraForm column builder shortcut
public struct zf {
    public static func text(_ name: String) -> ColumnBuilder {
        return PowerSync.Column.text(name)
    }
    
    public static func integer(_ name: String) -> ColumnBuilder {
        return PowerSync.Column.integer(name)
    }
    
    public static func real(_ name: String) -> ColumnBuilder {
        return PowerSync.Column.real(name)
    }
}

extension PowerSync.Column {
    public static func text(_ name: String) -> ColumnBuilder {
        return ColumnBuilder(name: name, powerSyncColumn: .text(name))
    }
    
    public static func integer(_ name: String) -> ColumnBuilder {
        return ColumnBuilder(name: name, powerSyncColumn: .integer(name))
            .int()
    }
    
    public static func real(_ name: String) -> ColumnBuilder {
        return ColumnBuilder(name: name, powerSyncColumn: .real(name))
            .double()
    }
}

// MARK: - RLS Policy

/// Row Level Security policy for PostgreSQL tables
public struct RLSPolicy: Equatable {
    /// Policy name
    public let name: String
    /// Policy operation (SELECT, INSERT, UPDATE, DELETE, or ALL)
    public let operation: RLSOperation
    /// Policy type (permissive or restrictive)
    public let policyType: RLSPolicyType
    /// SQL expression for the policy check
    public let usingExpression: String
    /// Optional SQL expression for WITH CHECK (for INSERT/UPDATE)
    public let withCheckExpression: String?
    
    public init(
        name: String,
        operation: RLSOperation = .all,
        policyType: RLSPolicyType = .permissive,
        usingExpression: String,
        withCheckExpression: String? = nil
    ) {
        self.name = name
        self.operation = operation
        self.policyType = policyType
        self.usingExpression = usingExpression
        self.withCheckExpression = withCheckExpression
    }
}

/// RLS operation types
public enum RLSOperation: String, CaseIterable {
    case select = "SELECT"
    case insert = "INSERT"
    case update = "UPDATE"
    case delete = "DELETE"
    case all = "ALL"
}

/// RLS policy type
public enum RLSPolicyType: String {
    case permissive = "PERMISSIVE"
    case restrictive = "RESTRICTIVE"
}

/// RLS policy builder for common patterns
public struct RLSPolicyBuilder {
    private let tableName: String
    private let userIdColumn: String
    private let usersTableName: String
    private let isSuperUserColumn: String
    private let isOnlineColumn: String
    
    public init(
        tableName: String,
        userIdColumn: String = "user_id",
        usersTableName: String = "users",
        isSuperUserColumn: String = "is_superuser",
        isOnlineColumn: String = "is_online"
    ) {
        self.tableName = tableName
        self.userIdColumn = userIdColumn
        self.usersTableName = usersTableName
        self.isSuperUserColumn = isSuperUserColumn
        self.isOnlineColumn = isOnlineColumn
    }
    
    // MARK: - Permission Helpers
    
    /// Generate SQL expression for checking if user owns the row
    private func userExpression() -> String {
        return "\(userIdColumn) = auth.uid()::text"
    }
    
    /// Generate SQL expression for checking if user is authenticated
    private func authenticatedExpression() -> String {
        return "auth.uid() IS NOT NULL"
    }
    
    /// Generate SQL expression for checking if user is anonymous (not authenticated)
    private func anonymousExpression() -> String {
        return "auth.uid() IS NULL"
    }
    
    /// Generate SQL expression for checking if user is superuser
    private func superUserExpression() -> String {
        return """
        EXISTS (
            SELECT 1 FROM public.\(usersTableName)
            WHERE id = auth.uid()::text
            AND \(isSuperUserColumn) = true
        )
        """
    }
    
    /// Generate SQL expression for checking if user is admin
    private func adminExpression() -> String {
        return """
        EXISTS (
            SELECT 1 FROM public.\(usersTableName)
            WHERE id = auth.uid()::text
            AND role = 'admin'
        )
        """
    }
    
    /// Generate SQL expression for checking if user is editor
    private func editorExpression() -> String {
        return """
        EXISTS (
            SELECT 1 FROM public.\(usersTableName)
            WHERE id = auth.uid()::text
            AND role IN ('admin', 'editor')
        )
        """
    }
    
    /// Generate SQL expression for checking if user is online
    private func onlineExpression() -> String {
        return """
        EXISTS (
            SELECT 1 FROM public.\(usersTableName)
            WHERE id = auth.uid()::text
            AND \(isOnlineColumn) = true
        )
        """
    }
    
    /// Combine multiple expressions with OR
    private func combineExpressions(_ expressions: [String]) -> String {
        return expressions.joined(separator: " OR ")
    }
    
    // MARK: - Common Policy Patterns
    
    /// Users can only access their own rows (or superusers can access all)
    /// Requires: auth.uid() or current_setting('app.user_id') to match user_id column
    public func canAccessOwn(allowSuperUser: Bool = true) -> RLSPolicy {
        let expression: String
        if allowSuperUser {
            expression = combineExpressions([
                userExpression(),
                superUserExpression()
            ])
        } else {
            expression = userExpression()
        }
        
        return RLSPolicy(
            name: "\(tableName)_own_access",
            operation: .all,
            usingExpression: expression,
            withCheckExpression: expression
        )
    }
    
    /// Users can access all rows (no restriction)
    public func canAccessAll() -> RLSPolicy {
        RLSPolicy(
            name: "\(tableName)_all_access",
            operation: .all,
            usingExpression: "true"
        )
    }
    
    /// Users can read all but only modify their own
    public func canReadAllModifyOwn(allowSuperUser: Bool = true) -> RLSPolicy {
        RLSPolicy(
            name: "\(tableName)_read_all_modify_own",
            operation: .select,
            usingExpression: "true"
        )
    }
    
    /// Users can read all but only modify their own (separate policies)
    public func canReadAllModifyOwnSeparate(allowSuperUser: Bool = true) -> [RLSPolicy] {
        let modifyExpression: String
        if allowSuperUser {
            modifyExpression = combineExpressions([
                userExpression(),
                superUserExpression()
            ])
        } else {
            modifyExpression = userExpression()
        }
        
        return [
            RLSPolicy(
                name: "\(tableName)_read_all",
                operation: .select,
                usingExpression: "true"
            ),
            RLSPolicy(
                name: "\(tableName)_modify_own",
                operation: .update,
                usingExpression: modifyExpression,
                withCheckExpression: modifyExpression
            ),
            RLSPolicy(
                name: "\(tableName)_delete_own",
                operation: .delete,
                usingExpression: modifyExpression
            ),
            RLSPolicy(
                name: "\(tableName)_insert_own",
                operation: .insert,
                usingExpression: "true",
                withCheckExpression: allowSuperUser ? modifyExpression : userExpression()
            )
        ]
    }
    
    // MARK: - Permission-Based Policies
    
    /// Policy for authenticated users only
    public func authenticated(operation: RLSOperation = .all) -> RLSPolicy {
        RLSPolicy(
            name: "\(tableName)_authenticated_\(operation.rawValue.lowercased())",
            operation: operation,
            usingExpression: authenticatedExpression()
        )
    }
    
    /// Policy for anonymous users only
    public func anonymous(operation: RLSOperation = .all) -> RLSPolicy {
        RLSPolicy(
            name: "\(tableName)_anonymous_\(operation.rawValue.lowercased())",
            operation: operation,
            usingExpression: anonymousExpression()
        )
    }
    
    /// Policy for superusers only
    public func superUser(operation: RLSOperation = .all) -> RLSPolicy {
        RLSPolicy(
            name: "\(tableName)_superuser_\(operation.rawValue.lowercased())",
            operation: operation,
            usingExpression: superUserExpression()
        )
    }
    
    /// Policy for admin users only
    public func admin(operation: RLSOperation = .all) -> RLSPolicy {
        RLSPolicy(
            name: "\(tableName)_admin_\(operation.rawValue.lowercased())",
            operation: operation,
            usingExpression: adminExpression()
        )
    }
    
    /// Policy for admin users to perform operations on any row (not just their own)
    public func adminCanDelete() -> RLSPolicy {
        return admin(operation: .delete)
    }
    
    /// Policy for admin users to perform operations on any row (not just their own)
    public func adminCanUpdate() -> RLSPolicy {
        return admin(operation: .update)
    }
    
    /// Policy for admin users to perform operations on any row (not just their own)
    public func adminCanInsert() -> RLSPolicy {
        return admin(operation: .insert)
    }
    
    /// Policy for admin users to perform operations on any row (not just their own)
    public func adminCanSelect() -> RLSPolicy {
        return admin(operation: .select)
    }
    
    /// Policy for editor users (admin or editor)
    public func editor(operation: RLSOperation = .all) -> RLSPolicy {
        RLSPolicy(
            name: "\(tableName)_editor_\(operation.rawValue.lowercased())",
            operation: operation,
            usingExpression: editorExpression()
        )
    }
    
    /// Policy for online users only
    public func online(operation: RLSOperation = .all) -> RLSPolicy {
        RLSPolicy(
            name: "\(tableName)_online_\(operation.rawValue.lowercased())",
            operation: operation,
            usingExpression: onlineExpression()
        )
    }
    
    // MARK: - Additional Convenience Methods
    
    /// Policy for read access (alias for authenticated SELECT)
    public func canRead(allowSuperUser: Bool = true) -> RLSPolicy {
        let expression: String
        if allowSuperUser {
            expression = combineExpressions([
                authenticatedExpression(),
                superUserExpression()
            ])
        } else {
            expression = authenticatedExpression()
        }
        
        return RLSPolicy(
            name: "\(tableName)_can_read",
            operation: .select,
            usingExpression: expression
        )
    }
    
    /// Policy for users to write their own rows
    public func canWriteOwn(operation: RLSOperation = .insert, allowSuperUser: Bool = true) -> RLSPolicy {
        let expression: String
        if allowSuperUser {
            expression = combineExpressions([
                userExpression(),
                superUserExpression()
            ])
        } else {
            expression = userExpression()
        }
        
        return RLSPolicy(
            name: "\(tableName)_can_write_own",
            operation: operation,
            usingExpression: "true",
            withCheckExpression: expression
        )
    }
    
    /// Policy for users to update their own rows
    public func canUpdateOwn(allowSuperUser: Bool = true) -> RLSPolicy {
        let expression: String
        if allowSuperUser {
            expression = combineExpressions([
                userExpression(),
                superUserExpression()
            ])
        } else {
            expression = userExpression()
        }
        
        return RLSPolicy(
            name: "\(tableName)_can_update_own",
            operation: .update,
            usingExpression: expression,
            withCheckExpression: expression
        )
    }
    
    /// Policy for users to delete if they own the row OR are superuser
    public func canDeleteIfSuperuser(allowSuperUser: Bool = true) -> RLSPolicy {
        let expression: String
        if allowSuperUser {
            expression = combineExpressions([
                userExpression(),
                superUserExpression()
            ])
        } else {
            expression = userExpression()
        }
        
        return RLSPolicy(
            name: "\(tableName)_can_delete_if_superuser",
            operation: .delete,
            usingExpression: expression
        )
    }
    
    /// Policy for users who own the row OR have specific permission
    public func userOrPermission(
        name: String,
        operation: RLSOperation = .all,
        permission: String,
        permissionColumn: String = "role"
    ) -> RLSPolicy {
        let expression = combineExpressions([
            userExpression(),
            """
            EXISTS (
                SELECT 1 FROM public.\(usersTableName)
                WHERE id = auth.uid()::text
                AND \(permissionColumn) = '\(permission)'
            )
            """
        ])
        
        return RLSPolicy(
            name: name,
            operation: operation,
            usingExpression: expression,
            withCheckExpression: operation == .insert || operation == .update || operation == .all ? expression : nil
        )
    }
    
    /// Custom policy with SQL expression
    public func custom(
        name: String,
        operation: RLSOperation = .all,
        usingExpression: String,
        withCheckExpression: String? = nil
    ) -> RLSPolicy {
        RLSPolicy(
            name: name,
            operation: operation,
            usingExpression: usingExpression,
            withCheckExpression: withCheckExpression
        )
    }
    
    /// Policy using Supabase auth.uid()
    public func usingAuthUid(
        operation: RLSOperation = .all,
        column: String? = nil,
        function: String = "auth.uid()::text",
        allowSuperUser: Bool = true
    ) -> RLSPolicy {
        let col = column ?? userIdColumn
        var expression = "\(col) = \(function)"
        
        if allowSuperUser {
            expression = combineExpressions([
                expression,
                superUserExpression()
            ])
        }
        
        return RLSPolicy(
            name: "\(tableName)_auth_uid_\(operation.rawValue.lowercased())",
            operation: operation,
            usingExpression: expression,
            withCheckExpression: operation == .insert || operation == .update || operation == .all 
                ? expression 
                : nil
        )
    }
    
    /// Policy using custom function
    public func usingFunction(
        name: String,
        operation: RLSOperation = .all,
        functionCall: String,
        withCheckFunction: String? = nil
    ) -> RLSPolicy {
        RLSPolicy(
            name: name,
            operation: operation,
            usingExpression: functionCall,
            withCheckExpression: withCheckFunction
        )
    }
}

// MARK: - Zyra Table

/// Zyra table that includes metadata
public struct ZyraTable: Hashable {
    public let name: String
    public let powerSyncTable: PowerSync.Table
    public let columns: [ColumnMetadata]
    public let primaryKey: String
    public let defaultOrderBy: String
    public let rlsPolicies: [RLSPolicy]
    
    // Store original column builders for many-to-many relationship detection
    private let originalColumnBuilders: [ColumnBuilder]
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    
    public static func == (lhs: ZyraTable, rhs: ZyraTable) -> Bool {
        return lhs.name == rhs.name
    }
    
    /// Initialize with fluent API
    /// Automatically adds: id (primary key), created_at, updated_at columns
    public init(
        name: String,
        primaryKey: String = "id",
        defaultOrderBy: String = "created_at DESC",
        columns: [ColumnBuilder],
        rlsPolicies: [RLSPolicy] = []
    ) {
        self.name = name
        self.primaryKey = primaryKey
        self.defaultOrderBy = defaultOrderBy
        self.rlsPolicies = rlsPolicies
        self.originalColumnBuilders = columns
        
        // Build metadata for all columns
        var allColumns = columns.map { $0.build() }
        
        // Automatically add standard columns if not already present
        let columnNames = Set(allColumns.map { $0.name.lowercased() })
        
        // Add id column if not present (or use provided primaryKey)
        if !columnNames.contains(primaryKey.lowercased()) {
            let idColumn = ColumnBuilder(name: primaryKey, powerSyncColumn: .text(primaryKey))
                .notNull()
                .build()
            allColumns.insert(idColumn, at: 0)
        }
        
        // Add created_at if not present
        if !columnNames.contains("created_at") {
            let createdAtColumn = ColumnBuilder(name: "created_at", powerSyncColumn: .text("created_at"))
                .default(.now)
                .notNull()
                .build()
            allColumns.append(createdAtColumn)
        }
        
        // Add updated_at if not present
        if !columnNames.contains("updated_at") {
            let updatedAtColumn = ColumnBuilder(name: "updated_at", powerSyncColumn: .text("updated_at"))
                .default(.now)
                .nullable()
                .build()
            allColumns.append(updatedAtColumn)
        }
        
        self.columns = allColumns
        
        // Create PowerSync table from columns, excluding the id column
        // PowerSync automatically adds id column, so we shouldn't include it
        let powerSyncColumns = self.columns
            .filter { $0.name.lowercased() != primaryKey.lowercased() }
            .map { $0.powerSyncColumn }
        self.powerSyncTable = PowerSync.Table(
            name: name,
            columns: powerSyncColumns
        )
    }
    
    /// Get original column builders (for many-to-many relationship detection)
    internal func getOriginalColumnBuilders() -> [ColumnBuilder] {
        return originalColumnBuilders
    }
    
    /// Get all enums used by this table
    public func getEnums() -> Set<DatabaseEnum> {
        return Set(columns.compactMap { $0.enumType })
    }
    
    /// Get all tables referenced by foreign keys in this table
    public func getReferencedTables() -> Set<String> {
        return Set(columns.compactMap { $0.foreignKey?.referencedTable })
    }
    
    /// Convert to PowerSync Table (for Schema)
    public func toPowerSyncTable() -> PowerSync.Table {
        return powerSyncTable
    }
    
    /// Generate TableFieldConfig automatically
    public func toTableFieldConfig() -> TableFieldConfig {
        let allFields = columns.map { $0.name }
        
        let encryptedFields = columns
            .filter { $0.isEncrypted }
            .map { $0.name }
        
        let integerFields = columns
            .filter { $0.swiftType == .integer }
            .map { $0.name }
        
        let booleanFields = columns
            .filter { $0.swiftType == .boolean }
            .map { $0.name }
        
        return TableFieldConfig(
            allFields: allFields,
            encryptedFields: encryptedFields,
            integerFields: integerFields,
            booleanFields: booleanFields,
            defaultOrderBy: defaultOrderBy
        )
    }
    
    // MARK: - Foreign Key Operations
    
    /// Generate SQL foreign key constraints
    public func generateForeignKeyConstraints() -> [String] {
        return columns.compactMap { column in
            guard let fk = column.foreignKey else { return nil }
            
            let constraintName = "\(name)_\(column.name)_fkey"
            let constraint = "CONSTRAINT \"\(constraintName)\" FOREIGN KEY (\(column.name)) REFERENCES \"\(fk.referencedTable)\" (\(fk.referencedColumn)) ON UPDATE \(fk.onUpdate.sqlString) ON DELETE \(fk.onDelete.sqlString)"
            return constraint.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    /// Get all foreign key relationships
    public func getForeignKeys() -> [(column: String, foreignKey: ForeignKey)] {
        return columns.compactMap { column in
            guard let fk = column.foreignKey else { return nil }
            return (column.name, fk)
        }
    }
    
    // MARK: - SQL Generation
    
    /// Generate SQL CREATE TABLE statement with defaults, foreign keys, and triggers
    public func generateCreateTableSQL() -> String {
        var columnDefinitions: [String] = []
        
        // Add primary key
        columnDefinitions.append("\(primaryKey) TEXT PRIMARY KEY")
        
        // Add each column with its definition (skip primary key since already added)
        for column in columns {
            // Skip primary key column since it's already added above
            if column.name.lowercased() == primaryKey.lowercased() {
                continue
            }
            
            var colDef = column.name
            
            // Add type
            if let enumType = column.enumType {
                colDef += " \"\(enumType.name)\""
            } else if column.swiftType == .date {
                colDef += " TIMESTAMPTZ"
            } else {
                colDef += " TEXT"
            }
            
            // Add NOT NULL if required
            if !column.isNullable {
                colDef += " NOT NULL"
            }
            
            // Add default value if present
            if let defaultValue = column.defaultValue {
                if defaultValue.contains("(") || defaultValue.uppercased() == "NOW()" || defaultValue.uppercased() == "CURRENT_TIMESTAMP" {
                    colDef += " DEFAULT \(defaultValue)"
                } else {
                    colDef += " DEFAULT '\(defaultValue)'"
                }
            }
            
            columnDefinitions.append(colDef)
        }
        
        // Add foreign key constraints
        let fkConstraints = generateForeignKeyConstraints()
        let allConstraints = columnDefinitions + fkConstraints
        
        var sql = "CREATE TABLE \"\(name)\" (\n"
        sql += "    \(allConstraints.joined(separator: ",\n    "))\n"
        sql += ");"
        
        // Generate trigger for updated_at if present
        if let updatedAtColumn = columns.first(where: { $0.name.lowercased() == "updated_at" }) {
            sql += "\n\n"
            sql += generateUpdatedAtTrigger()
        }
        
        return sql
    }
    
    /// Generate PostgreSQL trigger function and trigger for automatic updated_at updates
    public func generateUpdatedAtTrigger() -> String {
        let functionName = "\(name.replacingOccurrences(of: "-", with: "_"))_update_updated_at"
        let triggerName = "\(name.replacingOccurrences(of: "-", with: "_"))_updated_at_trigger"
        
        return """
        -- Function to update updated_at timestamp
        CREATE OR REPLACE FUNCTION \(functionName)()
        RETURNS TRIGGER AS $$
        BEGIN
            NEW.updated_at = NOW();
            RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;
        
        -- Trigger to automatically update updated_at on row update
        CREATE TRIGGER \(triggerName)
        BEFORE UPDATE ON "\(name)"
        FOR EACH ROW
        EXECUTE FUNCTION \(functionName)();
        """
    }
    
    /// Generate just the trigger SQL (without CREATE TABLE)
    public func generateUpdatedAtTriggerOnly() -> String? {
        guard columns.contains(where: { $0.name.lowercased() == "updated_at" }) else { return nil }
        return generateUpdatedAtTrigger()
    }
    
    /// Generate CREATE TABLE SQL only (without triggers)
    public func generateCreateTableSQLOnly() -> String {
        var columnDefinitions: [String] = []
        
        // Add primary key
        columnDefinitions.append("\(primaryKey) TEXT PRIMARY KEY")
        
        // Add each column with its definition (skip primary key since already added)
        for column in columns {
            // Skip primary key column since it's already added above
            if column.name.lowercased() == primaryKey.lowercased() {
                continue
            }
            
            var colDef = column.name
            
            // Add type
            if let enumType = column.enumType {
                colDef += " \"\(enumType.name)\""
            } else if column.swiftType == .date {
                colDef += " TIMESTAMPTZ"
            } else {
                colDef += " TEXT"
            }
            
            // Add NOT NULL if required
            if !column.isNullable {
                colDef += " NOT NULL"
            }
            
            // Add UNIQUE constraint if required
            if column.isUnique {
                colDef += " UNIQUE"
            }
            
            // Add default value if present
            if let defaultValue = column.defaultValue {
                if defaultValue.contains("(") || defaultValue.uppercased() == "NOW()" || defaultValue.uppercased() == "CURRENT_TIMESTAMP" {
                    colDef += " DEFAULT \(defaultValue)"
                } else {
                    colDef += " DEFAULT '\(defaultValue)'"
                }
            }
            
            columnDefinitions.append(colDef)
        }
        
        // Add foreign key constraints
        let fkConstraints = generateForeignKeyConstraints()
        let allConstraints = columnDefinitions + fkConstraints
        
        var sql = "CREATE TABLE \"\(name)\" (\n"
        sql += "    \(allConstraints.joined(separator: ",\n    "))\n"
        sql += ");"
        
        return sql
    }
    
    // MARK: - RLS Generation
    
    /// Generate RLS SQL (enable RLS and create policies)
    /// Special handling for users table: users can only view/update their own record, not insert/delete
    public func generateRLSSQL() -> String {
        guard !rlsPolicies.isEmpty else {
            return ""
        }
        
        var sql: [String] = []
        
        // Enable RLS on the table
        sql.append("-- Enable Row Level Security")
        sql.append("ALTER TABLE \"\(name)\" ENABLE ROW LEVEL SECURITY;")
        sql.append("")
        
        // Check if this is a users table (ends with "users" or is exactly "users")
        let isUsersTable = name.lowercased().hasSuffix("users") || name.lowercased() == "users"
        
        if isUsersTable {
            // Users table: special policies
            // Users can only view their own record
            // Users can update their own record (except id)
            // Users cannot insert or delete (handled by auth.signup/auth.users)
            sql.append("-- Users table policies (read-only except self-update)")
            sql.append("CREATE POLICY \"\(name)_select_own\"")
            sql.append("ON \"\(name)\" AS PERMISSIVE FOR SELECT")
            sql.append("USING (id = auth.uid()::text);")
            sql.append("")
            
            sql.append("CREATE POLICY \"\(name)_update_own\"")
            sql.append("ON \"\(name)\" AS PERMISSIVE FOR UPDATE")
            sql.append("USING (id = auth.uid()::text)")
            sql.append("WITH CHECK (id = auth.uid()::text);")
            sql.append("")
            
            // Note: INSERT and DELETE are handled by Supabase Auth
            // Users cannot directly insert/delete records in the users table
        } else {
            // Regular table: create policies as defined
            sql.append("-- RLS Policies")
            for policy in rlsPolicies {
                sql.append(generatePolicySQL(policy))
                sql.append("")
            }
        }
        
        return sql.joined(separator: "\n")
    }
    
    /// Generate SQL for a single policy
    private func generatePolicySQL(_ policy: RLSPolicy) -> String {
        var sql = "CREATE POLICY \"\(policy.name)\""
        
        // Add table name
        sql += " ON \"\(name)\""
        
        // Add policy type (PERMISSIVE/RESTRICTIVE)
        sql += " AS \(policy.policyType.rawValue)"
        
        // Add operation
        sql += " FOR \(policy.operation.rawValue)"
        
        // Add USING expression
        sql += " USING (\(policy.usingExpression))"
        
        // Add WITH CHECK expression if present
        if let withCheck = policy.withCheckExpression {
            sql += " WITH CHECK (\(withCheck))"
        }
        
        sql += ";"
        
        return sql
    }
    
    /// Check if RLS is enabled for this table
    public var hasRLS: Bool {
        return !rlsPolicies.isEmpty
    }
    
    /// Get RLS policy builder for this table
    public func rls(
        userIdColumn: String = "user_id",
        usersTableName: String = "users",
        isSuperUserColumn: String = "is_superuser",
        isOnlineColumn: String = "is_online"
    ) -> RLSPolicyBuilder {
        return RLSPolicyBuilder(
            tableName: name,
            userIdColumn: userIdColumn,
            usersTableName: usersTableName,
            isSuperUserColumn: isSuperUserColumn,
            isOnlineColumn: isOnlineColumn
        )
    }
    
    // MARK: - Swift Model Generation
    
    /// Generate Swift model struct code
    public func generateSwiftModel(modelName: String? = nil) -> String {
        // Note: dbPrefix should be provided by the app configuration
        let structName = modelName ?? toPascalCase(name)
        
        var code = "// MARK: - \(structName)\n\n"
        code += "struct \(structName): Codable, Identifiable, Hashable {\n"
        
        // Generate properties
        var properties: [String] = []
        var codingKeys: [String] = []
        
        for column in columns {
            let swiftName = toCamelCase(column.name)
            let swiftType = column.swiftType.toSwiftType(isNullable: column.isNullable, enumType: column.enumType)
            
            properties.append("    let \(swiftName): \(swiftType)")
            
            // Add CodingKey if name differs from Swift name
            if column.name != swiftName {
                codingKeys.append("        case \(swiftName) = \"\(column.name)\"")
            } else {
                codingKeys.append("        case \(swiftName)")
            }
        }
        
        // Add enum definitions if any columns use enums
        var enumDefinitions: [String] = []
        var addedEnums = Set<String>()
        
        for column in columns {
            if let enumType = column.enumType, !addedEnums.contains(enumType.name) {
                addedEnums.insert(enumType.name)
                let enumName = enumType.name
                    .replacingOccurrences(of: "_", with: " ")
                    .split(separator: " ")
                    .map { $0.capitalized }
                    .joined()
                
                var enumCode = "\n    enum \(enumName): String, Codable {\n"
                var enumCases: [String] = []
                for value in enumType.values {
                    let caseName = value
                        .replacingOccurrences(of: "-", with: "_")
                        .replacingOccurrences(of: " ", with: "_")
                        .replacingOccurrences(of: ".", with: "_")
                    enumCases.append("        case \(caseName) = \"\(value)\"")
                }
                enumCode += enumCases.joined(separator: "\n")
                enumCode += "\n    }"
                enumDefinitions.append(enumCode)
            }
        }
        
        if !enumDefinitions.isEmpty {
            code += enumDefinitions.joined(separator: "\n")
            code += "\n\n"
        }
        
        code += properties.joined(separator: "\n")
        code += "\n\n"
        code += "    enum CodingKeys: String, CodingKey {\n"
        code += codingKeys.joined(separator: "\n")
        code += "\n    }\n"
        code += "}\n"
        
        return code
    }
    
    /// Generate standalone Swift model file
    public func generateSwiftModelFile(modelName: String? = nil) -> String {
        let structName = modelName ?? toPascalCase(name)
        
        var code = "import Foundation\n\n"
        code += generateSwiftModel(modelName: modelName)
        
        return code
    }
    
    // MARK: - Drizzle Schema Generation
    
    /// Generate Drizzle ORM schema code (TypeScript)
    public func generateDrizzleSchema(tableVariableName: String? = nil, includeImports: Bool = false, dbPrefix: String = "") -> String {
        let varName = tableVariableName ?? toCamelCase(name.replacingOccurrences(of: dbPrefix, with: ""))
        let tableName = name.replacingOccurrences(of: dbPrefix, with: "")
        
        var code = ""
        
        // Add imports if requested
        if includeImports {
            code += "import { sql } from \"drizzle-orm\";\n"
            code += "import { createTable, pgTableCreator, text, integer, boolean, timestamp, uuid, pgEnum } from \"drizzle-orm/pg-core\";\n"
            code += "import { foreignKey } from \"drizzle-orm/pg-core\";\n"
            if !dbPrefix.isEmpty {
                code += "import { AppConfig } from \"AppConfig\";\n\n"
                code += "const createTable = pgTableCreator(\n"
                code += "  (name) => `${AppConfig.DBprefix}${name}`,\n"
                code += ");\n\n"
            } else {
                code += "\n"
                code += "const createTable = pgTableCreator(() => \"\");\n\n"
            }
        }
        
        code += "// \(tableName) table\n"
        code += "export const \(varName) = createTable(\n"
        code += "  \"\(tableName)\",\n"
        code += "  (d) => ({\n"
        
        // Generate column definitions
        var drizzleColumns: [String] = []
        
        for column in columns {
            let drizzleColumn = generateDrizzleColumn(column, dbPrefix: dbPrefix)
            drizzleColumns.append("    \(drizzleColumn)")
        }
        
        code += drizzleColumns.joined(separator: ",\n")
        code += "\n  }),\n"
        
        // Add foreign key constraints
        let fkConstraints = generateDrizzleForeignKeys(dbPrefix: dbPrefix)
        if !fkConstraints.isEmpty {
            code += "  (t) => [\n"
            code += fkConstraints.map { "    \($0)" }.joined(separator: ",\n")
            code += "\n  ]\n"
        }
        
        code += ");\n"
        
        return code
    }
    
    /// Generate standalone Drizzle table file
    public func generateDrizzleTableFile(tableVariableName: String? = nil) -> String {
        return generateDrizzleSchema(tableVariableName: tableVariableName, includeImports: true)
    }
    
    /// Generate Drizzle column definition
    private func generateDrizzleColumn(_ column: ColumnMetadata, dbPrefix: String = "") -> String {
        let columnName = column.name
        var def = "\(columnName): "
        
        // Determine Drizzle column type
        if let enumType = column.enumType {
            let enumVarName = toCamelCase(enumType.name.replacingOccurrences(of: dbPrefix, with: ""))
            def += "\(enumVarName)"
        } else {
            switch column.swiftType {
            case .string:
                def += "d.text()"
            case .integer:
                def += "d.integer()"
            case .boolean:
                def += "d.boolean()"
            case .double:
                def += "d.real()"
            case .uuid:
                def += "d.text()"
            case .date:
                def += "d.timestamp({ withTimezone: true })"
            case .enum:
                def += "d.text()"
            case .object:
                def += "d.text()"
            case .array:
                def += "d.text()"
            }
        }
        
        // Add modifiers
        if column.name == primaryKey {
            def += ".primaryKey()"
        }
        
        if !column.isNullable {
            def += ".notNull()"
        }
        
        if column.isUnique && column.name != primaryKey {
            def += ".unique()"
        }
        
        // Handle updated_at special case
        if column.name.lowercased() == "updated_at" {
            def += ".$onUpdate(() => new Date())"
        }
        
        if let defaultValue = column.defaultValue {
            if column.name.lowercased() != "updated_at" {
                if defaultValue.contains("(") || defaultValue.uppercased() == "NOW()" || defaultValue.uppercased() == "CURRENT_TIMESTAMP" {
                    def += ".default(sql`\(defaultValue)`)"
                } else {
                    if column.swiftType == .string || column.swiftType == .uuid {
                        def += ".default(\"\(defaultValue)\")"
                    } else if column.swiftType == .integer {
                        def += ".default(\(defaultValue))"
                    } else if column.swiftType == .boolean {
                        def += ".default(\(defaultValue))"
                    } else {
                        def += ".default(\"\(defaultValue)\")"
                    }
                }
            }
        }
        
        return def
    }
    
    /// Generate Drizzle foreign key constraints
    private func generateDrizzleForeignKeys(dbPrefix: String = "") -> [String] {
        return columns.compactMap { column in
            guard let fk = column.foreignKey else { return nil }
            
            let referencedTableVar = toCamelCase(fk.referencedTable.replacingOccurrences(of: dbPrefix, with: ""))
            
            return "foreignKey({ columns: [t.\(column.name)], foreignKeys: [\(referencedTableVar)({ columns: [\(referencedTableVar).\(fk.referencedColumn)] }) ] })"
        }
    }
    
    // MARK: - Helper Methods
    
    /// Convert table name to PascalCase
    private func toPascalCase(_ name: String) -> String {
        let components = name
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
        
        return components.joined()
    }
    
    /// Convert snake_case to camelCase
    private func toCamelCase(_ name: String) -> String {
        let components = name.split(separator: "_")
        guard let first = components.first else { return name }
        
        let rest = components.dropFirst().map { $0.capitalized }
        return first.lowercased() + rest.joined()
    }
    
    // MARK: - Zod Schema Generation
    
    /// Generate Zod schema code (TypeScript)
    public func generateZodSchema(dbPrefix: String = "") -> String {
        let schemaName = toCamelCase(name.replacingOccurrences(of: dbPrefix, with: ""))
        
        var code = "import { z } from \"zod\";\n\n"
        code += "export const \(schemaName)Schema = z.object({\n"
        
        var zodFields: [String] = []
        
        for column in columns {
            var fieldDef = generateZodField(column)
            zodFields.append("  \(fieldDef)")
        }
        
        code += zodFields.joined(separator: ",\n")
        code += "\n});\n\n"
        code += "export type \(toPascalCase(name.replacingOccurrences(of: dbPrefix, with: ""))) = z.infer<typeof \(schemaName)Schema>;\n"
        
        return code
    }
    
    /// Generate Zod field definition
    private func generateZodField(_ column: ColumnMetadata) -> String {
        var field = "\(column.name): "
        
        // Base type
        var zodType: String
        
        if let enumType = column.enumType {
            let enumValues = enumType.values.map { "\"\($0)\"" }.joined(separator: ", ")
            zodType = "z.enum([\(enumValues)])"
        } else {
            switch column.swiftType {
            case .string:
                zodType = "z.string()"
            case .integer:
                zodType = "z.number().int()"
            case .boolean:
                zodType = "z.boolean()"
            case .double:
                zodType = "z.number()"
            case .uuid:
                zodType = "z.string().uuid()"
            case .date:
                zodType = "z.string().datetime()"
            default:
                zodType = "z.string()"
            }
        }
        
        field += zodType
        
        // Add validations
        if let minLength = column.minLength {
            field += ".min(\(minLength))"
        }
        
        if let maxLength = column.maxLength {
            field += ".max(\(maxLength))"
        }
        
        if column.isEmail == true {
            field += ".email()"
        }
        
        if column.isUrl == true {
            field += ".url()"
        }
        
        if let intMin = column.intMin {
            field += ".min(\(intMin))"
        }
        
        if let intMax = column.intMax {
            field += ".max(\(intMax))"
        }
        
        // Handle nullable/optional
        if column.isNullable {
            if column.defaultValue == nil {
                field += ".nullable()"
            } else {
                field += ".optional()"
            }
        }
        
        return field
    }
    
    // MARK: - Prisma Schema Generation
    
    /// Generate Prisma model code
    public func generatePrismaModel(modelName: String? = nil, dbPrefix: String = "") -> String {
        let modelName = modelName ?? toPascalCase(name.replacingOccurrences(of: dbPrefix, with: ""))
        let tableName = name.replacingOccurrences(of: dbPrefix, with: "")
        
        var code = "model \(modelName) {\n"
        
        // Generate fields
        var fields: [String] = []
        
        for column in columns {
            let fieldName = toCamelCase(column.name)
            var fieldDef = "  \(fieldName)"
            
            // Check if this is a foreign key
            if let fk = column.foreignKey {
                // Foreign key field - use the type of the referenced column
                let referencedFieldName = toCamelCase(fk.referencedColumn)
                
                // Foreign key fields use the same type as the referenced column
                // Since we're generating for a single table, we'll use String for now
                // The type will be correct when generating the full schema
                fieldDef += " " + generatePrismaType(column)
                
                // Add relation attribute
                let relatedModelName = toPascalCase(fk.referencedTable.replacingOccurrences(of: dbPrefix, with: ""))
                let relationName = "\(modelName)\(relatedModelName)"
                var attributes: [String] = ["@relation(fields: [\(fieldName)], references: [\(referencedFieldName)], name: \"\(relationName)\")"]
                
                // Map column name if different from field name
                if column.name != fieldName {
                    attributes.append("@map(\"\(column.name)\")")
                }
                
                // Make optional if nullable
                if column.isNullable {
                    fieldDef += "?"
                }
                
                fieldDef += " " + attributes.joined(separator: " ")
                fields.append(fieldDef)
                continue
            }
            
            // Regular field (not a foreign key)
            fieldDef += " " + generatePrismaType(column)
            
            // Add attributes
            var attributes: [String] = []
            
            // Primary key
            if column.name == primaryKey {
                attributes.append("@id")
                
                // Add default if it's a UUID or cuid
                if column.isUuid == true {
                    attributes.append("@default(uuid())")
                } else if column.isCuid == true {
                    attributes.append("@default(cuid())")
                } else if column.isCuid2 == true {
                    attributes.append("@default(cuid())")
                } else if column.isNanoid == true {
                    attributes.append("@default(cuid())")
                }
            }
            
            // Unique constraint
            if column.isUnique && column.name != primaryKey {
                attributes.append("@unique")
            }
            
            // Default values
            if let defaultValue = column.defaultValue {
                if column.name.lowercased() == "created_at" {
                    attributes.append("@default(now())")
                } else if column.name.lowercased() == "updated_at" {
                    attributes.append("@updatedAt")
                } else if defaultValue.uppercased() == "NOW()" || defaultValue.uppercased() == "CURRENT_TIMESTAMP" {
                    if column.name.lowercased() == "updated_at" {
                        attributes.append("@updatedAt")
                    } else {
                        attributes.append("@default(now())")
                    }
                } else if column.swiftType == .boolean {
                    let boolValue = defaultValue.lowercased() == "true"
                    attributes.append("@default(\(boolValue))")
                } else if column.swiftType == .integer {
                    attributes.append("@default(\(defaultValue))")
                } else {
                    attributes.append("@default(\"\(defaultValue)\")")
                }
            }
            
            // Map column name if different from field name
            if column.name != fieldName {
                attributes.append("@map(\"\(column.name)\")")
            }
            
            // Add attributes
            if !attributes.isEmpty {
                fieldDef += " " + attributes.joined(separator: " ")
            }
            
            // Make optional if nullable
            if column.isNullable && column.name != primaryKey {
                fieldDef += "?"
            }
            
            fields.append(fieldDef)
        }
        
        code += fields.joined(separator: "\n")
        
        // Add table mapping
        if tableName != modelName.lowercased() {
            code += "\n\n  @@map(\"\(tableName)\")"
        }
        
        // Note: RLS policies are database-level features and should not be included in Prisma schema
        // RLS is managed via SQL migrations, not Prisma schema
        
        code += "\n}"
        
        return code
    }
    
    /// Generate Prisma type string for a column
    private func generatePrismaType(_ column: ColumnMetadata) -> String {
        if let enumType = column.enumType {
            return toPascalCase(enumType.name)
        }
        
        switch column.swiftType {
        case .string:
            if column.isUuid == true {
                return "String"
            } else if column.isDate == true || column.name.lowercased().contains("_at") {
                return "DateTime"
            } else {
                return "String"
            }
        case .integer:
            return "Int"
        case .boolean:
            return "Boolean"
        case .double:
            return "Float"
        case .uuid:
            return "String"
        case .date:
            return "DateTime"
        case .enum:
            return "String"
        case .object:
            return "String" // JSON stored as String in Prisma
        case .array:
            return "String" // JSON stored as String in Prisma
        }
    }
}

// MARK: - Zyra Schema

/// Complete schema definition with tables and enums
public struct ZyraSchema {
    public let tables: [ZyraTable]
    public let enums: [DatabaseEnum]
    private let joinTables: [ZyraTable]
    
    public init(tables: [ZyraTable], enums: [DatabaseEnum] = [], dbPrefix: String = "") {
        var processedTables = tables
        var generatedJoinTables: [ZyraTable] = []
        var tableMap: [String: ZyraTable] = [:]
        
        // Build table map for quick lookup
        for table in tables {
            tableMap[table.name] = table
        }
        
        // Process each table to find many-to-many relationships
        for (index, table) in processedTables.enumerated() {
            var updatedColumns: [ColumnBuilder] = []
            var tableJoinTables: [ZyraTable] = []
            
            // Check each original column builder for many-to-many relationships
            for columnBuilder in table.getOriginalColumnBuilders() {
                // Check if this column builder has a many-to-many relationship
                if let manyToMany = columnBuilder._manyToManyRelationship {
                    // Find the referenced table
                    let referencedTableName = manyToMany.table2
                    
                    // Check if the referenced table exists
                    if let referencedTable = tableMap[referencedTableName] {
                        // Create the join table with correct table1 name
                        let joinTable = ManyToManyRelationship(
                            table1: table.name,
                            table2: referencedTableName,
                            joinTableName: manyToMany.joinTableName,
                            table1Column: nil, // Auto-generate based on table1 name
                            table2Column: manyToMany.table2Column.isEmpty ? nil : manyToMany.table2Column,
                            table1ReferenceRemoved: manyToMany.table1ReferenceRemoved,
                            table1ReferenceUpdated: manyToMany.table1ReferenceUpdated,
                            table2ReferenceRemoved: manyToMany.table2ReferenceRemoved,
                            table2ReferenceUpdated: manyToMany.table2ReferenceUpdated,
                            additionalColumns: manyToMany.additionalColumns
                        ).generateJoinTable(dbPrefix: dbPrefix)
                        
                        tableJoinTables.append(joinTable)
                        // Don't add this column to the table - it's just a marker
                        continue
                    } else {
                        print("⚠️ Warning: Referenced table '\(referencedTableName)' not found for many-to-many relationship")
                        // Keep the column but remove the many-to-many marker
                        var cleanBuilder = columnBuilder
                        cleanBuilder._manyToManyRelationship = nil
                        updatedColumns.append(cleanBuilder)
                        continue
                    }
                }
                
                // Regular column - keep it
                updatedColumns.append(columnBuilder)
            }
            
            // Rebuild the table without many-to-many marker columns
            if updatedColumns.count != table.getOriginalColumnBuilders().count {
                let newTable = ZyraTable(
                    name: table.name,
                    primaryKey: table.primaryKey,
                    defaultOrderBy: table.defaultOrderBy,
                    columns: updatedColumns,
                    rlsPolicies: table.rlsPolicies
                )
                processedTables[index] = newTable
                tableMap[table.name] = newTable
            }
            
            // Add generated join tables
            generatedJoinTables.append(contentsOf: tableJoinTables)
        }
        
        // Combine regular tables with join tables
        self.tables = processedTables
        self.joinTables = generatedJoinTables
        
        // Collect all enums from tables
        var allEnums = Set(enums)
        for table in processedTables {
            allEnums.formUnion(table.getEnums())
        }
        for table in generatedJoinTables {
            allEnums.formUnion(table.getEnums())
        }
        self.enums = Array(allEnums)
    }
    
    /// Get all tables including join tables
    public var allTables: [ZyraTable] {
        return tables + joinTables
    }
    
    /// Check if a table is a join table
    public func isJoinTable(_ table: ZyraTable) -> Bool {
        return joinTableNames.contains(table.name)
    }
    
    /// Get join table names
    public var joinTableNames: Set<String> {
        return Set(joinTables.map { $0.name })
    }
    
    /// Generate PowerSync bucket definitions (YAML format)
    /// Automatically separates tables into global and user-specific buckets based on user_id column
    public func generatePowerSyncBucketDefinitions(dbPrefix: String = "", userIdColumn: String = "user_id") -> String {
        var yaml = "bucket_definitions:\n"
        
        // Separate tables into global and user-specific
        var globalTables: [ZyraTable] = []
        var userTables: [ZyraTable] = []
        
        // Check if users table exists (should be global for reading, but user-specific for other operations)
        let usersTableName = dbPrefix.isEmpty ? "users" : "\(dbPrefix)users"
        
        for table in allTables {
            // Users table is special - skip it from bucket definitions (handled by Supabase Auth)
            if table.name.lowercased() == usersTableName.lowercased() || table.name.lowercased().hasSuffix("users") {
                continue
            }
            
            // Check if table has user_id column
            let hasUserId = table.columns.contains { $0.name.lowercased() == userIdColumn.lowercased() }
            
            if hasUserId {
                userTables.append(table)
            } else {
                globalTables.append(table)
            }
        }
        
        // Generate global bucket
        if !globalTables.isEmpty {
            yaml += "  global:\n"
            yaml += "    data:\n"
            yaml += "      # Sync all rows\n"
            yaml += "      #   - SELECT * FROM \"power_sync_counters\"\n"
            yaml += "      \n"
            
            // Sort global tables: regular first, then join tables
            let sortedGlobalTables = globalTables.sorted { table1, table2 in
                let isJoin1 = isJoinTable(table1)
                let isJoin2 = isJoinTable(table2)
                
                if isJoin1 != isJoin2 {
                    return !isJoin1
                }
                
                return table1.name < table2.name
            }
            
            var hasRegularTables = false
            var hasJoinTables = false
            
            for table in sortedGlobalTables {
                let isJoin = isJoinTable(table)
                
                // Add section comment for join tables
                if isJoin && !hasJoinTables && hasRegularTables {
                    yaml += "      \n"
                    yaml += "      # Join Tables\n"
                    hasJoinTables = true
                }
                
                var tableName = formatTableNameForPowerSync(table: table, dbPrefix: dbPrefix)
                yaml += "      - SELECT * FROM \"\(tableName)\"\n"
                
                if !isJoin && !hasRegularTables {
                    hasRegularTables = true
                }
            }
        }
        
        // Generate user-specific bucket
        if !userTables.isEmpty {
            yaml += "\n"
            yaml += "  by_user:\n"
            yaml += "    # Only sync rows belonging to the user\n"
            yaml += "    parameters: SELECT request.user_id() as user_id\n"
            yaml += "    data:\n"
            
            // Sort user tables: regular first, then join tables
            let sortedUserTables = userTables.sorted { table1, table2 in
                let isJoin1 = isJoinTable(table1)
                let isJoin2 = isJoinTable(table2)
                
                if isJoin1 != isJoin2 {
                    return !isJoin1
                }
                
                return table1.name < table2.name
            }
            
            var hasRegularTables = false
            var hasJoinTables = false
            
            for table in sortedUserTables {
                let isJoin = isJoinTable(table)
                
                // Add section comment for join tables
                if isJoin && !hasJoinTables && hasRegularTables {
                    yaml += "      \n"
                    yaml += "      # Join Tables\n"
                    hasJoinTables = true
                }
                
                var tableName = formatTableNameForPowerSync(table: table, dbPrefix: dbPrefix)
                
                // Find the user_id column name (case-sensitive)
                let userIdCol = table.columns.first { $0.name.lowercased() == userIdColumn.lowercased() }?.name ?? userIdColumn
                
                // Generate WHERE clause
                yaml += "      - SELECT * FROM \"\(tableName)\" WHERE \"\(tableName)\".\"\(userIdCol)\" = bucket.user_id\n"
                
                if !isJoin && !hasRegularTables {
                    hasRegularTables = true
                }
            }
        }
        
        return yaml
    }
    
    /// Format table name for PowerSync bucket definitions
    private func formatTableNameForPowerSync(table: ZyraTable, dbPrefix: String) -> String {
        var tableName = table.name
        
        // Join tables get "JOIN-" prefix in PowerSync bucket definitions
        if isJoinTable(table) {
            if !dbPrefix.isEmpty && tableName.hasPrefix(dbPrefix) {
                let nameWithoutPrefix = String(tableName.dropFirst(dbPrefix.count))
                tableName = "\(dbPrefix)JOIN-\(nameWithoutPrefix)"
            } else {
                tableName = "JOIN-\(tableName)"
            }
        }
        
        return tableName
    }
    
    /// Generate complete migration SQL with proper ordering
    public func generateMigrationSQL() -> String {
        var sql: [String] = []
        
        // 1. Create all enums first
        if !enums.isEmpty {
            sql.append("-- Create Enums")
            for dbEnum in enums {
                sql.append(dbEnum.generateCreateEnumSQL())
            }
            sql.append("")
        }
        
        // 2. Create tables in topological order (including join tables)
        sql.append("-- Create Tables")
        let allTables = tables + joinTables
        let orderedTables = topologicalSortTables(allTables: allTables)
        
        for table in orderedTables {
            sql.append(table.generateCreateTableSQLOnly())
            sql.append("")
            
            // Add trigger if updated_at exists
            if let triggerSQL = table.generateUpdatedAtTriggerOnly() {
                sql.append(triggerSQL)
                sql.append("")
            }
            
            // Add RLS if policies exist
            if table.hasRLS {
                sql.append(table.generateRLSSQL())
                sql.append("")
            }
        }
        
        return sql.joined(separator: "\n\n")
    }
    
    /// Topologically sort tables based on foreign key dependencies
    private func topologicalSortTables(allTables: [ZyraTable]? = nil) -> [ZyraTable] {
        let tablesToSort = allTables ?? tables
        var dependencies: [String: Set<String>] = [:]
        var tableMap: [String: ZyraTable] = [:]
        
        for table in tablesToSort {
            tableMap[table.name] = table
            dependencies[table.name] = table.getReferencedTables()
        }
        
        var dependents: [String: Set<String>] = [:]
        for tableName in tableMap.keys {
            dependents[tableName] = []
        }
        
        for (tableName, deps) in dependencies {
            for dep in deps {
                if tableMap[dep] != nil {
                    dependents[dep] = (dependents[dep] ?? []).union([tableName])
                }
            }
        }
        
        var inDegree: [String: Int] = [:]
        for tableName in tableMap.keys {
            inDegree[tableName] = dependencies[tableName]?.count ?? 0
        }
        
        var queue: [String] = []
        for (tableName, degree) in inDegree {
            if degree == 0 {
                queue.append(tableName)
            }
        }
        
        var result: [ZyraTable] = []
        
        while !queue.isEmpty {
            let current = queue.removeFirst()
            
            if let table = tableMap[current] {
                result.append(table)
            }
            
            if let dependentsOfCurrent = dependents[current] {
                for dependent in dependentsOfCurrent {
                    if let currentDegree = inDegree[dependent] {
                        inDegree[dependent] = currentDegree - 1
                        if inDegree[dependent] == 0 {
                            queue.append(dependent)
                        }
                    }
                }
            }
        }
        
        if result.count != tablesToSort.count {
            print("⚠️ Warning: Circular dependency detected or missing referenced table")
            return tablesToSort
        }
        
        return result
    }
    
    /// Convert to PowerSync Schema
    public func toPowerSyncSchema() -> PowerSync.Schema {
        return PowerSync.Schema(
            tables: allTables.map { $0.toPowerSyncTable() }
        )
    }
    
    /// Generate Drizzle schema code for all tables and enums
    public func generateDrizzleSchema(dbPrefix: String = "") -> String {
        var code = "import { sql } from \"drizzle-orm\";\n"
        code += "import { createTable, pgTableCreator, text, integer, boolean, timestamp, uuid, pgEnum } from \"drizzle-orm/pg-core\";\n"
        code += "import { foreignKey } from \"drizzle-orm/pg-core\";\n"
        if !dbPrefix.isEmpty {
            code += "import { AppConfig } from \"AppConfig\";\n\n"
            code += "const createTable = pgTableCreator(\n"
            code += "  (name) => `${AppConfig.DBprefix}${name}`,\n"
            code += ");\n\n"
        } else {
            code += "\n"
            code += "const createTable = pgTableCreator(() => \"\");\n\n"
        }
        
        // Generate enums first
        if !enums.isEmpty {
            code += "// Enums\n"
            for dbEnum in enums {
                let enumName = toCamelCase(dbEnum.name.replacingOccurrences(of: dbPrefix, with: ""))
                let values = dbEnum.values.map { "\"\($0)\"" }.joined(separator: ", ")
                code += "export const \(enumName) = pgEnum(\"\(dbEnum.name)\", [\(values)]);\n"
            }
            code += "\n"
        }
        
        // Generate tables in dependency order (including join tables)
        code += "// Tables\n"
        let allTables = tables + joinTables
        let orderedTables = topologicalSortTables(allTables: allTables)
        for table in orderedTables {
            code += table.generateDrizzleSchema(includeImports: false, dbPrefix: dbPrefix)
            code += "\n"
        }
        
        // Generate schema export
        code += "\n// Schema export\n"
        code += "export const schema = {\n"
        for table in orderedTables {
            let varName = toCamelCase(table.name.replacingOccurrences(of: dbPrefix, with: ""))
            code += "  \(varName),\n"
        }
        code += "};\n"
        
        return code
    }
    
    /// Helper to convert table name to camelCase
    private func toCamelCase(_ name: String) -> String {
        let components = name.split(separator: "_")
        guard let first = components.first else { return name }
        
        let rest = components.dropFirst().map { $0.capitalized }
        return first.lowercased() + rest.joined()
    }
    
    /// Helper to convert name to PascalCase
    private func toPascalCase(_ name: String) -> String {
        let components = name
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
        
        return components.joined()
    }
    
    /// Generate Swift model code for all tables in schema
    public func generateAllSwiftModels() -> String {
        var code = ""
        
        // Generate enum definitions first
        if !enums.isEmpty {
            code += "// MARK: - Enums\n\n"
            for dbEnum in enums {
                let enumName = dbEnum.name
                    .replacingOccurrences(of: "_", with: " ")
                    .split(separator: " ")
                    .map { $0.capitalized }
                    .joined()
                
                code += "enum \(enumName): String, Codable {\n"
                for value in dbEnum.values {
                    let caseName = value
                        .replacingOccurrences(of: "-", with: "_")
                        .replacingOccurrences(of: " ", with: "_")
                        .replacingOccurrences(of: ".", with: "_")
                    code += "    case \(caseName) = \"\(value)\"\n"
                }
                code += "}\n\n"
            }
        }
        
        // Generate table models
        code += "// MARK: - Models\n\n"
        code += allTables.map { $0.generateSwiftModel() }.joined(separator: "\n\n")
        
        return code
    }
    
    /// Generate Zod schema code for all tables and enums
    public func generateZodSchema(dbPrefix: String = "") -> String {
        var code = "import { z } from \"zod\";\n\n"
        
        // Generate enum schemas first
        if !enums.isEmpty {
            code += "// Enums\n"
            for dbEnum in enums {
                let enumName = toPascalCase(dbEnum.name.replacingOccurrences(of: dbPrefix, with: ""))
                let values = dbEnum.values.map { "\"\($0)\"" }.joined(separator: ", ")
                code += "export const \(enumName)Schema = z.enum([\(values)]);\n"
                code += "export type \(enumName) = z.infer<typeof \(enumName)Schema>;\n\n"
            }
        }
        
        // Generate table schemas
        code += "// Tables\n"
        let allTables = tables + joinTables
        let orderedTables = topologicalSortTables(allTables: allTables)
        for table in orderedTables {
            code += table.generateZodSchema(dbPrefix: dbPrefix)
            code += "\n"
        }
        
        return code
    }
    
    /// Generate complete Prisma schema file
    public func generatePrismaSchema(
        dbPrefix: String = "",
        provider: String = "postgresql",
        datasourceUrl: String = "env(\"DATABASE_URL\")"
    ) -> String {
        var code = "// This file was auto-generated from ZyraForm schema\n"
        code += "// Run `npx prisma format` to format this file\n\n"
        
        // Generator block
        code += "generator client {\n"
        code += "  provider = \"prisma-client-js\"\n"
        code += "}\n\n"
        
        // Datasource block
        code += "datasource db {\n"
        code += "  provider = \"\(provider)\"\n"
        code += "  url      = \(datasourceUrl)\n"
        code += "}\n\n"
        
        // Generate enums first
        if !enums.isEmpty {
            for dbEnum in enums {
                let enumName = toPascalCase(dbEnum.name.replacingOccurrences(of: dbPrefix, with: ""))
                code += "enum \(enumName) {\n"
                
                for value in dbEnum.values {
                    // Convert enum value to PascalCase for Prisma
                    // Handle both snake_case and regular strings
                    let prismaValue: String
                    if value.contains("_") {
                        prismaValue = value.split(separator: "_")
                            .map { $0.capitalized }
                            .joined()
                    } else {
                        // Capitalize first letter if single word
                        prismaValue = value.capitalized
                    }
                    code += "  \(prismaValue)\n"
                }
                
                code += "}\n\n"
            }
        }
        
        // Generate models in dependency order
        let allTables = tables + joinTables
        let orderedTables = topologicalSortTables(allTables: allTables)
        for table in orderedTables {
            code += table.generatePrismaModel(dbPrefix: dbPrefix)
            code += "\n\n"
        }
        
        return code.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Generate Prisma schema and write to file path
    public func generatePrismaSchemaFile(
        at path: String,
        dbPrefix: String = "",
        provider: String = "postgresql",
        datasourceUrl: String = "env(\"DATABASE_URL\")"
    ) throws {
        let prismaSchema = generatePrismaSchema(
            dbPrefix: dbPrefix,
            provider: provider,
            datasourceUrl: datasourceUrl
        )
        try prismaSchema.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
