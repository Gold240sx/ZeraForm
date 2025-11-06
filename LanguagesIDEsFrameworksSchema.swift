//
//  LanguagesIDEsFrameworksSchema.swift
//  ZeraForm Schema Example
//
//  Defines relationships between Languages, IDEs, Frameworks, Dependencies, and Stores
//

import ZyraForm

// MARK: - Enums

let LanguageTypeEnum = ZyraEnum(
    name: "language_type",
    values: ["compiled", "interpreted", "hybrid"]
)

let StoreTypeEnum = ZyraEnum(
    name: "store_type",
    values: ["package_manager", "registry", "repository"]
)

let DependencyTypeEnum = ZyraEnum(
    name: "dependency_type",
    values: ["library", "framework", "tool", "runtime"]
)

// MARK: - Core Tables

let Languages = ZyraTable(
    name: "languages",
    primaryKey: "id",
    columns: [
        zf.uuid("id").notNull(),
        zf.text("name").unique().notNull(),  // e.g., "Swift", "JavaScript"
        zf.text("slug").unique().notNull(),  // e.g., "swift", "javascript"
        zf.text("description").nullable(),
        zf.text("type").enum(LanguageTypeEnum).notNull(),  // compiled, interpreted, hybrid
        zf.url("website").nullable(),
        zf.url("logo_url").nullable(),
        zf.timestampz("created_at").default(.now).notNull(),
        zf.timestampz("updated_at").default(.now).notNull()
    ]
)

let IDEs = ZyraTable(
    name: "ides",
    primaryKey: "id",
    columns: [
        zf.uuid("id").notNull(),
        zf.text("name").unique().notNull(),  // e.g., "Xcode", "VS Code"
        zf.text("slug").unique().notNull(),  // e.g., "xcode", "vs-code"
        zf.text("description").nullable(),
        zf.text("vendor").nullable(),  // e.g., "Apple", "Microsoft"
        zf.url("website").nullable(),
        zf.url("logo_url").nullable(),
        zf.bool("is_open_source").default(false).notNull(),
        zf.timestampz("created_at").default(.now).notNull(),
        zf.timestampz("updated_at").default(.now).notNull(),
        
        // Many-to-many: IDEs support many languages
        zf.uuid("language_id").belongsToMany(
            "languages",
            joinTableName: "ide_languages",
            additionalColumns: [
                zf.timestampz("supported_since").nullable(),  // When IDE started supporting this language
                zf.bool("is_official").default(false).notNull(),  // Official support vs plugin
                zf.text("support_level").default("full").notNull()  // e.g., "full", "partial", "experimental"
            ]
        )
    ]
)

let Frameworks = ZyraTable(
    name: "frameworks",
    primaryKey: "id",
    columns: [
        zf.uuid("id").notNull(),
        zf.text("name").unique().notNull(),  // e.g., "React", "SwiftUI"
        zf.text("slug").unique().notNull(),  // e.g., "react", "swiftui"
        zf.text("description").nullable(),
        zf.url("website").nullable(),
        zf.url("logo_url").nullable(),
        zf.url("repository_url").nullable(),  // GitHub/GitLab URL
        zf.bool("is_open_source").default(false).notNull(),
        zf.timestampz("created_at").default(.now).notNull(),
        zf.timestampz("updated_at").default(.now).notNull(),
        
        // One-to-many: Framework belongs to a primary language
        zf.uuid("primary_language_id").references(Languages).notNull(),
        
        // Many-to-many: Frameworks can support multiple languages
        zf.uuid("language_id").belongsToMany(
            "languages",
            joinTableName: "framework_languages",
            additionalColumns: [
                zf.bool("is_primary").default(false).notNull(),  // Mark primary language
                zf.text("support_level").default("full").notNull()  // e.g., "full", "partial"
            ]
        ),
        
        // Many-to-many: Frameworks can be distributed via multiple stores
        zf.uuid("store_id").belongsToMany(
            "stores",
            joinTableName: "framework_stores",
            additionalColumns: [
                zf.text("package_name").nullable(),  // Package name in this store
                zf.text("version").nullable(),  // Current version in this store
                zf.timestampz("published_at").nullable()
            ]
        )
    ]
)

let Stores = ZyraTable(
    name: "stores",
    primaryKey: "id",
    columns: [
        zf.uuid("id").notNull(),
        zf.text("name").unique().notNull(),  // e.g., "npm", "Swift Package Manager"
        zf.text("slug").unique().notNull(),  // e.g., "npm", "spm"
        zf.text("description").nullable(),
        zf.text("type").enum(StoreTypeEnum).notNull(),  // package_manager, registry, repository
        zf.url("website").nullable(),
        zf.url("logo_url").nullable(),
        zf.bool("is_open_source").default(false).notNull(),
        zf.timestampz("created_at").default(.now).notNull(),
        zf.timestampz("updated_at").default(.now).notNull(),
        
        // Many-to-many: Stores support many languages
        zf.uuid("language_id").belongsToMany(
            "languages",
            joinTableName: "store_languages",
            additionalColumns: [
                zf.bool("is_native").default(false).notNull(),  // Native support vs compatibility
                zf.text("support_level").default("full").notNull()
            ]
        )
    ]
)

let Dependencies = ZyraTable(
    name: "dependencies",
    primaryKey: "id",
    columns: [
        zf.uuid("id").notNull(),
        zf.text("name").notNull(),  // e.g., "axios", "Alamofire"
        zf.text("slug").notNull(),
        zf.text("description").nullable(),
        zf.text("type").enum(DependencyTypeEnum).notNull(),  // library, framework, tool, runtime
        zf.url("repository_url").nullable(),
        zf.url("documentation_url").nullable(),
        zf.bool("is_open_source").default(false).notNull(),
        zf.timestampz("created_at").default(.now).notNull(),
        zf.timestampz("updated_at").default(.now).notNull(),
        
        // One-to-many: Dependency belongs to a primary language
        zf.uuid("primary_language_id").references(Languages).notNull(),
        
        // Many-to-many: Dependencies can support multiple languages
        zf.uuid("language_id").belongsToMany(
            "languages",
            joinTableName: "dependency_languages",
            additionalColumns: [
                zf.bool("is_primary").default(false).notNull(),
                zf.text("support_level").default("full").notNull()
            ]
        ),
        
        // Many-to-many: Dependencies can be used by many frameworks
        zf.uuid("framework_id").belongsToMany(
            "frameworks",
            joinTableName: "framework_dependencies",
            additionalColumns: [
                zf.text("version_constraint").nullable(),  // e.g., "^1.0.0", ">=2.0.0"
                zf.bool("is_required").default(true).notNull(),
                zf.text("usage_type").default("runtime").notNull()  // e.g., "runtime", "dev", "peer"
            ]
        ),
        
        // Many-to-many: Dependencies can be available in multiple stores
        zf.uuid("store_id").belongsToMany(
            "stores",
            joinTableName: "dependency_stores",
            additionalColumns: [
                zf.text("package_name").notNull(),  // Package name in this store
                zf.text("latest_version").nullable(),
                zf.integer("download_count").default(0).notNull(),
                zf.timestampz("published_at").nullable(),
                zf.timestampz("last_updated_at").nullable()
            ]
        )
    ]
)

// MARK: - Complete Schema

let schema = ZyraSchema(
    tables: [
        Languages,
        IDEs,
        Frameworks,
        Stores,
        Dependencies
    ],
    enums: [
        LanguageTypeEnum,
        StoreTypeEnum,
        DependencyTypeEnum
    ],
    dbPrefix: ""
)

// MARK: - Code Generation Examples

// Generate PostgreSQL migration
func generatePostgreSQLMigration() -> String {
    return schema.generateMigrationSQL()
}

// Generate Prisma schema
func generatePrismaSchema() -> String {
    return schema.generatePrismaSchema()
}

// Generate Drizzle schema
func generateDrizzleSchema() -> String {
    return schema.generateDrizzleSchema()
}

// Generate Zod schemas
func generateZodSchemas() -> String {
    return schema.generateZodSchemas()
}

// Generate Swift models
func generateSwiftModels() -> String {
    return schema.generateSwiftModels()
}

// Generate PowerSync buckets
func generatePowerSyncBuckets() -> String {
    return schema.generatePowerSyncBucketDefinitions(
        dbPrefix: "",
        userIdColumn: "user_id"
    )
}

