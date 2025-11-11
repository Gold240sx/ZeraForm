//
//  CorrectedSchemaExamples.swift
//  ZeraForm Syntax Examples
//
//  Examples showing correct syntax for common issues
//

import ZyraForm

// MARK: - Helper Function for Simplified Object Schema
// This helper makes object schemas less verbose by using the field name as both key and value

extension ColumnBuilder {
    /// Simplified object schema helper - uses field name for both dictionary key and ColumnBuilder name
    static func simpleObject(_ name: String, fields: [String], strategy: ObjectStorageStrategy = .jsonb) -> ColumnBuilder {
        let schema = Dictionary(uniqueKeysWithValues: fields.map { ($0, zf.text($0)) })
        return zf.object(name, schema: schema, strategy: strategy)
    }
}

// MARK: - Example: Correct Boolean Syntax

let ExampleTable1 = ZyraTable(
    name: "example_table_1",
    primaryKey: "id",
    columns: [
        zf.uuid("id").notNull(),
        // ✅ CORRECT: Start with zf.text(), then call .bool()
        zf.text("is_template").bool().notNull().default(false),
        zf.text("is_active").bool().default(true).notNull(),
        zf.text("is_verified").bool().nullable()
    ]
)

// MARK: - Example: Arrays vs Many-to-Many Relationships

let VibecodeTable = ZyraTable(
    name: "vibecode",
    primaryKey: "id",
    columns: [
        zf.uuid("id").notNull(),
        zf.text("name").notNull(),
        
        // ✅ Option 1: Array of UUIDs (no foreign key constraint, just stores IDs)
        // Use this if you just need to store a list of IDs without referential integrity
        zf.array("ide_ids", elementType: zf.uuid("ide_id"), strategy: .jsonb),
        
        // ✅ Option 2: Many-to-Many Relationship (recommended for actual relationships)
        // Use this if you need foreign key constraints and relationship queries
        zf.uuid("ide_id").belongsToMany(
            "ides",
            joinTableName: "vibecode_ides",
            additionalColumns: [
                zf.timestampz("added_at").default(.now).notNull(),
                zf.text("is_primary").bool().default(false).notNull()
            ]
        )
    ]
)

// MARK: - Example: Object Schema Syntax

let PlatformsTable = ZyraTable(
    name: "platforms",
    primaryKey: "id",
    columns: [
        zf.uuid("id").notNull(),
        zf.text("name").notNull(),
        
        // ✅ CORRECT: Dictionary format (required by current API)
        zf.object("slug", schema: [
            "pc": zf.text("pc").nullable(),
            "mac": zf.text("mac").nullable(),
            "linux": zf.text("linux").nullable()
        ], strategy: .jsonb),
        
        // ✅ Using helper function for cleaner syntax
        ColumnBuilder.simpleObject("supported_platforms", fields: ["windows", "macos", "linux"], strategy: .jsonb)
    ]
)

// MARK: - Complete Example Combining All Patterns

let CompleteExample = ZyraTable(
    name: "complete_example",
    primaryKey: "id",
    columns: [
        zf.uuid("id").notNull(),
        zf.text("name").notNull(),
        
        // Boolean fields
        zf.text("is_template").bool().default(false).notNull(),
        zf.text("is_active").bool().default(true).notNull(),
        
        // Object with JSONB strategy
        zf.object("metadata", schema: [
            "version": zf.text("version").nullable(),
            "author": zf.text("author").nullable(),
            "tags": zf.array("tags", elementType: zf.text("tag"), strategy: .jsonb).nullable()
        ], strategy: .jsonb),
        
        // Array of UUIDs (no foreign key)
        zf.array("related_ids", elementType: zf.uuid("related_id"), strategy: .jsonb),
        
        // Many-to-many relationship (with foreign keys)
        zf.uuid("category_id").belongsToMany(
            "categories",
            joinTableName: "example_categories",
            additionalColumns: [
                zf.timestampz("assigned_at").default(.now).notNull()
            ]
        )
    ]
)

