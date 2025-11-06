# Languages, IDEs, Frameworks, Dependencies, and Stores Schema

This schema defines the relationships between programming languages, IDEs, frameworks, dependencies, and package stores using ZeraForm.

## Relationship Overview

### Core Entities
- **Languages**: Programming languages (Swift, JavaScript, Python, etc.)
- **IDEs**: Integrated Development Environments (Xcode, VS Code, IntelliJ, etc.)
- **Frameworks**: Development frameworks (React, Vue, SwiftUI, etc.)
- **Dependencies**: Package dependencies/libraries
- **Stores**: Package managers/stores (npm, SPM, Maven, CocoaPods, etc.)

### Relationship Types

#### One-to-Many Relationships
- **Language → Frameworks**: One language can have many frameworks (but frameworks belong to one primary language)
- **Language → Dependencies**: One language can have many dependencies (but dependencies belong to one primary language)
- **Store → Dependencies**: One store can host many dependencies (but each dependency entry belongs to one store)

#### Many-to-Many Relationships
- **Languages ↔ IDEs**: Languages can be used in many IDEs, IDEs support many languages
- **Languages ↔ Frameworks**: Languages can have many frameworks, frameworks can support multiple languages
- **Languages ↔ Stores**: Languages can use many stores, stores support many languages
- **Frameworks ↔ Dependencies**: Frameworks can use many dependencies, dependencies can be used by many frameworks
- **Frameworks ↔ Stores**: Frameworks can be distributed via many stores, stores host many frameworks
- **Dependencies ↔ Stores**: Dependencies can be in many stores, stores host many dependencies

---

## Schema Definition

```swift
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
```

---

## Generated Tables

When you create this schema, ZeraForm will automatically generate the following join tables:

1. **ide_languages** - Links IDEs to languages they support
   - `id` (primary key)
   - `ide_id` (FK to ides)
   - `language_id` (FK to languages)
   - `supported_since` (timestamp, nullable)
   - `is_official` (boolean)
   - `support_level` (text)

2. **framework_languages** - Links frameworks to languages they support
   - `id` (primary key)
   - `framework_id` (FK to frameworks)
   - `language_id` (FK to languages)
   - `is_primary` (boolean)
   - `support_level` (text)

3. **framework_stores** - Links frameworks to stores where they're available
   - `id` (primary key)
   - `framework_id` (FK to frameworks)
   - `store_id` (FK to stores)
   - `package_name` (text, nullable)
   - `version` (text, nullable)
   - `published_at` (timestamp, nullable)

4. **store_languages** - Links stores to languages they support
   - `id` (primary key)
   - `store_id` (FK to stores)
   - `language_id` (FK to languages)
   - `is_native` (boolean)
   - `support_level` (text)

5. **dependency_languages** - Links dependencies to languages they support
   - `id` (primary key)
   - `dependency_id` (FK to dependencies)
   - `language_id` (FK to languages)
   - `is_primary` (boolean)
   - `support_level` (text)

6. **framework_dependencies** - Links frameworks to their dependencies
   - `id` (primary key)
   - `framework_id` (FK to frameworks)
   - `dependency_id` (FK to dependencies)
   - `version_constraint` (text, nullable)
   - `is_required` (boolean)
   - `usage_type` (text)

7. **dependency_stores** - Links dependencies to stores where they're available
   - `id` (primary key)
   - `dependency_id` (FK to dependencies)
   - `store_id` (FK to stores)
   - `package_name` (text)
   - `latest_version` (text, nullable)
   - `download_count` (integer)
   - `published_at` (timestamp, nullable)
   - `last_updated_at` (timestamp, nullable)

---

## Example Queries

### Get all languages supported by an IDE:
```sql
SELECT l.*, il.support_level, il.is_official
FROM languages l
JOIN ide_languages il ON l.id = il.language_id
WHERE il.ide_id = ?
```

### Get all frameworks for a language:
```sql
SELECT f.*
FROM frameworks f
WHERE f.primary_language_id = ?
   OR f.id IN (
       SELECT fl.framework_id 
       FROM framework_languages fl 
       WHERE fl.language_id = ?
   )
```

### Get all dependencies used by a framework:
```sql
SELECT d.*, fd.version_constraint, fd.is_required
FROM dependencies d
JOIN framework_dependencies fd ON d.id = fd.dependency_id
WHERE fd.framework_id = ?
```

### Get all stores where a dependency is available:
```sql
SELECT s.*, ds.package_name, ds.latest_version, ds.download_count
FROM stores s
JOIN dependency_stores ds ON s.id = ds.store_id
WHERE ds.dependency_id = ?
ORDER BY ds.download_count DESC
```

### Get all frameworks available in a specific store:
```sql
SELECT f.*, fs.package_name, fs.version
FROM frameworks f
JOIN framework_stores fs ON f.id = fs.framework_id
WHERE fs.store_id = ?
```

### Find dependencies that support multiple languages:
```sql
SELECT d.*, COUNT(dl.language_id) as language_count
FROM dependencies d
JOIN dependency_languages dl ON d.id = dl.dependency_id
GROUP BY d.id
HAVING COUNT(dl.language_id) > 1
```

---

## Usage Example

```swift
// Generate PostgreSQL migration
let postgresSQL = schema.generateMigrationSQL()
print(postgresSQL)

// Generate Prisma schema
let prismaSchema = schema.generatePrismaSchema()
print(prismaSchema)

// Generate PowerSync buckets
let powerSyncBuckets = schema.generatePowerSyncBucketDefinitions(
    dbPrefix: "",
    userIdColumn: "user_id"
)
print(powerSyncBuckets)
```

---

## Design Notes

### Primary vs. Multi-Language Support
- **Primary Language**: Each framework and dependency has a `primary_language_id` for the main language it's written in
- **Multi-Language Support**: Use the many-to-many join tables (`framework_languages`, `dependency_languages`) to track additional language support

### Store Distribution
- Frameworks and dependencies can be distributed via multiple stores
- Each store entry includes store-specific metadata (package name, version, etc.)

### Version Management
- Store-specific versions are tracked in join tables (`framework_stores.version`, `dependency_stores.latest_version`)
- Framework dependency versions use constraints (`framework_dependencies.version_constraint`)

### Support Levels
- Track support quality with `support_level` fields ("full", "partial", "experimental")
- Distinguish official vs. plugin support for IDE-language relationships

