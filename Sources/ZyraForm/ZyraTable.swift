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
    let name: String
    let powerSyncColumn: PowerSync.Column
    let isEncrypted: Bool
    let swiftType: SwiftColumnType
    let isNullable: Bool
    let foreignKey: ForeignKey?
    let defaultValue: String?
    let enumType: DatabaseEnum?
    let nestedSchema: NestedSchema?
    
    // Validation properties (like Zod)
    let isPositive: Bool?
    let isNegative: Bool?
    let isEven: Bool?
    let isOdd: Bool?
    let minimum: Double?
    let maximum: Double?
    let intMin: Int?
    let intMax: Int?
    let isEmail: Bool?
    let isUrl: Bool?
    let isHttpUrl: Bool?
    let isUuid: Bool?
    let isCuid: Bool?
    let isCuid2: Bool?
    let isNanoid: Bool?
    let isEmoji: Bool?
    let isHex: Bool?
    let isJwt: Bool?
    let isDate: Bool?
    let isTime: Bool?
    let isIsoDateTime: Bool?
    let isIsoDate: Bool?
    let isIsoTime: Bool?
    let regexPattern: String?
    let regexError: String?
    let minLength: Int?
    let maxLength: Int?
    let exactLength: Int?
    let startsWith: String?
    let endsWith: String?
    let includes: String?
    let isUppercase: Bool?
    let isLowercase: Bool?
    let isIpv4: Bool?
    let isIpv6: Bool?
    let customValidation: (String, (Any) -> Bool)?
    
    indirect enum SwiftColumnType: Equatable {
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
    public func toSwiftType(isNullable: Bool) -> String {
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
        case .enum:
            type = "String"
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
    let name: String
    let powerSyncColumn: PowerSync.Column
    var isEncrypted: Bool = false
    var swiftType: ColumnMetadata.SwiftColumnType = .string
    var isNullable: Bool = false
    var foreignKey: ForeignKey? = nil
    var defaultValue: String? = nil
    var enumType: DatabaseEnum? = nil
    
    // Validation properties
    var isPositive: Bool? = nil
    var isNegative: Bool? = nil
    var isEven: Bool? = nil
    var isOdd: Bool? = nil
    var minimum: Double? = nil
    var maximum: Double? = nil
    var intMin: Int? = nil
    var intMax: Int? = nil
    var isEmail: Bool? = nil
    var isUrl: Bool? = nil
    var isHttpUrl: Bool? = nil
    var isUuid: Bool? = nil
    var isCuid: Bool? = nil
    var isCuid2: Bool? = nil
    var isNanoid: Bool? = nil
    var isEmoji: Bool? = nil
    var isHex: Bool? = nil
    var isJwt: Bool? = nil
    var isDate: Bool? = nil
    var isTime: Bool? = nil
    var isIsoDateTime: Bool? = nil
    var isIsoDate: Bool? = nil
    var isIsoTime: Bool? = nil
    var regexPattern: String? = nil
    var regexError: String? = nil
    var minLength: Int? = nil
    var maxLength: Int? = nil
    var exactLength: Int? = nil
    var startsWith: String? = nil
    var endsWith: String? = nil
    var includes: String? = nil
    var isUppercase: Bool? = nil
    var isLowercase: Bool? = nil
    var isIpv4: Bool? = nil
    var isIpv6: Bool? = nil
    var customValidation: (String, (Any) -> Bool)? = nil
    
    // Use indirect reference to break circular dependency
    private var _nestedSchema: NestedSchema?
    
    var nestedSchema: NestedSchema? {
        get { _nestedSchema }
        set { _nestedSchema = newValue }
    }
    
    init(name: String, powerSyncColumn: PowerSync.Column) {
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
    
    // MARK: - Default Values
    
    func `default`(_ value: String) -> ColumnBuilder {
        var builder = self
        builder.defaultValue = value
        return builder
    }
    
    func `default`(_ value: Int) -> ColumnBuilder {
        var builder = self
        builder.defaultValue = String(value)
        return builder
    }
    
    func `default`(_ value: Bool) -> ColumnBuilder {
        var builder = self
        builder.defaultValue = value ? "true" : "false"
        return builder
    }
    
    func `default`(_ value: DefaultTimestamp) -> ColumnBuilder {
        var builder = self
        switch value {
        case .now:
            builder.defaultValue = "NOW()"
            builder.swiftType = .date
        }
        return builder
    }
    
    func defaultSQL(_ sqlExpression: String) -> ColumnBuilder {
        var builder = self
        builder.defaultValue = sqlExpression
        return builder
    }
    
    // MARK: - Enum and Foreign Key
    
    func `enum`(_ enumType: DatabaseEnum) -> ColumnBuilder {
        var builder = self
        builder.enumType = enumType
        builder.swiftType = .enum(enumType)
        return builder
    }
    
    func references(
        _ table: String,
        column: String = "id",
        onDelete: ForeignKeyAction = .setNull,
        onUpdate: ForeignKeyAction = .cascade
    ) -> ColumnBuilder {
        var builder = self
        builder.foreignKey = ForeignKey(
            referencedTable: table,
            referencedColumn: column,
            onDelete: onDelete,
            onUpdate: onUpdate
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
    
    func object(_ schema: [String: ColumnBuilder]) -> ColumnBuilder {
        var builder = self
        builder.nestedSchema = NestedSchema(fields: schema)
        builder.swiftType = .object(NestedSchema(fields: schema))
        return builder
    }
    
    func array(_ elementType: ColumnBuilder) -> ColumnBuilder {
        var builder = self
        let nested = NestedSchema(elementType: elementType)
        builder.nestedSchema = nested
        builder.swiftType = .array(nested)
        return builder
    }
    
    // MARK: - Build
    
    func build() -> ColumnMetadata {
        return ColumnMetadata(
            name: name,
            powerSyncColumn: powerSyncColumn,
            isEncrypted: isEncrypted,
            swiftType: swiftType,
            isNullable: isNullable,
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
    let name: String
    let values: [String]
    
    public init(name: String, values: [String]) {
        self.name = name
        self.values = values
    }
    
    /// Generate CREATE TYPE SQL for PostgreSQL
    func generateCreateEnumSQL() -> String {
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
    let referencedTable: String
    let referencedColumn: String
    let onDelete: ForeignKeyAction
    let onUpdate: ForeignKeyAction
}

public enum ForeignKeyAction {
    case cascade
    case restrict
    case setNull
    case setDefault
    case noAction
    
    var sqlString: String {
        switch self {
        case .cascade: return "CASCADE"
        case .restrict: return "RESTRICT"
        case .setNull: return "SET NULL"
        case .setDefault: return "SET DEFAULT"
        case .noAction: return "NO ACTION"
        }
    }
    
    var drizzleString: String {
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

// MARK: - Zyra Table

/// Zyra table that includes metadata
public struct ZyraTable: Hashable {
    public let name: String
    public let powerSyncTable: PowerSync.Table
    public let columns: [ColumnMetadata]
    public let primaryKey: String
    public let defaultOrderBy: String
    
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
        columns: [ColumnBuilder]
    ) {
        self.name = name
        self.primaryKey = primaryKey
        self.defaultOrderBy = defaultOrderBy
        
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
    func generateForeignKeyConstraints() -> [String] {
        return columns.compactMap { column in
            guard let fk = column.foreignKey else { return nil }
            
            let constraintName = "\(name)_\(column.name)_fkey"
            return """
                CONSTRAINT \(constraintName) FOREIGN KEY (\(column.name)) 
                REFERENCES "\(fk.referencedTable)" (\(fk.referencedColumn)) 
                ON UPDATE \(fk.onUpdate.sqlString) 
                ON DELETE \(fk.onDelete.sqlString)
            """
        }
    }
    
    /// Get all foreign key relationships
    func getForeignKeys() -> [(column: String, foreignKey: ForeignKey)] {
        return columns.compactMap { column in
            guard let fk = column.foreignKey else { return nil }
            return (column.name, fk)
        }
    }
    
    // MARK: - SQL Generation
    
    /// Generate SQL CREATE TABLE statement with defaults, foreign keys, and triggers
    func generateCreateTableSQL() -> String {
        var columnDefinitions: [String] = []
        
        // Add primary key
        columnDefinitions.append("\(primaryKey) TEXT PRIMARY KEY")
        
        // Add each column with its definition
        for column in columns {
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
        
        var sql = """
        CREATE TABLE "\(name)" (
            \(allConstraints.joined(separator: ",\n    "))
        );
        """
        
        // Generate trigger for updated_at if present
        if let updatedAtColumn = columns.first(where: { $0.name.lowercased() == "updated_at" }) {
            sql += "\n\n"
            sql += generateUpdatedAtTrigger()
        }
        
        return sql
    }
    
    /// Generate PostgreSQL trigger function and trigger for automatic updated_at updates
    func generateUpdatedAtTrigger() -> String {
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
    func generateUpdatedAtTriggerOnly() -> String? {
        guard columns.contains(where: { $0.name.lowercased() == "updated_at" }) else { return nil }
        return generateUpdatedAtTrigger()
    }
    
    /// Generate CREATE TABLE SQL only (without triggers)
    func generateCreateTableSQLOnly() -> String {
        var columnDefinitions: [String] = []
        
        // Add primary key
        columnDefinitions.append("\(primaryKey) TEXT PRIMARY KEY")
        
        // Add each column with its definition
        for column in columns {
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
        
        return """
        CREATE TABLE "\(name)" (
            \(allConstraints.joined(separator: ",\n    "))
        );
        """
    }
    
    // MARK: - Swift Model Generation
    
    /// Generate Swift model struct code
    func generateSwiftModel(modelName: String? = nil) -> String {
        // Note: dbPrefix should be provided by the app configuration
        let structName = modelName ?? toPascalCase(name)
        
        var code = "// MARK: - \(structName)\n\n"
        code += "struct \(structName): Codable, Identifiable, Hashable {\n"
        
        // Generate properties
        var properties: [String] = []
        var codingKeys: [String] = []
        
        for column in columns {
            let swiftName = toCamelCase(column.name)
            let swiftType = column.swiftType.toSwiftType(isNullable: column.isNullable)
            
            properties.append("    let \(swiftName): \(swiftType)")
            
            // Add CodingKey if name differs from Swift name
            if column.name != swiftName {
                codingKeys.append("        case \(swiftName) = \"\(column.name)\"")
            } else {
                codingKeys.append("        case \(swiftName)")
            }
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
    func generateSwiftModelFile(modelName: String? = nil) -> String {
        let structName = modelName ?? toPascalCase(name)
        
        var code = "import Foundation\n\n"
        code += generateSwiftModel(modelName: modelName)
        
        return code
    }
    
    // MARK: - Drizzle Schema Generation
    
    /// Generate Drizzle ORM schema code (TypeScript)
    func generateDrizzleSchema(tableVariableName: String? = nil, includeImports: Bool = false, dbPrefix: String = "") -> String {
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
    func generateDrizzleTableFile(tableVariableName: String? = nil) -> String {
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
    func generateZodSchema(dbPrefix: String = "") -> String {
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
    
    public init(tables: [ZyraTable], enums: [DatabaseEnum] = []) {
        self.tables = tables
        
        // Collect all enums from tables
        var allEnums = Set(enums)
        for table in tables {
            allEnums.formUnion(table.getEnums())
        }
        self.enums = Array(allEnums)
    }
    
    /// Generate complete migration SQL with proper ordering
    func generateMigrationSQL() -> String {
        var sql: [String] = []
        
        // 1. Create all enums first
        if !enums.isEmpty {
            sql.append("-- Create Enums")
            for dbEnum in enums {
                sql.append(dbEnum.generateCreateEnumSQL())
            }
            sql.append("")
        }
        
        // 2. Create tables in topological order
        sql.append("-- Create Tables")
        let orderedTables = topologicalSortTables()
        
        for table in orderedTables {
            sql.append(table.generateCreateTableSQLOnly())
            sql.append("")
            
            // Add trigger if updated_at exists
            if let triggerSQL = table.generateUpdatedAtTriggerOnly() {
                sql.append(triggerSQL)
                sql.append("")
            }
        }
        
        return sql.joined(separator: "\n\n")
    }
    
    /// Topologically sort tables based on foreign key dependencies
    private func topologicalSortTables() -> [ZyraTable] {
        var dependencies: [String: Set<String>] = [:]
        var tableMap: [String: ZyraTable] = [:]
        
        for table in tables {
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
        
        if result.count != tables.count {
            print("⚠️ Warning: Circular dependency detected or missing referenced table")
            return tables
        }
        
        return result
    }
    
    /// Convert to PowerSync Schema
    func toPowerSyncSchema() -> PowerSync.Schema {
        return PowerSync.Schema(
            tables: tables.map { $0.toPowerSyncTable() }
        )
    }
    
    /// Generate Drizzle schema code for all tables and enums
    func generateDrizzleSchema(dbPrefix: String = "") -> String {
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
        
        // Generate tables in dependency order
        code += "// Tables\n"
        let orderedTables = topologicalSortTables()
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
    func generateAllSwiftModels() -> String {
        return tables.map { $0.generateSwiftModel() }.joined(separator: "\n\n")
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
        let orderedTables = topologicalSortTables()
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
