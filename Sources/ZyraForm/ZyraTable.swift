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
    public let enumType: ZyraEnum?
    public let nestedSchema: NestedSchema?
    public let checkConstraint: String?
    
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
        case bigInt
        case bool
        case double
        case decimal(precision: Int, scale: Int)
        case uuid
        case date
        case `enum`(ZyraEnum)
        case object(NestedSchema)
        case array(NestedSchema)
    }
}

extension ColumnMetadata.SwiftColumnType {
    var enumValue: ZyraEnum? {
        if case .enum(let dbEnum) = self {
            return dbEnum
        }
        return nil
    }
    
    /// Convert to Swift type string
    public func toSwiftType(isNullable: Bool, enumType: ZyraEnum? = nil) -> String {
        let type: String
        switch self {
        case .string:
            type = "String"
        case .integer:
            type = "Int"
        case .bigInt:
            type = "Int64"
        case .bool:
            type = "Bool"
        case .double:
            type = "Double"
        case .decimal:
            type = "Decimal"
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

// MARK: - Object Storage Strategy

/// Strategy for storing nested objects/arrays in the database
public enum ObjectStorageStrategy: Equatable {
    /// Flatten nested fields into columns with a prefix delimiter
    /// Example: address object becomes address-addr_ln1, address-addr_ln2, etc.
    case flattened(prefix: String? = nil)
    
    /// Store as JSONB (PostgreSQL) or JSON (MySQL/SQLite)
    case jsonb
    
    /// Store in a separate table with a foreign key relationship
    /// - tableName: Name of the separate table (auto-generated if nil)
    /// - relationshipType: One-to-one or one-to-many
    case separateTable(tableName: String? = nil, relationshipType: RelationshipType = .oneToOne)
}

/// Relationship type for separate table strategy
public enum RelationshipType: Equatable {
    /// One-to-one: Parent has exactly one child record
    case oneToOne
    /// One-to-many: Parent can have multiple child records (for arrays)
    case oneToMany
}

// MARK: - Nested Schema

/// Nested schema for objects and arrays (supports recursion)
/// Uses indirect enum to break circular reference with ColumnBuilder
public indirect enum NestedSchema: Equatable {
    case object(fields: [String: ColumnBuilder], strategy: ObjectStorageStrategy = .flattened(prefix: nil))
    case array(elementType: ColumnBuilder, strategy: ObjectStorageStrategy = .flattened(prefix: nil))
    
    public init(fields: [String: ColumnBuilder], strategy: ObjectStorageStrategy = .flattened(prefix: nil)) {
        self = .object(fields: fields, strategy: strategy)
    }
    
    public init(elementType: ColumnBuilder, strategy: ObjectStorageStrategy = .flattened(prefix: nil)) {
        self = .array(elementType: elementType, strategy: strategy)
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
        if case .object(let fields, _) = self {
            return fields
        }
        return [:]
    }
    
    public var elementType: ColumnBuilder? {
        if case .array(let elementType, _) = self {
            return elementType
        }
        return nil
    }
    
    public var strategy: ObjectStorageStrategy {
        switch self {
        case .object(_, let strategy):
            return strategy
        case .array(_, let strategy):
            return strategy
        }
    }
    
    // Custom Equatable implementation
    // Note: Compares schema structure, ignoring function closures in ColumnBuilder
    public static func == (lhs: NestedSchema, rhs: NestedSchema) -> Bool {
        guard lhs.strategy == rhs.strategy else { return false }
        
        switch (lhs, rhs) {
        case (.object(let lhsFields, _), .object(let rhsFields, _)):
            // Compare field names and basic properties, ignoring closures
            return lhsFields.keys == rhsFields.keys &&
                   lhsFields.keys.allSatisfy { key in
                       let lhsBuilder = lhsFields[key]!
                       let rhsBuilder = rhsFields[key]!
                       return lhsBuilder.name == rhsBuilder.name &&
                              lhsBuilder.swiftType == rhsBuilder.swiftType &&
                              lhsBuilder.isNullable == rhsBuilder.isNullable
                   }
        case (.array(let lhsElement, _), .array(let rhsElement, _)):
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
    public var enumType: ZyraEnum? = nil
    public var checkConstraint: String? = nil
    
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
        builder.swiftType = .bool
        return builder
    }
    
    public func double() -> ColumnBuilder {
        var builder = self
        builder.swiftType = .double
        return builder
    }
    
    public func bigint() -> ColumnBuilder {
        var builder = self
        builder.swiftType = .bigInt
        return builder
    }
    
    public func decimal(precision: Int = 10, scale: Int = 2) -> ColumnBuilder {
        var builder = self
        builder.swiftType = .decimal(precision: precision, scale: scale)
        return builder
    }
    
    /// Add a CHECK constraint to the column
    /// - Parameter expression: SQL expression for the check constraint (e.g., "age >= 0", "price > 0")
    /// - Returns: ColumnBuilder with check constraint
    /// - Example:
    ///   ```swift
    ///   zf.integer("age").check("age >= 0 AND age <= 150")
    ///   zf.real("price").check("price > 0")
    ///   ```
    public func check(_ expression: String) -> ColumnBuilder {
        var builder = self
        builder.checkConstraint = expression
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
    
    public func `enum`(_ enumType: ZyraEnum) -> ColumnBuilder {
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
    /// - Important: Foreign keys should reference primary keys. The referenced column must be a primary key or unique column.
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
    
    /// Create a foreign key relationship to another ZyraTable
    /// Automatically uses the referenced table's primary key (validated)
    /// - Parameters:
    ///   - table: The referenced ZyraTable instance
    ///   - referenceUpdated: Action when referenced row is updated (defaults to .cascade)
    ///   - referenceRemoved: Action when referenced row is deleted (defaults to .setNull)
    /// - Returns: ColumnBuilder with foreign key relationship
    /// - Precondition: Foreign keys must reference primary keys. This method always uses the table's primary key.
    /// - Example:
    ///   ```swift
    ///   zf.text("user_type_id").references(UserTypes)
    ///   // Always references UserTypes.primaryKey
    ///   ```
    public func references(
        _ table: ZyraTable,
        referenceUpdated: ForeignKeyAction = .cascade,
        referenceRemoved: ForeignKeyAction = .setNull
    ) -> ColumnBuilder {
        // Always use the primary key - call the String-based method explicitly
        return self.references(
            table.name,
            column: table.primaryKey,
            referenceUpdated: referenceUpdated,
            referenceRemoved: referenceRemoved
        )
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
    
    /// Create a nested object field
    /// - Parameters:
    ///   - schema: Dictionary of field names to ColumnBuilders
    ///   - strategy: Storage strategy (default: flattened with column name as prefix)
    /// - Returns: ColumnBuilder with object type
    /// - Example:
    ///   ```swift
    ///   zf.text("address").object([
    ///       "addr_ln1": zf.text("addr_ln1").notNull(),
    ///       "city": zf.text("city").notNull()
    ///   ], strategy: .flattened())
    ///   // Generates: address-addr_ln1, address-city columns
    ///   ```
    public func object(_ schema: [String: ColumnBuilder], strategy: ObjectStorageStrategy = .flattened(prefix: nil)) -> ColumnBuilder {
        var builder = self
        
        // If strategy is flattened with nil prefix, use the column name as prefix
        let finalStrategy: ObjectStorageStrategy
        if case .flattened(let prefix) = strategy, prefix == nil {
            finalStrategy = .flattened(prefix: self.name)
        } else {
            finalStrategy = strategy
        }
        
        let nested = NestedSchema(fields: schema, strategy: finalStrategy)
        builder.nestedSchema = nested
        builder.swiftType = .object(nested)
        return builder
    }
    
    /// Create a nested array field
    /// - Parameters:
    ///   - elementType: ColumnBuilder for array elements
    ///   - strategy: Storage strategy (default: flattened with column name as prefix)
    /// - Returns: ColumnBuilder with array type
    public func array(_ elementType: ColumnBuilder, strategy: ObjectStorageStrategy = .flattened(prefix: nil)) -> ColumnBuilder {
        var builder = self
        
        // If strategy is flattened with nil prefix, use the column name as prefix
        let finalStrategy: ObjectStorageStrategy
        if case .flattened(let prefix) = strategy, prefix == nil {
            finalStrategy = .flattened(prefix: self.name)
        } else {
            finalStrategy = strategy
        }
        
        let nested = NestedSchema(elementType: elementType, strategy: finalStrategy)
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
            checkConstraint: checkConstraint,
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
public struct ZyraEnum: Hashable {
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
    
    /// Create a big integer column (BIGINT type in SQL)
    public static func bigint(_ name: String) -> ColumnBuilder {
        return PowerSync.Column.bigint(name)
    }
    
    /// Create a decimal column (DECIMAL/NUMERIC type in SQL)
    /// - Parameters:
    ///   - name: Column name
    ///   - precision: Total number of digits (default: 10)
    ///   - scale: Number of digits after decimal point (default: 2)
    public static func decimal(_ name: String, precision: Int = 10, scale: Int = 2) -> ColumnBuilder {
        return PowerSync.Column.decimal(name, precision: precision, scale: scale)
    }
    
    /// Create a date column (DATE type in SQL)
    public static func date(_ name: String) -> ColumnBuilder {
        return PowerSync.Column.text(name).date()
    }
    
    /// Create a time column (TIME type in SQL)
    public static func time(_ name: String) -> ColumnBuilder {
        return PowerSync.Column.text(name).time()
    }
    
    /// Create a timestamp with timezone column (TIMESTAMPTZ type in PostgreSQL)
    public static func timestampz(_ name: String) -> ColumnBuilder {
        return PowerSync.Column.text(name).isoDateTime()
    }
    
    /// Create a UUID column (validates UUID format)
    public static func uuid(_ name: String) -> ColumnBuilder {
        return PowerSync.Column.text(name).uuid()
    }
    
    /// Create a URL column (validates URL format)
    public static func url(_ name: String) -> ColumnBuilder {
        return PowerSync.Column.text(name).url()
    }
    
    /// Create an email column (validates email format)
    public static func email(_ name: String) -> ColumnBuilder {
        return PowerSync.Column.text(name).email()
    }
    
    /// Create a boolean column (BOOLEAN type in SQL)
    /// - Parameter name: Column name
    /// - Returns: ColumnBuilder with boolean type
    /// - Example:
    ///   ```swift
    ///   zf.bool("is_active").default(false).notNull()
    ///   zf.bool("is_template").default(true).nullable()
    ///   ```
    public static func bool(_ name: String) -> ColumnBuilder {
        return PowerSync.Column.text(name).bool()
    }
    
    /// Create a nested object column
    /// - Parameters:
    ///   - name: Column name (used as prefix for flattened strategy)
    ///   - schema: Dictionary of field names to ColumnBuilders
    ///   - strategy: Storage strategy (default: flattened with column name as prefix)
    /// - Returns: ColumnBuilder with object type
    /// - Example:
    ///   ```swift
    ///   zf.object("address", schema: [
    ///       "addr_ln1": zf.text("addr_ln1").notNull(),
    ///       "city": zf.text("city").notNull()
    ///   ], strategy: .flattened())
    ///   // Generates: address-addr_ln1, address-city columns
    ///   ```
    public static func object(_ name: String, schema: [String: ColumnBuilder], strategy: ObjectStorageStrategy = .flattened(prefix: nil)) -> ColumnBuilder {
        let builder = ColumnBuilder(name: name, powerSyncColumn: PowerSync.Column.text(name))
        
        // If strategy is flattened with nil prefix, use the column name as prefix
        let finalStrategy: ObjectStorageStrategy
        if case .flattened(let prefix) = strategy, prefix == nil {
            finalStrategy = .flattened(prefix: name)
        } else {
            finalStrategy = strategy
        }
        
        return builder.object(schema, strategy: finalStrategy)
    }
    
    /// Create a nested array column
    /// - Parameters:
    ///   - name: Column name (used as prefix for flattened strategy)
    ///   - elementType: ColumnBuilder for array elements
    ///   - strategy: Storage strategy (default: flattened with column name as prefix)
    /// - Returns: ColumnBuilder with array type
    public static func array(_ name: String, elementType: ColumnBuilder, strategy: ObjectStorageStrategy = .flattened(prefix: nil)) -> ColumnBuilder {
        let builder = ColumnBuilder(name: name, powerSyncColumn: PowerSync.Column.text(name))
        
        // If strategy is flattened with nil prefix, use the column name as prefix
        let finalStrategy: ObjectStorageStrategy
        if case .flattened(let prefix) = strategy, prefix == nil {
            finalStrategy = .flattened(prefix: name)
        } else {
            finalStrategy = strategy
        }
        
        return builder.array(elementType, strategy: finalStrategy)
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
    
    /// Create a big integer column (BIGINT type in SQL)
    public static func bigint(_ name: String) -> ColumnBuilder {
        return ColumnBuilder(name: name, powerSyncColumn: .integer(name))
            .bigint()
    }
    
    /// Create a decimal column (DECIMAL/NUMERIC type in SQL)
    /// - Parameters:
    ///   - name: Column name
    ///   - precision: Total number of digits (default: 10)
    ///   - scale: Number of digits after decimal point (default: 2)
    public static func decimal(_ name: String, precision: Int = 10, scale: Int = 2) -> ColumnBuilder {
        return ColumnBuilder(name: name, powerSyncColumn: .real(name))
            .decimal(precision: precision, scale: scale)
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

/// RLS role types for who can access
public enum RLSRole: String, CaseIterable {
    case anonymous = "anonymous"
    case authenticated = "authenticated"
    case unauthenticated = "unauthenticated"
    case admin = "admin"
    case superadmin = "superadmin"
}

/// RLS access operations
public enum RLSAccess: String, CaseIterable {
    case read = "read"
    case write = "write"
    case update = "update"
    case delete = "delete"
    
    /// Convert to RLSOperation for SQL generation
    var operation: RLSOperation {
        switch self {
        case .read:
            return .select
        case .write:
            return .insert
        case .update:
            return .update
        case .delete:
            return .delete
        }
    }
}

/// RLS policy builder for common patterns
/// Uses Supabase RBAC (Role-Based Access Control) instead of superuser permissions
/// Reference: https://supabase.com/features/role-based-access-control
public struct RLSPolicyBuilder {
    private let tableName: String
    private let userIdColumn: String
    private let usersTableName: String
    private let roleColumn: String
    private let isOnlineColumn: String
    
    public init(
        tableName: String,
        userIdColumn: String = "user_id",
        usersTableName: String = "users",
        roleColumn: String = "role",
        isOnlineColumn: String = "is_online"
    ) {
        self.tableName = tableName
        self.userIdColumn = userIdColumn
        self.usersTableName = usersTableName
        self.roleColumn = roleColumn
        self.isOnlineColumn = isOnlineColumn
    }
    
    // MARK: - Permission Helpers
    
    /// Generate SQL expression for checking if user owns the row
    private func userExpression() -> String {
        return "\(userIdColumn)::uuid = (auth.uid())::uuid"
    }
    
    /// Generate SQL expression for checking if user is authenticated
    private func authenticatedExpression() -> String {
        return "auth.uid() IS NOT NULL"
    }
    
    /// Generate SQL expression for checking if user is anonymous (not authenticated)
    private func anonymousExpression() -> String {
        return "auth.uid() IS NULL"
    }
    
    /// Generate SQL expression for checking if user has any of the specified roles
    /// Uses Supabase RBAC - roles are stored in the role column
    private func roleExpression(_ roles: [String]) -> String {
        guard !roles.isEmpty else { return "false" }
        if roles.count == 1 {
            return """
            EXISTS (
                SELECT 1 FROM public.\(usersTableName)
                WHERE id = (auth.uid())::uuid
                AND \(roleColumn) = '\(roles[0])'
            )
            """
        } else {
            let rolesList = roles.map { "'\($0)'" }.joined(separator: ", ")
            return """
            EXISTS (
                SELECT 1 FROM public.\(usersTableName)
                WHERE id = (auth.uid())::uuid
                AND \(roleColumn) IN (\(rolesList))
            )
            """
        }
    }
    
    /// Generate SQL expression for checking if user is admin
    private func adminExpression() -> String {
        return roleExpression(["admin"])
    }
    
    /// Generate SQL expression for checking if user is editor (admin or editor)
    private func editorExpression() -> String {
        return roleExpression(["admin", "editor"])
    }
    
    /// Generate SQL expression for checking if user is online
    private func onlineExpression() -> String {
        return """
        EXISTS (
            SELECT 1 FROM public.\(usersTableName)
            WHERE id = (auth.uid())::uuid
            AND \(isOnlineColumn) = true
        )
        """
    }
    
    /// Combine multiple expressions with OR
    private func combineExpressions(_ expressions: [String]) -> String {
        return expressions.joined(separator: " OR ")
    }
    
    // MARK: - Common Policy Patterns
    
    /// Users can only access their own rows (optionally allow specific roles)
    /// Uses Supabase RBAC for role-based permissions
    /// - Parameter allowRoles: Array of role names that can access any row (e.g., ["admin"])
    public func canAccessOwn(allowRoles: [String] = []) -> RLSPolicy {
        let expression: String
        if !allowRoles.isEmpty {
            expression = combineExpressions([
                userExpression(),
                roleExpression(allowRoles)
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
    public func canReadAllModifyOwn(allowRoles: [String] = []) -> RLSPolicy {
        RLSPolicy(
            name: "\(tableName)_read_all_modify_own",
            operation: .select,
            usingExpression: "true"
        )
    }
    
    /// Users can read all but only modify their own (separate policies)
    /// - Parameter allowRoles: Array of role names that can modify any row (e.g., ["admin"])
    public func canReadAllModifyOwnSeparate(allowRoles: [String] = []) -> [RLSPolicy] {
        let modifyExpression: String
        if !allowRoles.isEmpty {
            modifyExpression = combineExpressions([
                userExpression(),
                roleExpression(allowRoles)
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
                withCheckExpression: !allowRoles.isEmpty ? modifyExpression : userExpression()
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
    
    /// Policy for users with specific role(s)
    /// Uses Supabase RBAC - checks if user has any of the specified roles
    /// - Parameter roles: Array of role names (e.g., ["admin", "super_admin"])
    /// - Parameter operation: The operation this policy applies to
    public func hasRole(_ roles: [String], operation: RLSOperation = .all) -> RLSPolicy {
        RLSPolicy(
            name: "\(tableName)_role_\(roles.joined(separator: "_"))_\(operation.rawValue.lowercased())",
            operation: operation,
            usingExpression: roleExpression(roles)
        )
    }
    
    /// Policy for users with a specific role
    /// Convenience method for single role check
    public func hasRole(_ role: String, operation: RLSOperation = .all) -> RLSPolicy {
        hasRole([role], operation: operation)
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
    /// - Parameter allowRoles: Array of role names that can read all rows (e.g., ["admin"])
    public func canRead(allowRoles: [String] = []) -> RLSPolicy {
        let expression: String
        if !allowRoles.isEmpty {
            expression = combineExpressions([
                authenticatedExpression(),
                roleExpression(allowRoles)
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
    /// - Parameter operation: The operation (default: insert)
    /// - Parameter allowRoles: Array of role names that can write any row (e.g., ["admin"])
    public func canWriteOwn(operation: RLSOperation = .insert, allowRoles: [String] = []) -> RLSPolicy {
        let expression: String
        if !allowRoles.isEmpty {
            expression = combineExpressions([
                userExpression(),
                roleExpression(allowRoles)
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
    /// - Parameter allowRoles: Array of role names that can update any row (e.g., ["admin"])
    public func canUpdateOwn(allowRoles: [String] = []) -> RLSPolicy {
        let expression: String
        if !allowRoles.isEmpty {
            expression = combineExpressions([
                userExpression(),
                roleExpression(allowRoles)
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
    
    /// Policy for users to delete if they own the row OR have specific roles
    /// - Parameter allowRoles: Array of role names that can delete any row (e.g., ["admin"])
    public func canDeleteOwn(allowRoles: [String] = []) -> RLSPolicy {
        let expression: String
        if !allowRoles.isEmpty {
            expression = combineExpressions([
                userExpression(),
                roleExpression(allowRoles)
            ])
        } else {
            expression = userExpression()
        }
        
        return RLSPolicy(
            name: "\(tableName)_can_delete_own",
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
                WHERE id = (auth.uid())::uuid
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
    /// - Parameter operation: The operation this policy applies to
    /// - Parameter column: The column to compare (defaults to userIdColumn)
    /// - Parameter function: The function to use (defaults to "(auth.uid())::uuid")
    /// - Parameter allowRoles: Array of role names that can bypass the user_id check (e.g., ["admin"])
    public func usingAuthUid(
        operation: RLSOperation = .all,
        column: String? = nil,
        function: String = "(auth.uid())::uuid",
        allowRoles: [String] = []
    ) -> RLSPolicy {
        let col = column ?? userIdColumn
        var expression = "\(col)::uuid = \(function)"
        
        if !allowRoles.isEmpty {
            expression = combineExpressions([
                expression,
                roleExpression(allowRoles)
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

// MARK: - New Fluent RLS Policy Builder

/// New fluent API for building RLS policies
/// Example:
/// ```
/// .rls()
///   .who([.authenticated, .admin])
///   .permissive()
///   .access([.read, .write, .update])
///   .match("user_id = auth.uid()")
/// ```
public struct FluentRLSPolicyBuilder {
    private let tableName: String
    private let userIdColumn: String
    private let usersTableName: String
    private let roleColumn: String
    
    private var who: [RLSRole] = []
    private var policyType: RLSPolicyType = .permissive
    private var access: [RLSAccess] = []
    private var matchExpression: String?
    private var useOwnRow: Bool = false
    
    public init(
        tableName: String,
        userIdColumn: String = "user_id",
        usersTableName: String = "public.user_public",
        roleColumn: String = "role"
    ) {
        self.tableName = tableName
        self.userIdColumn = userIdColumn
        self.usersTableName = usersTableName
        self.roleColumn = roleColumn
    }
    
    /// Define who can access (roles array)
    /// - Parameter roles: Array of roles (anonymous, authenticated, unauthenticated, admin, superadmin)
    public func who(_ roles: [RLSRole]) -> FluentRLSPolicyBuilder {
        var builder = self
        builder.who = roles
        return builder
    }
    
    /// Set policy type to permissive (default)
    public func permissive() -> FluentRLSPolicyBuilder {
        var builder = self
        builder.policyType = .permissive
        return builder
    }
    
    /// Set policy type to restrictive
    public func restrictive() -> FluentRLSPolicyBuilder {
        var builder = self
        builder.policyType = .restrictive
        return builder
    }
    
    /// Define access operations (read, write, update, delete)
    /// - Parameter operations: Array of access operations
    public func access(_ operations: [RLSAccess]) -> FluentRLSPolicyBuilder {
        var builder = self
        builder.access = operations
        return builder
    }
    
    /// Custom matching expression (e.g., "user_id = auth.uid()" or "row.value = session.uuid()")
    /// - Parameter expression: SQL expression for matching rows
    public func match(_ expression: String) -> FluentRLSPolicyBuilder {
        var builder = self
        builder.matchExpression = expression
        builder.useOwnRow = false
        return builder
    }
    
    /// Use default "own row" matching (user_id = auth.uid())
    /// This is a convenience method for the most common case
    /// Equivalent to: `.match("user_id::uuid = (auth.uid())::uuid")`
    public func own() -> FluentRLSPolicyBuilder {
        var builder = self
        builder.useOwnRow = true
        builder.matchExpression = nil
        return builder
    }
    
    /// Build the RLS policies from the fluent configuration
    public func build() -> [RLSPolicy] {
        guard !who.isEmpty, !access.isEmpty else {
            return []
        }
        
        // Generate SQL expression for "who"
        let whoExpression = generateWhoExpression()
        
        // Generate match expression
        let matchExpr = matchExpression ?? (useOwnRow ? "\(userIdColumn)::uuid = (auth.uid())::uuid" : "true")
        
        // Combine expressions
        let combinedExpression: String
        if matchExpr == "true" {
            combinedExpression = whoExpression
        } else {
            combinedExpression = "(\(whoExpression)) AND (\(matchExpr))"
        }
        
        // Generate policies for each access operation
        var policies: [RLSPolicy] = []
        
        for accessOp in access {
            let operation = accessOp.operation
            let policyName = "\(tableName)_\(who.map { $0.rawValue }.joined(separator: "_"))_\(accessOp.rawValue)"
            
            // For INSERT and UPDATE, we need WITH CHECK
            let withCheck: String?
            if operation == .insert || operation == .update {
                withCheck = combinedExpression
            } else {
                withCheck = nil
            }
            
            let policy = RLSPolicy(
                name: policyName,
                operation: operation,
                policyType: policyType,
                usingExpression: combinedExpression,
                withCheckExpression: withCheck
            )
            
            policies.append(policy)
        }
        
        return policies
    }
    
    /// Generate SQL expression for "who" roles
    private func generateWhoExpression() -> String {
        var expressions: [String] = []
        
        for role in who {
            switch role {
            case .anonymous:
                expressions.append("auth.uid() IS NULL")
            case .authenticated:
                expressions.append("auth.uid() IS NOT NULL")
            case .unauthenticated:
                expressions.append("auth.uid() IS NULL")
            case .admin:
                expressions.append("""
                EXISTS (
                    SELECT 1 FROM \(usersTableName)
                    WHERE id = (auth.uid())::uuid
                    AND \(roleColumn) = 'admin'
                )
                """)
            case .superadmin:
                expressions.append("""
                EXISTS (
                    SELECT 1 FROM \(usersTableName)
                    WHERE id = (auth.uid())::uuid
                    AND \(roleColumn) = 'superadmin'
                )
                """)
            }
        }
        
        // Combine with OR (any of the roles can match)
        return expressions.joined(separator: " OR ")
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
    public func getEnums() -> Set<ZyraEnum> {
        return Set(columns.compactMap { $0.enumType })
    }
    
    /// Get all tables referenced by foreign keys in this table
    public func getReferencedTables() -> Set<String> {
        return Set(columns.compactMap { $0.foreignKey?.referencedTable })
    }
    
    /// Convenience property to access the primary key column name
    /// Allows syntax like: `table.id` instead of `table.primaryKey`
    public var id: String {
        return primaryKey
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
            .filter { $0.swiftType == .bool }
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
    
    /// Generate MySQL foreign key constraints
    public func generateMySQLForeignKeyConstraints() -> [String] {
        return columns.compactMap { column in
            guard let fk = column.foreignKey else { return nil }
            
            let constraintName = "\(name)_\(column.name)_fkey"
            let constraint = "CONSTRAINT `\(constraintName)` FOREIGN KEY (`\(column.name)`) REFERENCES `\(fk.referencedTable)` (`\(fk.referencedColumn)`) ON UPDATE \(fk.onUpdate.sqlString) ON DELETE \(fk.onDelete.sqlString)"
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
            // Encrypted fields are always TEXT (encrypted strings), regardless of swiftType
            // Validation happens on the decrypted value, but storage is always TEXT
            if column.isEncrypted {
                colDef += " TEXT"
            } else if let enumType = column.enumType {
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
    
    /// Generate column definitions for nested schema based on strategy
    /// - Parameters:
    ///   - nestedSchema: The nested schema to process
    ///   - parentColumnName: The parent column name for flattened naming
    ///   - visited: Set of visited schema paths to prevent circular references
    ///   - depth: Current recursion depth (max 10 to prevent infinite loops)
    private func generateNestedSchemaColumns(
        _ nestedSchema: NestedSchema,
        parentColumnName: String,
        visited: Set<String> = [],
        depth: Int = 0
    ) -> [String] {
        // Prevent infinite recursion
        guard depth < 10 else {
            print("⚠️ Warning: Maximum recursion depth reached for nested schema at \(parentColumnName)")
            return []
        }
        
        // Prevent circular references
        let schemaPath = "\(parentColumnName)"
        if visited.contains(schemaPath) {
            print("⚠️ Warning: Circular reference detected in nested schema at \(parentColumnName), using JSONB fallback")
            return ["\"\(parentColumnName)\" JSONB"]
        }
        
        var newVisited = visited
        newVisited.insert(schemaPath)
        var nestedColumns: [String] = []
        
        switch nestedSchema.strategy {
        case .flattened(let prefix):
            let columnPrefix = prefix ?? parentColumnName
            
            switch nestedSchema {
            case .object(let fields, _):
                // Generate flattened columns for each field
                for (fieldName, fieldBuilder) in fields.sorted(by: { $0.key < $1.key }) {
                    let flattenedName = "\(columnPrefix)-\(fieldName)"
                    let fieldMetadata = fieldBuilder.build()
                    
                    var colDef = "\"\(flattenedName)\""
                    
                    // Handle nested schemas recursively (including arrays) with cycle detection
                    if let nested = fieldMetadata.nestedSchema {
                        nestedColumns.append(contentsOf: generateNestedSchemaColumns(
                            nested,
                            parentColumnName: flattenedName,
                            visited: newVisited,
                            depth: depth + 1
                        ))
                        continue
                    }
                    
                    // Handle foreign keys in nested objects (flattened strategy)
                    // Foreign keys will be added via ALTER TABLE in generateAlterTableForForeignKeys()
                    
                    // Add type
                    if fieldMetadata.isEncrypted {
                        colDef += " TEXT"
                    } else if let enumType = fieldMetadata.enumType {
                        colDef += " \"\(enumType.name)\""
                    } else if fieldMetadata.swiftType == .date {
                        colDef += " TIMESTAMPTZ"
                    } else {
                        colDef += " TEXT"
                    }
                    
                    // Add NOT NULL if required
                    if !fieldMetadata.isNullable {
                        colDef += " NOT NULL"
                    }
                    
                    // Add UNIQUE constraint if required
                    if fieldMetadata.isUnique {
                        colDef += " UNIQUE"
                    }
                    
                    // Add default value if present
                    if let defaultValue = fieldMetadata.defaultValue {
                        if defaultValue.contains("(") || defaultValue.uppercased() == "NOW()" || defaultValue.uppercased() == "CURRENT_TIMESTAMP" {
                            colDef += " DEFAULT \(defaultValue)"
                        } else {
                            colDef += " DEFAULT '\(defaultValue)'"
                        }
                    }
                    
                    nestedColumns.append(colDef)
                }
                
            case .array(let elementType, _):
                // Arrays with flattened strategy fall back to JSONB (can't flatten arrays)
                // For PostgreSQL, we could use native array types, but JSONB is more portable
                var colDef = "\"\(parentColumnName)\" JSONB"
                let elementMetadata = elementType.build()
                if !elementMetadata.isNullable {
                    colDef += " NOT NULL"
                }
                nestedColumns.append(colDef)
            }
            
        case .jsonb:
            // Generate a single JSONB column
            var colDef = "\"\(parentColumnName)\" JSONB"
            
            // Determine nullability from nested schema
            switch nestedSchema {
            case .object(let fields, _):
                // Object is nullable if all fields are nullable (conservative approach)
                // For now, make it nullable by default
                break
            case .array(let elementType, _):
                let elementMetadata = elementType.build()
                if !elementMetadata.isNullable {
                    colDef += " NOT NULL"
                }
            }
            
            nestedColumns.append(colDef)
            
        case .separateTable:
            // Separate table strategy - don't generate columns here
            // The table will be generated separately by ZyraSchema
            // Parent table doesn't get a column for this
            break
        }
        
        return nestedColumns
    }
    
    /// Generate CREATE TABLE SQL without foreign keys (for circular dependency handling)
    public func generateCreateTableSQLWithoutFKs() -> String {
        var columnDefinitions: [String] = []
        
        // Add primary key
        columnDefinitions.append("\(primaryKey) TEXT PRIMARY KEY")
        
        // Add each column with its definition (skip primary key since already added)
        for column in columns {
            // Skip primary key column since it's already added above
            if column.name.lowercased() == primaryKey.lowercased() {
                continue
            }
            
            // Handle nested schemas
            if let nestedSchema = column.nestedSchema {
                switch nestedSchema.strategy {
                case .separateTable:
                    // Separate table strategy - skip this column
                    // The table will be generated separately
                    continue
                case .flattened, .jsonb:
                    // Generate columns for nested schema
                    let nestedCols = generateNestedSchemaColumns(nestedSchema, parentColumnName: column.name)
                    columnDefinitions.append(contentsOf: nestedCols)
                    continue
                }
            }
            
            var colDef = "\"\(column.name)\""
            
            // Add type
            if column.isEncrypted {
                colDef += " TEXT"
            } else if let enumType = column.enumType {
                colDef += " \"\(enumType.name)\""
            } else {
                switch column.swiftType {
                case .string:
                    if let maxLength = column.maxLength {
                        colDef += " VARCHAR(\(maxLength))"
                    } else {
                        colDef += " TEXT"
                    }
                case .integer:
                    colDef += " INTEGER"
                case .bigInt:
                    colDef += " BIGINT"
                case .bool:
                    colDef += " BOOLEAN"
                case .double:
                    colDef += " DOUBLE PRECISION"
                case .decimal(let precision, let scale):
                    colDef += " DECIMAL(\(precision), \(scale))"
                case .uuid:
                    colDef += " UUID"
                case .date:
                    colDef += " TIMESTAMPTZ"
                case .enum:
                    // Handled above
                    colDef += " TEXT"
                case .object, .array:
                    colDef += " JSONB"
                }
            }
            
            // Add NOT NULL if required
            if !column.isNullable {
                colDef += " NOT NULL"
            }
            
            // Add UNIQUE constraint if required
            if column.isUnique {
                colDef += " UNIQUE"
            }
            
            // Add CHECK constraint if present
            if let checkConstraint = column.checkConstraint {
                colDef += " CHECK (\(checkConstraint))"
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
        
        // NO foreign key constraints here - they'll be added with ALTER TABLE
        
        var sql = "CREATE TABLE \"\(name)\" (\n"
        sql += "    \(columnDefinitions.joined(separator: ",\n    "))\n"
        sql += ");"
        
        return sql
    }
    
    /// Collect foreign keys from nested schemas (for flattened strategy)
    /// - Parameters:
    ///   - nestedSchema: The nested schema to process
    ///   - parentColumnName: The parent column name for flattened naming
    ///   - visited: Set of visited schema paths to prevent circular references
    ///   - depth: Current recursion depth (max 10 to prevent infinite loops)
    private func collectForeignKeysFromNestedSchema(
        _ nestedSchema: NestedSchema,
        parentColumnName: String,
        visited: Set<String> = [],
        depth: Int = 0
    ) -> [(columnName: String, fk: ForeignKey)] {
        // Prevent infinite recursion
        guard depth < 10 else {
            print("⚠️ Warning: Maximum recursion depth reached for nested schema at \(parentColumnName)")
            return []
        }
        
        // Prevent circular references
        let schemaPath = "\(parentColumnName)"
        if visited.contains(schemaPath) {
            print("⚠️ Warning: Circular reference detected in nested schema at \(parentColumnName)")
            return []
        }
        
        var newVisited = visited
        newVisited.insert(schemaPath)
        var foreignKeys: [(String, ForeignKey)] = []
        
        switch nestedSchema {
        case .object(let fields, _):
            for (fieldName, fieldBuilder) in fields {
                let fieldMetadata = fieldBuilder.build()
                let flattenedName = "\(parentColumnName)-\(fieldName)"
                
                // Check for foreign key in this field
                if let fk = fieldMetadata.foreignKey {
                    foreignKeys.append((flattenedName, fk))
                }
                
                // Recursively check nested schemas (with cycle detection)
                if let nested = fieldMetadata.nestedSchema {
                    foreignKeys.append(contentsOf: collectForeignKeysFromNestedSchema(
                        nested,
                        parentColumnName: flattenedName,
                        visited: newVisited,
                        depth: depth + 1
                    ))
                }
            }
            
        case .array(let elementType, _):
            let elementMetadata = elementType.build()
            
            // Check for foreign key in array element
            if let fk = elementMetadata.foreignKey {
                // For arrays, foreign keys would be in the separate table, not here
                // But we can still collect them for reference
                foreignKeys.append((parentColumnName, fk))
            }
            
            // Recursively check nested schemas in array elements (with cycle detection)
            if let nested = elementMetadata.nestedSchema {
                foreignKeys.append(contentsOf: collectForeignKeysFromNestedSchema(
                    nested,
                    parentColumnName: parentColumnName,
                    visited: newVisited,
                    depth: depth + 1
                ))
            }
        }
        
        return foreignKeys
    }
    
    /// Generate ALTER TABLE statements for foreign keys (including nested schemas)
    public func generateAlterTableForForeignKeys() -> [String] {
        var fkStatements: [String] = []
        
        // Collect foreign keys from top-level columns
        for column in columns {
            guard let fk = column.foreignKey else { continue }
            
            let constraintName = "\(name)_\(column.name)_fkey"
            fkStatements.append("ALTER TABLE \"\(name)\" ADD CONSTRAINT \"\(constraintName)\" FOREIGN KEY (\(column.name)) REFERENCES \"\(fk.referencedTable)\" (\(fk.referencedColumn)) ON UPDATE \(fk.onUpdate.sqlString) ON DELETE \(fk.onDelete.sqlString);")
        }
        
        // Collect foreign keys from nested schemas (flattened strategy)
        for column in columns {
            guard let nestedSchema = column.nestedSchema,
                  case .flattened = nestedSchema.strategy else {
                continue
            }
            
            let nestedFKs = collectForeignKeysFromNestedSchema(nestedSchema, parentColumnName: column.name)
            for (flattenedColumnName, fk) in nestedFKs {
                let constraintName = "\(name)_\(flattenedColumnName.replacingOccurrences(of: "-", with: "_"))_fkey"
                fkStatements.append("ALTER TABLE \"\(name)\" ADD CONSTRAINT \"\(constraintName)\" FOREIGN KEY (\"\(flattenedColumnName)\") REFERENCES \"\(fk.referencedTable)\" (\(fk.referencedColumn)) ON UPDATE \(fk.onUpdate.sqlString) ON DELETE \(fk.onDelete.sqlString);")
            }
        }
        
        return fkStatements
    }
    
    /// Generate MySQL column definitions for nested schema based on strategy
    /// - Parameters:
    ///   - nestedSchema: The nested schema to process
    ///   - parentColumnName: The parent column name for flattened naming
    ///   - visited: Set of visited schema paths to prevent circular references
    ///   - depth: Current recursion depth (max 10 to prevent infinite loops)
    private func generateMySQLNestedSchemaColumns(
        _ nestedSchema: NestedSchema,
        parentColumnName: String,
        visited: Set<String> = [],
        depth: Int = 0
    ) -> [String] {
        // Prevent infinite recursion
        guard depth < 10 else {
            print("⚠️ Warning: Maximum recursion depth reached for nested schema at \(parentColumnName)")
            return []
        }
        
        // Prevent circular references
        let schemaPath = "\(parentColumnName)"
        if visited.contains(schemaPath) {
            print("⚠️ Warning: Circular reference detected in nested schema at \(parentColumnName), using JSON fallback")
            return ["`\(parentColumnName)` JSON"]
        }
        
        var newVisited = visited
        newVisited.insert(schemaPath)
        var nestedColumns: [String] = []
        
        switch nestedSchema.strategy {
        case .flattened(let prefix):
            let columnPrefix = prefix ?? parentColumnName
            
            switch nestedSchema {
            case .object(let fields, _):
                // Generate flattened columns for each field
                for (fieldName, fieldBuilder) in fields.sorted(by: { $0.key < $1.key }) {
                    let flattenedName = "\(columnPrefix)-\(fieldName)"
                    let fieldMetadata = fieldBuilder.build()
                    
                    var colDef = "`\(flattenedName)`"
                    
                    // Handle nested schemas recursively with cycle detection
                    if let nested = fieldMetadata.nestedSchema {
                        nestedColumns.append(contentsOf: generateMySQLNestedSchemaColumns(
                            nested,
                            parentColumnName: flattenedName,
                            visited: newVisited,
                            depth: depth + 1
                        ))
                        continue
                    }
                    
                    // Add MySQL type
                    if let enumType = fieldMetadata.enumType {
                        let enumValues = enumType.values.map { "'\($0)'" }.joined(separator: ", ")
                        colDef += " ENUM(\(enumValues))"
                    } else {
                        switch fieldMetadata.swiftType {
                        case .integer:
                            colDef += " INT"
                        case .bigInt:
                            colDef += " BIGINT"
                        case .bool:
                            colDef += " BOOLEAN"
                        case .double:
                            colDef += " DOUBLE"
                        case .decimal(let precision, let scale):
                            colDef += " DECIMAL(\(precision), \(scale))"
                        case .uuid:
                            colDef += " CHAR(36)"
                        case .date:
                            colDef += " DATETIME"
                        case .string:
                            if let maxLength = fieldMetadata.maxLength {
                                colDef += " VARCHAR(\(maxLength))"
                            } else {
                                colDef += " TEXT"
                            }
                        default:
                            colDef += " TEXT"
                        }
                    }
                    
                    // Add NOT NULL if required
                    if !fieldMetadata.isNullable {
                        colDef += " NOT NULL"
                    }
                    
                    // Add UNIQUE constraint if required
                    if fieldMetadata.isUnique {
                        colDef += " UNIQUE"
                    }
                    
                    // Add CHECK constraint if present
                    if let checkConstraint = fieldMetadata.checkConstraint {
                        colDef += " CHECK (\(checkConstraint))"
                    }
                    
                    // Add default value if present
                    if let defaultValue = fieldMetadata.defaultValue {
                        if defaultValue.uppercased() == "NOW()" || defaultValue.uppercased() == "CURRENT_TIMESTAMP" {
                            colDef += " DEFAULT CURRENT_TIMESTAMP"
                        } else if defaultValue.contains("(") {
                            colDef += " DEFAULT \(defaultValue)"
                        } else {
                            colDef += " DEFAULT '\(defaultValue)'"
                        }
                    }
                    
                    nestedColumns.append(colDef)
                }
                
            case .array(let elementType, _):
                // For arrays with flattened strategy, fall back to JSON
                var colDef = "`\(parentColumnName)` JSON"
                if !elementType.isNullable {
                    colDef += " NOT NULL"
                }
                nestedColumns.append(colDef)
            }
            
        case .jsonb:
            // Generate a single JSON column (MySQL uses JSON, not JSONB)
            var colDef = "`\(parentColumnName)` JSON"
            nestedColumns.append(colDef)
            
        case .separateTable:
            // Separate table strategy - don't generate columns here
            break
        }
        
        return nestedColumns
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
            
            // Handle nested schemas
            if let nestedSchema = column.nestedSchema {
                switch nestedSchema.strategy {
                case .separateTable:
                    // Separate table strategy - skip this column
                    continue
                case .flattened, .jsonb:
                    // Generate columns for nested schema
                    let nestedCols = generateNestedSchemaColumns(nestedSchema, parentColumnName: column.name)
                    columnDefinitions.append(contentsOf: nestedCols)
                    continue
                }
            }
            
            var colDef = column.name
            
            // Add type
            // Encrypted fields are always TEXT (encrypted strings), regardless of swiftType
            // Validation happens on the decrypted value, but storage is always TEXT
            if column.isEncrypted {
                colDef += " TEXT"
            } else if let enumType = column.enumType {
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
    
    // MARK: - MySQL Generation
    
    /// Generate MySQL CREATE TABLE SQL without foreign keys (for circular dependency handling)
    public func generateMySQLTableSQLWithoutFKs() -> String {
        var columnDefinitions: [String] = []
        
        // Find primary key column to determine if it's integer (for AUTO_INCREMENT)
        let primaryKeyColumn = columns.first { $0.name.lowercased() == primaryKey.lowercased() }
        let isIntegerPrimaryKey = primaryKeyColumn?.swiftType == .integer
        
        // Add primary key
        if isIntegerPrimaryKey {
            columnDefinitions.append("`\(primaryKey)` INT AUTO_INCREMENT PRIMARY KEY")
        } else {
            // UUID or text primary key
            if primaryKeyColumn?.isUuid == true {
                columnDefinitions.append("`\(primaryKey)` CHAR(36) PRIMARY KEY")
            } else {
                columnDefinitions.append("`\(primaryKey)` VARCHAR(255) PRIMARY KEY")
            }
        }
        
        // Add each column with its definition (skip primary key since already added)
        for column in columns {
            // Skip primary key column since it's already added above
            if column.name.lowercased() == primaryKey.lowercased() {
                continue
            }
            
            var colDef = "`\(column.name)`"
            
            // Add MySQL type
            if let enumType = column.enumType {
                // MySQL ENUM type
                let enumValues = enumType.values.map { "'\($0)'" }.joined(separator: ", ")
                colDef += " ENUM(\(enumValues))"
            } else {
                switch column.swiftType {
                case .integer:
                    colDef += " INT"
                case .bigInt:
                    colDef += " BIGINT"
                case .bool:
                    colDef += " BOOLEAN"
                case .double:
                    colDef += " DOUBLE"
                case .decimal(let precision, let scale):
                    colDef += " DECIMAL(\(precision), \(scale))"
                case .uuid:
                    colDef += " CHAR(36)"
                case .date:
                    colDef += " DATETIME"
                case .string:
                    // Check if there's a maxLength constraint
                    if let maxLength = column.maxLength {
                        colDef += " VARCHAR(\(maxLength))"
                    } else {
                        colDef += " TEXT"
                    }
                case .enum:
                    // Shouldn't happen, but fallback
                    colDef += " VARCHAR(255)"
                case .object, .array:
                    colDef += " JSON"
                }
            }
            
            // Add NOT NULL if required
            if !column.isNullable {
                colDef += " NOT NULL"
            }
            
            // Add UNIQUE constraint if required
            if column.isUnique {
                colDef += " UNIQUE"
            }
            
            // Add CHECK constraint if present
            if let checkConstraint = column.checkConstraint {
                colDef += " CHECK (\(checkConstraint))"
            }
            
            // Add default value if present
            if let defaultValue = column.defaultValue {
                if defaultValue.uppercased() == "NOW()" || defaultValue.uppercased() == "CURRENT_TIMESTAMP" {
                    colDef += " DEFAULT CURRENT_TIMESTAMP"
                } else if defaultValue.contains("(") {
                    colDef += " DEFAULT \(defaultValue)"
                } else {
                    colDef += " DEFAULT '\(defaultValue)'"
                }
            }
            
            columnDefinitions.append(colDef)
        }
        
        // NO foreign key constraints here - they'll be added with ALTER TABLE
        
        var sql = "CREATE TABLE `\(name)` (\n"
        sql += "    \(columnDefinitions.joined(separator: ",\n    "))\n"
        sql += ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;"
        
        return sql
    }
    
    /// Generate MySQL ALTER TABLE statements for foreign keys (including nested schemas)
    public func generateMySQLAlterTableForForeignKeys() -> [String] {
        var fkStatements: [String] = []
        
        // Collect foreign keys from top-level columns
        for column in columns {
            guard let fk = column.foreignKey else { continue }
            
            let constraintName = "\(name)_\(column.name)_fkey"
            fkStatements.append("ALTER TABLE `\(name)` ADD CONSTRAINT `\(constraintName)` FOREIGN KEY (`\(column.name)`) REFERENCES `\(fk.referencedTable)` (`\(fk.referencedColumn)`) ON UPDATE \(fk.onUpdate.sqlString) ON DELETE \(fk.onDelete.sqlString);")
        }
        
        // Collect foreign keys from nested schemas (flattened strategy)
        for column in columns {
            guard let nestedSchema = column.nestedSchema,
                  case .flattened = nestedSchema.strategy else {
                continue
            }
            
            let nestedFKs = collectForeignKeysFromNestedSchema(nestedSchema, parentColumnName: column.name)
            for (flattenedColumnName, fk) in nestedFKs {
                let constraintName = "\(name)_\(flattenedColumnName.replacingOccurrences(of: "-", with: "_"))_fkey"
                fkStatements.append("ALTER TABLE `\(name)` ADD CONSTRAINT `\(constraintName)` FOREIGN KEY (`\(flattenedColumnName)`) REFERENCES `\(fk.referencedTable)` (`\(fk.referencedColumn)`) ON UPDATE \(fk.onUpdate.sqlString) ON DELETE \(fk.onDelete.sqlString);")
            }
        }
        
        return fkStatements
    }
    
    /// Generate MySQL CREATE TABLE statement
    public func generateMySQLTableSQL() -> String {
        var columnDefinitions: [String] = []
        
        // Find primary key column to determine if it's integer (for AUTO_INCREMENT)
        let primaryKeyColumn = columns.first { $0.name.lowercased() == primaryKey.lowercased() }
        let isIntegerPrimaryKey = primaryKeyColumn?.swiftType == .integer
        
        // Add primary key
        if isIntegerPrimaryKey {
            columnDefinitions.append("`\(primaryKey)` INT AUTO_INCREMENT PRIMARY KEY")
        } else {
            // UUID or text primary key
            if primaryKeyColumn?.isUuid == true {
                columnDefinitions.append("`\(primaryKey)` CHAR(36) PRIMARY KEY")
            } else {
                columnDefinitions.append("`\(primaryKey)` VARCHAR(255) PRIMARY KEY")
            }
        }
        
        // Add each column with its definition (skip primary key since already added)
        for column in columns {
            // Skip primary key column since it's already added above
            if column.name.lowercased() == primaryKey.lowercased() {
                continue
            }
            
            // Handle nested schemas
            if let nestedSchema = column.nestedSchema {
                switch nestedSchema.strategy {
                case .separateTable:
                    // Separate table strategy - skip this column
                    continue
                case .flattened, .jsonb:
                    // Generate columns for nested schema
                    let nestedCols = generateMySQLNestedSchemaColumns(nestedSchema, parentColumnName: column.name)
                    columnDefinitions.append(contentsOf: nestedCols)
                    continue
                }
            }
            
            var colDef = "`\(column.name)`"
            
            // Add MySQL type
            if let enumType = column.enumType {
                // MySQL ENUM type
                let enumValues = enumType.values.map { "'\($0)'" }.joined(separator: ", ")
                colDef += " ENUM(\(enumValues))"
            } else {
                switch column.swiftType {
                case .integer:
                    colDef += " INT"
                case .bigInt:
                    colDef += " BIGINT"
                case .bool:
                    colDef += " BOOLEAN"
                case .double:
                    colDef += " DOUBLE"
                case .decimal(let precision, let scale):
                    colDef += " DECIMAL(\(precision), \(scale))"
                case .uuid:
                    colDef += " CHAR(36)"
                case .date:
                    colDef += " DATETIME"
                case .string:
                    // Check if there's a maxLength constraint
                    if let maxLength = column.maxLength {
                        colDef += " VARCHAR(\(maxLength))"
                    } else {
                        colDef += " TEXT"
                    }
                case .enum:
                    // Shouldn't happen, but fallback
                    colDef += " VARCHAR(255)"
                case .object, .array:
                    colDef += " JSON"
                }
            }
            
            // Add NOT NULL if required
            if !column.isNullable {
                colDef += " NOT NULL"
            }
            
            // Add UNIQUE constraint if required
            if column.isUnique {
                colDef += " UNIQUE"
            }
            
            // Add CHECK constraint if present
            if let checkConstraint = column.checkConstraint {
                colDef += " CHECK (\(checkConstraint))"
            }
            
            // Add default value if present
            if let defaultValue = column.defaultValue {
                if defaultValue.uppercased() == "NOW()" || defaultValue.uppercased() == "CURRENT_TIMESTAMP" {
                    colDef += " DEFAULT CURRENT_TIMESTAMP"
                } else if defaultValue.contains("(") {
                    colDef += " DEFAULT \(defaultValue)"
                } else {
                    colDef += " DEFAULT '\(defaultValue)'"
                }
            }
            
            columnDefinitions.append(colDef)
        }
        
        // NO foreign key constraints here - they'll be added with ALTER TABLE
        
        var sql = "CREATE TABLE `\(name)` (\n"
        sql += "    \(columnDefinitions.joined(separator: ",\n    "))\n"
        sql += ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;"
        
        return sql
    }
    
    /// Generate MySQL trigger for automatic updated_at updates
    public func generateMySQLUpdatedAtTrigger() -> String {
        let triggerName = "\(name.replacingOccurrences(of: "-", with: "_"))_updated_at_trigger"
        
        return """
        -- Trigger to automatically update updated_at on row update
        DELIMITER $$
        CREATE TRIGGER `\(triggerName)`
        BEFORE UPDATE ON `\(name)`
        FOR EACH ROW
        BEGIN
            SET NEW.updated_at = NOW();
        END$$
        DELIMITER ;
        """
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
            sql.append("USING (id = (auth.uid())::uuid);")
            sql.append("")
            
            sql.append("CREATE POLICY \"\(name)_update_own\"")
            sql.append("ON \"\(name)\" AS PERMISSIVE FOR UPDATE")
            sql.append("USING (id = (auth.uid())::uuid)")
            sql.append("WITH CHECK (id = (auth.uid())::uuid);")
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
    /// Uses Supabase RBAC (Role-Based Access Control)
    /// - Parameter userIdColumn: Name of the user_id column (default: "user_id")
    /// - Parameter usersTableName: Name of the users table (default: "users")
    /// - Parameter roleColumn: Name of the role column in users table (default: "role")
    /// - Parameter isOnlineColumn: Name of the is_online column (default: "is_online")
    public func rls(
        userIdColumn: String = "user_id",
        usersTableName: String = "users",
        roleColumn: String = "role",
        isOnlineColumn: String = "is_online"
    ) -> RLSPolicyBuilder {
        return RLSPolicyBuilder(
            tableName: name,
            userIdColumn: userIdColumn,
            usersTableName: usersTableName,
            roleColumn: roleColumn,
            isOnlineColumn: isOnlineColumn
        )
    }
    
    /// Get fluent RLS policy builder for this table (new API)
    /// Example:
    /// ```
    /// let policies = table.fluentRls()
    ///   .who([.authenticated, .admin])
    ///   .permissive()
    ///   .access([.read, .write, .update])
    ///   .own()
    ///   .build()
    /// ```
    /// - Parameter userIdColumn: Name of the user_id column (default: "user_id")
    /// - Parameter usersTableName: Name of the users table (default: "public.user_public")
    /// - Parameter roleColumn: Name of the role column in users table (default: "role")
    public func fluentRls(
        userIdColumn: String = "user_id",
        usersTableName: String = "public.user_public",
        roleColumn: String = "role"
    ) -> FluentRLSPolicyBuilder {
        return FluentRLSPolicyBuilder(
            tableName: name,
            userIdColumn: userIdColumn,
            usersTableName: usersTableName,
            roleColumn: roleColumn
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
            // Handle nested schemas with flattened strategy
            if let nestedSchema = column.nestedSchema,
               case .flattened(let prefix) = nestedSchema.strategy {
                let columnPrefix = prefix ?? column.name
                switch nestedSchema {
                case .object(let fields, _):
                    // Generate flattened columns
                    for (fieldName, fieldBuilder) in fields.sorted(by: { $0.key < $1.key }) {
                        let flattenedName = "\(columnPrefix)-\(fieldName)"
                        let fieldMetadata = fieldBuilder.build()
                        let drizzleColumn = generateDrizzleColumnForNested(fieldMetadata, columnName: flattenedName, dbPrefix: dbPrefix)
                        if !drizzleColumn.isEmpty {
                            drizzleColumns.append("    \(drizzleColumn)")
                        }
                    }
                case .array(let elementType, _):
                    // Arrays with flattened fall back to JSONB
                    let drizzleColumn = "\(column.name): d.jsonb()"
                    drizzleColumns.append("    \(drizzleColumn)")
                }
            } else {
                let drizzleColumn = generateDrizzleColumn(column, dbPrefix: dbPrefix)
                if !drizzleColumn.isEmpty {
                    drizzleColumns.append("    \(drizzleColumn)")
                }
            }
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
        
        // Handle nested schemas
        if let nestedSchema = column.nestedSchema {
            switch nestedSchema.strategy {
            case .jsonb:
                def += "d.jsonb()"
            case .separateTable:
                // Separate table - skip this column (handled separately)
                return ""
            case .flattened:
                // Flattened is handled in generateDrizzleSchema
                // Fall through to regular handling
                break
            }
        }
        
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
            case .bigInt:
                def += "d.bigint()"
            case .bool:
                def += "d.boolean()"
            case .double:
                def += "d.real()"
            case .decimal(let precision, let scale):
                def += "d.numeric(\(precision), \(scale))"
            case .uuid:
                def += "d.text()"
            case .date:
                def += "d.timestamp({ withTimezone: true })"
            case .enum:
                def += "d.text()"
            case .object:
                def += "d.jsonb()"
            case .array:
                def += "d.jsonb()"
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
                    } else if column.swiftType == .bool {
                        def += ".default(\(defaultValue))"
                    } else {
                        def += ".default(\"\(defaultValue)\")"
                    }
                }
            }
        }
        
        return def
    }
    
    /// Helper to generate Drizzle column for nested schema fields (recursive)
    /// - Parameters:
    ///   - column: Column metadata
    ///   - columnName: Column name
    ///   - dbPrefix: Database prefix
    ///   - visited: Set of visited schema paths to prevent circular references
    ///   - depth: Current recursion depth (max 10 to prevent infinite loops)
    private func generateDrizzleColumnForNested(
        _ column: ColumnMetadata,
        columnName: String,
        dbPrefix: String = "",
        visited: Set<String> = [],
        depth: Int = 0
    ) -> String {
        // Prevent infinite recursion
        guard depth < 10 else {
            print("⚠️ Warning: Maximum recursion depth reached for Drizzle column at \(columnName)")
            return "\(columnName): d.jsonb()"
        }
        
        // Prevent circular references
        let schemaPath = "\(columnName)"
        if visited.contains(schemaPath) {
            print("⚠️ Warning: Circular reference detected in Drizzle column at \(columnName), using JSONB fallback")
            return "\(columnName): d.jsonb()"
        }
        
        var newVisited = visited
        newVisited.insert(schemaPath)
        
        // Handle nested schemas recursively
        if let nestedSchema = column.nestedSchema {
            switch nestedSchema.strategy {
            case .flattened(let prefix):
                let columnPrefix = prefix ?? columnName
                switch nestedSchema {
                case .object(let fields, _):
                    // For flattened objects, generate individual columns
                    var nestedColumns: [String] = []
                    for (fieldName, fieldBuilder) in fields.sorted(by: { $0.key < $1.key }) {
                        let flattenedName = "\(columnPrefix)-\(fieldName)"
                        let fieldMetadata = fieldBuilder.build()
                        let nestedCol = generateDrizzleColumnForNested(
                            fieldMetadata,
                            columnName: flattenedName,
                            dbPrefix: dbPrefix,
                            visited: newVisited,
                            depth: depth + 1
                        )
                        if !nestedCol.isEmpty {
                            nestedColumns.append(nestedCol)
                        }
                    }
                    return nestedColumns.joined(separator: ",\n    ")
                    
                case .array(let elementType, _):
                    // Arrays with flattened fall back to JSONB
                    return "\(columnName): d.jsonb()"
                }
                
            case .jsonb:
                return "\(columnName): d.jsonb()"
                
            case .separateTable:
                // Separate table - skip (handled separately)
                return ""
            }
        }
        
        // Base type handling
        var def = "\(columnName): "
        
        if let enumType = column.enumType {
            let enumVarName = toCamelCase(enumType.name.replacingOccurrences(of: dbPrefix, with: ""))
            def += "\(enumVarName)"
        } else {
            switch column.swiftType {
            case .string:
                def += "d.text()"
            case .integer:
                def += "d.integer()"
            case .bigInt:
                def += "d.bigint()"
            case .bool:
                def += "d.boolean()"
            case .double:
                def += "d.real()"
            case .decimal(let precision, let scale):
                def += "d.numeric(\(precision), \(scale))"
            case .uuid:
                def += "d.text()"
            case .date:
                def += "d.timestamp({ withTimezone: true })"
            default:
                def += "d.text()"
            }
        }
        
        if !column.isNullable {
            def += ".notNull()"
        }
        
        if column.isUnique {
            def += ".unique()"
        }
        
        return def
    }
    
    /// Collect foreign keys from nested schemas for Drizzle
    /// - Parameters:
    ///   - nestedSchema: The nested schema to process
    ///   - parentColumnName: The parent column name
    ///   - dbPrefix: Database prefix
    ///   - visited: Set of visited schema paths to prevent circular references
    ///   - depth: Current recursion depth (max 10 to prevent infinite loops)
    private func collectDrizzleForeignKeysFromNested(
        _ nestedSchema: NestedSchema,
        parentColumnName: String,
        dbPrefix: String = "",
        visited: Set<String> = [],
        depth: Int = 0
    ) -> [String] {
        // Prevent infinite recursion
        guard depth < 10 else {
            print("⚠️ Warning: Maximum recursion depth reached for Drizzle foreign keys at \(parentColumnName)")
            return []
        }
        
        // Prevent circular references
        let schemaPath = "\(parentColumnName)"
        if visited.contains(schemaPath) {
            print("⚠️ Warning: Circular reference detected in Drizzle foreign keys at \(parentColumnName)")
            return []
        }
        
        var newVisited = visited
        newVisited.insert(schemaPath)
        var fkConstraints: [String] = []
        
        switch nestedSchema {
        case .object(let fields, _):
            for (fieldName, fieldBuilder) in fields {
                let fieldMetadata = fieldBuilder.build()
                let flattenedName = "\(parentColumnName)-\(fieldName)"
                
                // Check for foreign key
                if let fk = fieldMetadata.foreignKey {
                    let referencedTableVar = toCamelCase(fk.referencedTable.replacingOccurrences(of: dbPrefix, with: ""))
                    fkConstraints.append("foreignKey({ columns: [t.\(flattenedName)], foreignKeys: [\(referencedTableVar)({ columns: [\(referencedTableVar).\(fk.referencedColumn)] }) ] })")
                }
                
                // Recursively check nested schemas with cycle detection
                if let nested = fieldMetadata.nestedSchema {
                    fkConstraints.append(contentsOf: collectDrizzleForeignKeysFromNested(
                        nested,
                        parentColumnName: flattenedName,
                        dbPrefix: dbPrefix,
                        visited: newVisited,
                        depth: depth + 1
                    ))
                }
            }
            
        case .array(let elementType, _):
            let elementMetadata = elementType.build()
            if let fk = elementMetadata.foreignKey {
                let referencedTableVar = toCamelCase(fk.referencedTable.replacingOccurrences(of: dbPrefix, with: ""))
                fkConstraints.append("foreignKey({ columns: [t.\(parentColumnName)], foreignKeys: [\(referencedTableVar)({ columns: [\(referencedTableVar).\(fk.referencedColumn)] }) ] })")
            }
            
            if let nested = elementMetadata.nestedSchema {
                fkConstraints.append(contentsOf: collectDrizzleForeignKeysFromNested(
                    nested,
                    parentColumnName: parentColumnName,
                    dbPrefix: dbPrefix,
                    visited: newVisited,
                    depth: depth + 1
                ))
            }
        }
        
        return fkConstraints
    }
    
    /// Generate Drizzle foreign key constraints (including nested schemas)
    private func generateDrizzleForeignKeys(dbPrefix: String = "") -> [String] {
        var fkConstraints: [String] = []
        
        // Collect foreign keys from top-level columns
        for column in columns {
            guard let fk = column.foreignKey else { continue }
            
            let referencedTableVar = toCamelCase(fk.referencedTable.replacingOccurrences(of: dbPrefix, with: ""))
            fkConstraints.append("foreignKey({ columns: [t.\(column.name)], foreignKeys: [\(referencedTableVar)({ columns: [\(referencedTableVar).\(fk.referencedColumn)] }) ] })")
        }
        
        // Collect foreign keys from nested schemas (flattened strategy)
        for column in columns {
            guard let nestedSchema = column.nestedSchema,
                  case .flattened = nestedSchema.strategy else {
                continue
            }
            
            let nestedFKs = collectDrizzleForeignKeysFromNested(nestedSchema, parentColumnName: column.name, dbPrefix: dbPrefix)
            fkConstraints.append(contentsOf: nestedFKs)
        }
        
        return fkConstraints
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
        
        // Handle nested schemas
        if let nestedSchema = column.nestedSchema {
            switch nestedSchema.strategy {
            case .flattened:
                // For flattened, generate individual fields with prefix
                switch nestedSchema {
                case .object(let fields, _):
                    var zodFields: [String] = []
                    let prefix = column.name
                    for (fieldName, fieldBuilder) in fields.sorted(by: { $0.key < $1.key }) {
                        let flattenedName = "\(prefix)-\(fieldName)"
                        let fieldMetadata = fieldBuilder.build()
                        zodFields.append(generateZodFieldForNested(fieldMetadata, fieldName: flattenedName))
                    }
                    return zodFields.joined(separator: ",\n  ")
                    
                case .array(let elementType, _):
                    let elementMetadata = elementType.build()
                    let elementZod = generateZodFieldForNested(elementMetadata, fieldName: "element")
                    return "\(column.name): z.array(\(elementZod.replacingOccurrences(of: "element: ", with: "")))"
                }
                
            case .jsonb:
                // For JSONB, generate z.object() or z.array()
                switch nestedSchema {
                case .object(let fields, _):
                    var zodFields: [String] = []
                    for (fieldName, fieldBuilder) in fields.sorted(by: { $0.key < $1.key }) {
                        let fieldMetadata = fieldBuilder.build()
                        zodFields.append(generateZodFieldForNested(fieldMetadata, fieldName: fieldName))
                    }
                    return "\(column.name): z.object({\n    \(zodFields.joined(separator: ",\n    "))\n  })"
                    
                case .array(let elementType, _):
                    let elementMetadata = elementType.build()
                    let elementZod = generateZodFieldForNested(elementMetadata, fieldName: "element")
                    return "\(column.name): z.array(\(elementZod.replacingOccurrences(of: "element: ", with: "")))"
                }
                
            case .separateTable:
                // Separate table - reference the separate table type
                return "\(column.name): \(toPascalCase(column.name))Schema"
            }
        }
        
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
            case .bigInt:
                zodType = "z.bigint()"
            case .bool:
                zodType = "z.boolean()"
            case .double:
                zodType = "z.number()"
            case .decimal:
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
    
    /// Helper to generate Zod field for nested schema fields (recursive)
    /// - Parameters:
    ///   - column: Column metadata
    ///   - fieldName: Field name
    ///   - visited: Set of visited schema paths to prevent circular references
    ///   - depth: Current recursion depth (max 10 to prevent infinite loops)
    private func generateZodFieldForNested(
        _ column: ColumnMetadata,
        fieldName: String,
        visited: Set<String> = [],
        depth: Int = 0
    ) -> String {
        // Prevent infinite recursion
        guard depth < 10 else {
            print("⚠️ Warning: Maximum recursion depth reached for Zod field at \(fieldName)")
            return "\(fieldName): z.any()"
        }
        
        // Prevent circular references
        let schemaPath = "\(fieldName)"
        if visited.contains(schemaPath) {
            print("⚠️ Warning: Circular reference detected in Zod field at \(fieldName), using any() fallback")
            return "\(fieldName): z.any()"
        }
        
        var newVisited = visited
        newVisited.insert(schemaPath)
        var field = "\(fieldName): "
        
        // Handle nested schemas recursively
        if let nestedSchema = column.nestedSchema {
            switch nestedSchema.strategy {
            case .flattened(let prefix):
                let columnPrefix = prefix ?? fieldName
                switch nestedSchema {
                case .object(let fields, _):
                    var zodFields: [String] = []
                    for (nestedFieldName, fieldBuilder) in fields.sorted(by: { $0.key < $1.key }) {
                        let flattenedName = "\(columnPrefix)-\(nestedFieldName)"
                        let fieldMetadata = fieldBuilder.build()
                        zodFields.append(generateZodFieldForNested(
                            fieldMetadata,
                            fieldName: flattenedName,
                            visited: newVisited,
                            depth: depth + 1
                        ))
                    }
                    return zodFields.joined(separator: ",\n  ")
                    
                case .array(let elementType, _):
                    let elementMetadata = elementType.build()
                    let elementZod = generateZodFieldForNested(
                        elementMetadata,
                        fieldName: "element",
                        visited: newVisited,
                        depth: depth + 1
                    )
                    return "\(fieldName): z.array(\(elementZod.replacingOccurrences(of: "element: ", with: "")))"
                }
                
            case .jsonb:
                switch nestedSchema {
                case .object(let fields, _):
                    var zodFields: [String] = []
                    for (nestedFieldName, fieldBuilder) in fields.sorted(by: { $0.key < $1.key }) {
                        let fieldMetadata = fieldBuilder.build()
                        zodFields.append(generateZodFieldForNested(
                            fieldMetadata,
                            fieldName: nestedFieldName,
                            visited: newVisited,
                            depth: depth + 1
                        ))
                    }
                    return "\(fieldName): z.object({\n    \(zodFields.joined(separator: ",\n    "))\n  })"
                    
                case .array(let elementType, _):
                    let elementMetadata = elementType.build()
                    let elementZod = generateZodFieldForNested(
                        elementMetadata,
                        fieldName: "element",
                        visited: newVisited,
                        depth: depth + 1
                    )
                    return "\(fieldName): z.array(\(elementZod.replacingOccurrences(of: "element: ", with: "")))"
                }
                
            case .separateTable:
                return "\(fieldName): \(toPascalCase(fieldName))Schema"
            }
        }
        
        // Base type handling
        if let enumType = column.enumType {
            let enumValues = enumType.values.map { "\"\($0)\"" }.joined(separator: ", ")
            field += "z.enum([\(enumValues)])"
        } else {
            switch column.swiftType {
            case .string:
                field += "z.string()"
            case .integer:
                field += "z.number().int()"
            case .bigInt:
                field += "z.bigint()"
            case .bool:
                field += "z.boolean()"
            case .double:
                field += "z.number()"
            case .decimal:
                field += "z.number()"
            case .uuid:
                field += "z.string().uuid()"
            case .date:
                field += "z.string().datetime()"
            default:
                field += "z.string()"
            }
        }
        
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
        if column.isNullable {
            field += ".nullable()"
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
            // Handle nested schemas
            if let nestedSchema = column.nestedSchema {
                switch nestedSchema.strategy {
                case .flattened(let prefix):
                    // Generate flattened fields
                    let columnPrefix = prefix ?? column.name
                    switch nestedSchema {
                    case .object(let nestedFields, _):
                        for (fieldName, fieldBuilder) in nestedFields.sorted(by: { $0.key < $1.key }) {
                            let flattenedName = "\(columnPrefix)-\(fieldName)"
                            let fieldMetadata = fieldBuilder.build()
                            let fieldName = toCamelCase(flattenedName)
                            var fieldDef = "  \(fieldName)"
                            
                            // Handle nested schemas recursively
                            if let nested = fieldMetadata.nestedSchema {
                                fieldDef += " " + generatePrismaTypeForNested(fieldMetadata, nestedSchema: nested, dbPrefix: dbPrefix)
                            } else {
                                fieldDef += " " + generatePrismaType(fieldMetadata)
                            }
                            
                            // Handle foreign keys in nested objects
                            if let fk = fieldMetadata.foreignKey {
                                let referencedFieldName = toCamelCase(fk.referencedColumn)
                                let relatedModelName = toPascalCase(fk.referencedTable.replacingOccurrences(of: dbPrefix, with: ""))
                                let relationName = "\(modelName)\(relatedModelName)\(fieldName.capitalized)"
                                var attributes: [String] = ["@relation(fields: [\(fieldName)], references: [\(referencedFieldName)], name: \"\(relationName)\")"]
                                if flattenedName != fieldName {
                                    attributes.append("@map(\"\(flattenedName)\")")
                                }
                                fieldDef += " " + attributes.joined(separator: " ")
                            }
                            
                            if fieldMetadata.isNullable {
                                fieldDef += "?"
                            }
                            fields.append(fieldDef)
                        }
                    case .array(let elementType, _):
                        // Arrays with flattened fall back to Json
                        let fieldName = toCamelCase(column.name)
                        var fieldDef = "  \(fieldName)"
                        fieldDef += " Json"
                        if column.isNullable {
                            fieldDef += "?"
                        }
                        fields.append(fieldDef)
                    }
                    continue
                    
                case .jsonb:
                    // Generate Json field
                    let fieldName = toCamelCase(column.name)
                    var fieldDef = "  \(fieldName)"
                    fieldDef += " Json"
                    if column.isNullable {
                        fieldDef += "?"
                    }
                    fields.append(fieldDef)
                    continue
                    
                case .separateTable:
                    // Separate table - skip (handled separately)
                    continue
                }
            }
            
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
                
                // Add @db.Decimal annotation for decimal types
                if case .decimal(let precision, let scale) = column.swiftType {
                    attributes.append("@db.Decimal(\(precision), \(scale))")
                }
                
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
            
            // Add @db.Decimal annotation for decimal types
            if case .decimal(let precision, let scale) = column.swiftType {
                attributes.append("@db.Decimal(\(precision), \(scale))")
            }
            
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
                } else if column.swiftType == .bool {
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
    
    /// Generate Prisma type string for nested schemas
    private func generatePrismaTypeForNested(_ column: ColumnMetadata, nestedSchema: NestedSchema, dbPrefix: String = "") -> String {
        switch nestedSchema.strategy {
        case .flattened:
            // For flattened, generate individual fields (handled in generatePrismaModel)
            return generatePrismaType(column)
            
        case .jsonb:
            return "Json"
            
        case .separateTable(let tableName, _):
            // Use provided table name or fallback to column name
            let finalTableName = tableName ?? column.name
            return toPascalCase(finalTableName.replacingOccurrences(of: dbPrefix, with: ""))
        }
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
        case .bigInt:
            return "BigInt"
        case .bool:
            return "Boolean"
        case .double:
            return "Float"
        case .decimal:
            return "Decimal"
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
    public let enums: [ZyraEnum]
    /// Generate separate table from nested schema with separateTable strategy
    private static func generateSeparateTable(
        from nestedSchema: NestedSchema,
        parentTable: ZyraTable,
        parentColumnName: String,
        dbPrefix: String = ""
    ) -> ZyraTable? {
        guard case .separateTable(let tableName, let relationshipType) = nestedSchema.strategy else {
            return nil
        }
        
        let finalTableName = tableName ?? "\(parentTable.name)_\(parentColumnName)"
        let prefixedTableName = dbPrefix.isEmpty ? finalTableName : "\(dbPrefix)\(finalTableName)"
        
        var separateTableColumns: [ColumnBuilder] = []
        
        // Add primary key
        separateTableColumns.append(zf.text("id").uuid().notNull())
        
        // Add foreign key to parent table
        let parentKeyName = "\(parentTable.name.replacingOccurrences(of: dbPrefix, with: "").singularized())_id"
        var parentKeyColumn = zf.uuid(parentKeyName)
            .notNull()
            .references(parentTable)
        
        // Add unique constraint for one-to-one relationships
        if relationshipType == .oneToOne {
            parentKeyColumn = parentKeyColumn.unique()
        }
        
        separateTableColumns.append(parentKeyColumn)
        
        // Add columns from nested schema
        switch nestedSchema {
        case .object(let fields, _):
            for (fieldName, fieldBuilder) in fields.sorted(by: { $0.key < $1.key }) {
                // Rebuild the column with the new name
                let fieldMetadata = fieldBuilder.build()
                
                // Create a new builder starting from the swiftType
                var newBuilder: ColumnBuilder
                switch fieldMetadata.swiftType {
                case .string, .uuid, .date:
                    newBuilder = zf.text(fieldName)
                case .integer:
                    newBuilder = zf.integer(fieldName)
                        case .bigInt:
                            newBuilder = zf.bigint(fieldName)
                case .double:
                    newBuilder = zf.real(fieldName)
                case .decimal(let precision, let scale):
                    newBuilder = zf.decimal(fieldName, precision: precision, scale: scale)
                case .bool:
                    newBuilder = zf.text(fieldName).bool()
                case .enum(let enumType):
                    newBuilder = zf.text(fieldName).enum(enumType)
                case .object, .array:
                    newBuilder = zf.text(fieldName) // Will be handled by nested schema
                }
                
                // Apply all the properties from the original builder
                if fieldMetadata.isEncrypted {
                    newBuilder = newBuilder.encrypted()
                }
                if !fieldMetadata.isNullable {
                    newBuilder = newBuilder.notNull()
                }
                if fieldMetadata.isUnique {
                    newBuilder = newBuilder.unique()
                }
                if let defaultValue = fieldMetadata.defaultValue {
                    newBuilder = newBuilder.default(defaultValue)
                }
                if let enumType = fieldMetadata.enumType {
                    newBuilder = newBuilder.enum(enumType)
                }
                if let fk = fieldMetadata.foreignKey {
                    newBuilder = newBuilder.references(fk.referencedTable, column: fk.referencedColumn)
                }
                
                // Preserve many-to-many relationships for separate table generation
                // These will be handled when the separate table is processed by ZyraSchema
                if fieldBuilder._manyToManyRelationship != nil {
                    newBuilder._manyToManyRelationship = fieldBuilder._manyToManyRelationship
                }
                
                separateTableColumns.append(newBuilder)
            }
            
        case .array(let elementType, let arrayStrategy):
            // For arrays, create columns based on element type
            let elementMetadata = elementType.build()
            
            // Add an index/position column for ordering
            separateTableColumns.append(zf.integer("position").notNull())
            
            // If element is a simple type, create a "value" column
            // If element is an object, create columns for each field
            if let nestedSchema = elementMetadata.nestedSchema {
                // Array of objects - create columns for each object field
                switch nestedSchema {
                case .object(let fields, _):
                    for (fieldName, fieldBuilder) in fields.sorted(by: { $0.key < $1.key }) {
                        let fieldMetadata = fieldBuilder.build()
                        
                        var newBuilder: ColumnBuilder
                        switch fieldMetadata.swiftType {
                        case .string, .uuid, .date:
                            newBuilder = zf.text(fieldName)
                        case .integer:
                            newBuilder = zf.integer(fieldName)
                        case .bigInt:
                            newBuilder = zf.bigint(fieldName)
                        case .double:
                            newBuilder = zf.real(fieldName)
                        case .decimal(let precision, let scale):
                            newBuilder = zf.decimal(fieldName, precision: precision, scale: scale)
                        case .bool:
                            newBuilder = zf.text(fieldName).bool()
                        case .enum(let enumType):
                            newBuilder = zf.text(fieldName).enum(enumType)
                        case .object, .array:
                            newBuilder = zf.text(fieldName)
                        }
                        
                        if fieldMetadata.isEncrypted {
                            newBuilder = newBuilder.encrypted()
                        }
                        if !fieldMetadata.isNullable {
                            newBuilder = newBuilder.notNull()
                        }
                        if let defaultValue = fieldMetadata.defaultValue {
                            newBuilder = newBuilder.default(defaultValue)
                        }
                        
                        separateTableColumns.append(newBuilder)
                    }
                case .array:
                    // Array of arrays - store as JSONB
                    separateTableColumns.append(zf.text("value").object([:], strategy: .jsonb).nullable())
                }
            } else {
                // Array of simple values - create a "value" column
                var valueBuilder: ColumnBuilder
                switch elementMetadata.swiftType {
                case .string, .uuid, .date:
                    valueBuilder = zf.text("value")
                case .integer:
                    valueBuilder = zf.integer("value")
                case .bigInt:
                    valueBuilder = zf.bigint("value")
                case .double:
                    valueBuilder = zf.real("value")
                case .decimal(let precision, let scale):
                    valueBuilder = zf.decimal("value", precision: precision, scale: scale)
                case .bool:
                    valueBuilder = zf.text("value").bool()
                case .enum(let enumType):
                    valueBuilder = zf.text("value").enum(enumType)
                case .object, .array:
                    valueBuilder = zf.text("value")
                }
                
                if elementMetadata.isEncrypted {
                    valueBuilder = valueBuilder.encrypted()
                }
                if !elementMetadata.isNullable {
                    valueBuilder = valueBuilder.notNull()
                }
                if let defaultValue = elementMetadata.defaultValue {
                    valueBuilder = valueBuilder.default(defaultValue)
                }
                
                separateTableColumns.append(valueBuilder)
            }
        }
        
        return ZyraTable(
            name: prefixedTableName,
            primaryKey: "id",
            columns: separateTableColumns
        )
    }
    
    /// Extract separate tables from nested schemas
    private static func extractSeparateTables(from tables: [ZyraTable], dbPrefix: String = "") -> [ZyraTable] {
        var separateTables: [ZyraTable] = []
        
        for table in tables {
            for column in table.columns {
                guard let nestedSchema = column.nestedSchema,
                      case .separateTable = nestedSchema.strategy else {
                    continue
                }
                
                if let separateTable = ZyraSchema.generateSeparateTable(
                    from: nestedSchema,
                    parentTable: table,
                    parentColumnName: column.name,
                    dbPrefix: dbPrefix
                ) {
                    separateTables.append(separateTable)
                }
            }
        }
        
        return separateTables
    }
    
    /// Collect many-to-many relationships from nested schemas
    /// Note: Many-to-many relationships within nested objects are only supported for separateTable strategy
    /// - Parameters:
    ///   - nestedSchema: The nested schema to process
    ///   - parentTableName: The parent table name
    ///   - parentColumnName: The parent column name
    ///   - visited: Set of visited schema paths to prevent circular references
    ///   - depth: Current recursion depth (max 10 to prevent infinite loops)
    private static func collectManyToManyFromNested(
        _ nestedSchema: NestedSchema,
        parentTableName: String,
        parentColumnName: String,
        visited: Set<String> = [],
        depth: Int = 0
    ) -> [(fieldBuilder: ColumnBuilder, parentPath: String)] {
        // Prevent infinite recursion
        guard depth < 10 else {
            print("⚠️ Warning: Maximum recursion depth reached for many-to-many collection at \(parentColumnName)")
            return []
        }
        
        // Prevent circular references
        let schemaPath = "\(parentTableName).\(parentColumnName)"
        if visited.contains(schemaPath) {
            print("⚠️ Warning: Circular reference detected in many-to-many collection at \(schemaPath)")
            return []
        }
        
        var newVisited = visited
        newVisited.insert(schemaPath)
        var manyToManyRelationships: [(ColumnBuilder, String)] = []
        
        switch nestedSchema {
        case .object(let fields, let strategy):
            // Many-to-many only makes sense for separateTable strategy
            if case .separateTable = strategy {
                for (fieldName, fieldBuilder) in fields {
                    let fieldMetadata = fieldBuilder.build()
                    let fieldPath = "\(parentColumnName).\(fieldName)"
                    
                    // Check for many-to-many relationship
                    if fieldBuilder._manyToManyRelationship != nil {
                        manyToManyRelationships.append((fieldBuilder, fieldPath))
                    }
                    
                    // Recursively check nested schemas
                    if let nested = fieldMetadata.nestedSchema {
                        manyToManyRelationships.append(contentsOf: collectManyToManyFromNested(
                            nested,
                            parentTableName: parentTableName,
                            parentColumnName: fieldPath,
                            visited: newVisited,
                            depth: depth + 1
                        ))
                    }
                }
            }
            
        case .array(let elementType, let strategy):
            // Many-to-many only makes sense for separateTable strategy
            if case .separateTable = strategy {
                let elementMetadata = elementType.build()
                if elementType._manyToManyRelationship != nil {
                    manyToManyRelationships.append((elementType, parentColumnName))
                }
                
                if let nested = elementMetadata.nestedSchema {
                    manyToManyRelationships.append(contentsOf: collectManyToManyFromNested(
                        nested,
                        parentTableName: parentTableName,
                        parentColumnName: parentColumnName,
                        visited: newVisited,
                        depth: depth + 1
                    ))
                }
            }
        }
        
        return manyToManyRelationships
    }
    
    private let joinTables: [ZyraTable]
    
    public init(tables: [ZyraTable], enums: [ZyraEnum] = [], dbPrefix: String = "") {
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
        
        // Generate separate tables from nested schemas with separateTable strategy
        let generatedSeparateTables = ZyraSchema.extractSeparateTables(from: processedTables, dbPrefix: dbPrefix)
        
        // Combine regular tables with join tables and separate tables
        self.tables = processedTables
        self.joinTables = generatedJoinTables + generatedSeparateTables
        
        // Collect all enums from tables
        var allEnums = Set(enums)
        for table in processedTables {
            allEnums.formUnion(table.getEnums())
        }
        for table in generatedJoinTables {
            allEnums.formUnion(table.getEnums())
        }
        self.enums = Array(allEnums)
        
        // Update table map to include join tables for validation
        var completeTableMap = tableMap
        for joinTable in generatedJoinTables {
            completeTableMap[joinTable.name] = joinTable
        }
        
        // Validate foreign keys reference primary keys
        self.validateForeignKeys(tableMap: completeTableMap)
    }
    
    /// Validate that all foreign keys reference primary keys
    private func validateForeignKeys(tableMap: [String: ZyraTable]) {
        let allTables = self.tables + self.joinTables
        
        for table in allTables {
            for column in table.columns {
                guard let fk = column.foreignKey else { continue }
                
                // Check if referenced table exists
                guard let referencedTable = tableMap[fk.referencedTable] else {
                    print("⚠️ Warning: Foreign key in table '\(table.name)' references non-existent table '\(fk.referencedTable)'")
                    continue
                }
                
                // Validate that the referenced column is the primary key
                if fk.referencedColumn.lowercased() != referencedTable.primaryKey.lowercased() {
                    fatalError("""
                    ❌ Foreign Key Validation Error:
                    Table '\(table.name)' has a foreign key '\(column.name)' that references '\(fk.referencedTable).\(fk.referencedColumn)',
                    but foreign keys must reference primary keys. Table '\(fk.referencedTable)' has primary key '\(referencedTable.primaryKey)'.
                    
                    Fix: Change the reference to use the primary key:
                    zf.text("\(column.name)").references("\(fk.referencedTable)", column: "\(referencedTable.primaryKey)")
                    Or use the ZyraTable instance:
                    zf.text("\(column.name)").references(\(fk.referencedTable))
                    """)
                }
            }
        }
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
                // Table names with hyphens/special chars need quotes in SQL
                let needsQuotes = tableName.contains("-") || tableName.contains(" ") || tableName != tableName.lowercased()
                let quotedTableName = needsQuotes ? "\"\(tableName)\"" : tableName
                yaml += "      - SELECT * FROM \(quotedTableName)\n"
                
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
                
                // Table names with hyphens/special chars need quotes in SQL
                let needsQuotes = tableName.contains("-") || tableName.contains(" ") || tableName != tableName.lowercased()
                let quotedTableName = needsQuotes ? "\"\(tableName)\"" : tableName
                let quotedColumnName = needsQuotes ? "\"\(userIdCol)\"" : userIdCol
                
                // Generate WHERE clause - format: SELECT * FROM tablename WHERE tablename.user_id = bucket.user_id
                yaml += "      - SELECT * FROM \(quotedTableName) WHERE \(quotedTableName).\(quotedColumnName) = bucket.user_id\n"
                
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
        
        // 2. Create tables WITHOUT foreign keys first (to handle circular dependencies)
        sql.append("-- Create Tables (without foreign keys)")
        let allTables = tables + joinTables
        let orderedTables = topologicalSortTables(allTables: allTables)
        
        for table in orderedTables {
            sql.append(table.generateCreateTableSQLWithoutFKs())
            sql.append("")
        }
        
        // 3. Add foreign keys with ALTER TABLE (all tables exist now)
        sql.append("-- Add Foreign Key Constraints")
        var fkStatements: [String] = []
        for table in orderedTables {
            fkStatements.append(contentsOf: table.generateAlterTableForForeignKeys())
        }
        if !fkStatements.isEmpty {
            sql.append(contentsOf: fkStatements)
            sql.append("")
        }
        
        // 4. Add triggers and RLS
        for table in orderedTables {
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
    
    /// Generate MySQL migration SQL
    /// Note: MySQL doesn't support RLS (Row Level Security) like PostgreSQL
    public func generateMySQLMigrationSQL() -> String {
        var sql: [String] = []
        
        // 1. Create tables WITHOUT foreign keys first (to handle circular dependencies)
        sql.append("-- Create Tables (without foreign keys)")
        let allTables = tables + joinTables
        let orderedTables = topologicalSortTables(allTables: allTables)
        
        for table in orderedTables {
            sql.append(table.generateMySQLTableSQLWithoutFKs())
            sql.append("")
        }
        
        // 2. Add foreign keys with ALTER TABLE (all tables exist now)
        sql.append("-- Add Foreign Key Constraints")
        var fkStatements: [String] = []
        for table in orderedTables {
            fkStatements.append(contentsOf: table.generateMySQLAlterTableForForeignKeys())
        }
        if !fkStatements.isEmpty {
            sql.append(contentsOf: fkStatements)
            sql.append("")
        }
        
        // 3. Add triggers
        for table in orderedTables {
            // Add trigger if updated_at exists
            if table.columns.contains(where: { $0.name.lowercased() == "updated_at" }) {
                sql.append(table.generateMySQLUpdatedAtTrigger())
                sql.append("")
            }
        }
        
        // Note: MySQL doesn't support RLS, so we skip RLS policies
        sql.append("-- Note: MySQL doesn't support Row Level Security (RLS)")
        sql.append("-- Consider implementing application-level access control")
        
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
