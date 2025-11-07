# ZyraForm

**Version 2.0.6**

A comprehensive Swift package for defining database schemas with a fluent API and generating code for multiple platforms. Define your schema once in Swift and generate PostgreSQL migrations, MySQL schemas, Prisma models, Drizzle schemas, Zod validators, Swift models, and PowerSync bucket definitions.

## 🎯 Why ZyraForm?

### Single Source of Truth
Define your database schema once in Swift using a familiar, fluent syntax. ZyraForm serves as your single source of truth, eliminating schema drift and inconsistencies across your stack.

### Multi-Platform Code Generation
Generate code for multiple platforms from your Swift schema:
- **PostgreSQL** - Complete migration SQL with circular reference handling
- **MySQL** - Full schema generation with triggers
- **Prisma Schema** - For Node.js/TypeScript backends
- **Drizzle ORM Schema** - For TypeScript projects
- **Zod Schemas** - For runtime validation
- **Swift Models** - For SwiftData and your Swift app
- **PowerSync Buckets** - Automatic bucket definitions for PowerSync

### Advanced Features
- **Nested Objects & Arrays** - Define complex nested structures with flexible storage strategies
- **Circular Reference Handling** - Automatic detection and resolution of circular dependencies
- **Many-to-Many Relationships** - Automatic join table generation with `.belongsToMany()`
- **Row Level Security (RLS)** - Comprehensive RLS policy generation for Supabase
- **Field Encryption** - Built-in encryption support for sensitive fields
- **Type Safety** - Full Swift type safety throughout

## 📦 Installation

Add ZyraForm to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/ZyraForm.git", from: "2.0.0")
]
```

Or add it via Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select version `2.0.0` or later

## 🚀 Quick Start

### 1. Define Your Schema

```swift
import ZyraForm

// Define an enum
let UserRoleEnum = ZyraEnum(
    name: "user_role",
    values: ["admin", "user", "guest"]
)

// Define a table
let Users = ZyraTable(
    name: "users",
    primaryKey: "id",
    columns: [
        zf.uuid("id").notNull(),
        zf.text("email").email().unique().notNull(),
        zf.text("username").minLength(2).maxLength(50).notNull(),
        zf.text("role").enum(UserRoleEnum).default("user").notNull(),
        zf.timestampz("created_at").default(.now).notNull()
    ],
    rlsPolicies: [
        RLSPolicyBuilder(tableName: "users").canAccessOwn()
    ]
)

// Create schema
let schema = ZyraSchema(
    tables: [Users],
    enums: [UserRoleEnum],
    dbPrefix: ""
)
```

### 2. Generate Code

```swift
// Generate PostgreSQL migration
let postgresSQL = schema.generateMigrationSQL()
print(postgresSQL)

// Generate Prisma schema
let prismaSchema = schema.generatePrismaSchema()
print(prismaSchema)

// Generate Drizzle schema
let drizzleSchema = schema.generateDrizzleSchema()
print(drizzleSchema)

// Generate Zod schemas
let zodSchemas = schema.generateZodSchemas()
print(zodSchemas)

// Generate PowerSync buckets
let powerSyncBuckets = schema.generatePowerSyncBucketDefinitions()
print(powerSyncBuckets)
```

## 📚 Core Concepts

### Column Types

ZyraForm provides a fluent API for defining columns:

```swift
// Text columns
zf.text("name").minLength(2).maxLength(100).notNull()
zf.text("email").email().unique().notNull()
zf.text("website").url().nullable()
zf.uuid("id").notNull()
zf.url("avatar_url").nullable()
zf.email("contact_email").notNull()

// Numeric columns
zf.integer("age").intMin(0).intMax(120).nullable()
zf.number("likes").positive().notNull()  // Alias for integer
zf.int("count").default(0).notNull()     // Alias for integer
zf.bigint("user_count").notNull()  // BIGINT for large integers
zf.real("price").notNull()
zf.double("rating").nullable()
zf.decimal("amount", precision: 10, scale: 2).notNull()  // DECIMAL with precision/scale

// Boolean columns
zf.bool("is_active").default(false).notNull()

// Date/Time columns
zf.date("birth_date").nullable()
zf.time("start_time").nullable()
zf.timestampz("created_at").default(.now).notNull()
```

### Column Modifiers

- `.notNull()` - Column is required
- `.nullable()` - Column is optional (default)
- `.unique()` - Column has unique constraint
- `.encrypted()` - Column should be encrypted
- `.default(value)` - Set default value
- `.default(.now)` - Default to current timestamp
- `.minLength(n)` - Minimum string length
- `.maxLength(n)` - Maximum string length
- `.intMin(n)` - Minimum integer value
- `.intMax(n)` - Maximum integer value
- `.email()` - Email validation
- `.url()` - URL validation
- `.check(expression)` - Add CHECK constraint (e.g., `.check("age >= 0 AND age <= 150")`)

### CHECK Constraints

Add CHECK constraints to enforce data integrity at the database level:

```swift
let Products = ZyraTable(
    name: "products",
    primaryKey: "id",
    columns: [
        zf.text("name").notNull(),
        zf.decimal("price", precision: 10, scale: 2)
            .check("price > 0")
            .notNull(),
        zf.integer("stock")
            .check("stock >= 0")
            .notNull(),
        zf.integer("age")
            .check("age >= 0 AND age <= 150")
            .nullable()
    ]
)
```

Generated SQL includes CHECK constraints:
```sql
CREATE TABLE "products" (
    "id" TEXT PRIMARY KEY,
    "name" TEXT NOT NULL,
    "price" DECIMAL(10, 2) CHECK (price > 0) NOT NULL,
    "stock" INTEGER CHECK (stock >= 0) NOT NULL,
    "age" INTEGER CHECK (age >= 0 AND age <= 150)
);
```

### Relationships

#### One-to-Many Relationships

```swift
let Posts = ZyraTable(
    name: "posts",
    primaryKey: "id",
    columns: [
        zf.text("title").notNull(),
        zf.text("content").notNull()
    ]
)

let Comments = ZyraTable(
    name: "comments",
    primaryKey: "id",
    columns: [
        zf.uuid("post_id").references(Posts).notNull(),  // Foreign key
        zf.text("content").notNull()
    ]
)
```

#### Many-to-Many Relationships

ZyraForm automatically creates join tables for many-to-many relationships:

```swift
let Projects = ZyraTable(
    name: "projects",
    primaryKey: "id",
    columns: [
        zf.text("name").notNull(),
        // Many-to-many: Projects can belong to many teams
        zf.uuid("team_id").belongsToMany(
            "teams",
            joinTableName: "team_projects",
            additionalColumns: [
                zf.timestampz("granted_at").default(.now).notNull(),
                zf.text("permission_level").default("view").notNull()
            ]
        )
    ]
)
```

This automatically creates a `team_projects` join table with:
- `id` (primary key)
- `project_id` (FK to projects)
- `team_id` (FK to teams)
- `granted_at` (timestamp)
- `permission_level` (text)

### Indexes

ZyraForm supports defining indexes on tables, similar to PowerSync. Indexes improve query performance for frequently filtered or sorted columns:

```swift
import ZyraForm
import PowerSync

let TODOS_TABLE = "todos"

let todos = ZyraTable(
    name: TODOS_TABLE,
    columns: [
        zf.text("list_id").notNull(),
        zf.text("photo_id").nullable(),
        zf.text("description").nullable(),
        zf.integer("completed").notNull(),
        zf.text("created_at").notNull(),
        zf.text("completed_at").nullable(),
        zf.text("created_by").nullable(),
        zf.text("completed_by").nullable()
    ],
    indexes: [
        PowerSync.Index(
            name: "list_id",
            columns: [PowerSync.IndexedColumn.ascending("list_id")]
        )
    ]
)
```

Indexes are passed directly to PowerSync tables and are included when generating PowerSync schemas. You can define multiple indexes per table, and each index can include multiple columns:

```swift
let posts = ZyraTable(
    name: "posts",
    columns: [
        zf.text("user_id").notNull(),
        zf.text("category_id").nullable(),
        zf.text("status").notNull(),
        zf.timestampz("created_at").notNull()
    ],
    indexes: [
        PowerSync.Index(
            name: "user_id",
            columns: [PowerSync.IndexedColumn.ascending("user_id")]
        ),
        PowerSync.Index(
            name: "category_status",
            columns: [
                PowerSync.IndexedColumn.ascending("category_id"),
                PowerSync.IndexedColumn.descending("status")
            ]
        )
    ]
)
```

### Nested Objects and Arrays

ZyraForm supports nested objects and arrays with flexible storage strategies:

#### Flattened Strategy

Fields are flattened into the parent table with a prefix:

```swift
let Users = ZyraTable(
    name: "users",
    primaryKey: "id",
    columns: [
        zf.text("name").notNull(),
        zf.object("address", schema: [
            "street": zf.text("street").notNull(),
            "city": zf.text("city").notNull(),
            "zip": zf.text("zip").notNull()
        ], strategy: .flattened())
    ]
)
```

Generates columns: `address-street`, `address-city`, `address-zip`

#### JSONB Strategy

Store nested data as JSONB (PostgreSQL) or JSON (MySQL):

```swift
// Dictionary syntax (original)
zf.object("metadata", schema: [
    "preferences": zf.text("preferences").nullable(),
    "settings": zf.text("settings").nullable()
], strategy: .jsonb)

// Simplified array syntax (new in 2.0.3)
zf.object("slug", schema: [
    zf.text("pc").nullable(),
    zf.text("mac").nullable(),
    zf.text("linux").nullable()
], strategy: .jsonb)
```

#### Separate Table Strategy

Store nested data in a separate table with a foreign key:

```swift
zf.object("profile", schema: [
    "bio": zf.text("bio").nullable(),
    "avatar": zf.url("avatar").nullable()
], strategy: .separateTable(tableName: "user_profiles", relationshipType: .oneToOne))
```

#### Arrays

Arrays support the same strategies, with automatic handling for nested structures:

```swift
// Array of simple values (stored as JSONB)
zf.array("tags", elementType: zf.text("tag"), strategy: .jsonb)

// Array of objects (separate table with position column)
zf.array("items", elementType: zf.object("item", schema: [
    "name": zf.text("name").notNull(),
    "quantity": zf.integer("quantity").notNull()
], strategy: .separateTable(relationshipType: .oneToMany))
```

**Note:** Arrays with `.flattened()` strategy automatically fall back to JSONB, as arrays cannot be truly flattened into columns.

### Circular References

ZyraForm automatically handles circular references by:
1. Creating all tables without foreign keys first
2. Adding foreign keys via `ALTER TABLE` statements

This allows tables to reference each other without errors:

```swift
let Organizations = ZyraTable(
    name: "organizations",
    primaryKey: "id",
    columns: [
        zf.text("name").notNull(),
        zf.uuid("creator_user_id").references("users").notNull()
    ]
)

let Users = ZyraTable(
    name: "users",
    primaryKey: "id",
    columns: [
        zf.text("email").notNull(),
        zf.uuid("primary_organization_id").references(Organizations).nullable()
    ]
)
```

### Row Level Security (RLS)

ZyraForm provides comprehensive RLS support aligned with Supabase RBAC:

```swift
let Posts = ZyraTable(
    name: "posts",
    primaryKey: "id",
    columns: [
        zf.text("title").notNull(),
        zf.text("content").notNull(),
        zf.uuid("user_id").notNull()
    ],
    rlsPolicies: [
        // Users can access their own posts, admins can access all
        RLSPolicyBuilder(tableName: "posts")
            .canAccessOwn(allowRoles: ["admin"]),
        
        // Public read access
        RLSPolicyBuilder(tableName: "posts")
            .canRead()
    ]
)
```

See the [RLS Guide](Documentation/RLS_GUIDE.md) for more details.

### Enums

Define database enums that work across all platforms:

```swift
let ProjectStatusEnum = ZyraEnum(
    name: "project_status",
    values: ["active", "archived", "deleted"]
)

let Projects = ZyraTable(
    name: "projects",
    primaryKey: "id",
    columns: [
        zf.text("name").notNull(),
        zf.text("status").enum(ProjectStatusEnum).default("active").notNull()
    ]
)
```

## 🔧 Code Generation

### PostgreSQL Migration

```swift
let sql = schema.generateMigrationSQL()
```

Generates:
- Enum creation statements
- Table creation (without foreign keys)
- Foreign key constraints (via ALTER TABLE)
- Triggers (for `updated_at` columns)
- RLS policies

### MySQL Migration

```swift
let sql = schema.generateMySQLMigrationSQL()
```

Generates MySQL-compatible SQL with:
- ENUM types
- AUTO_INCREMENT for integer primary keys
- Triggers for `updated_at` columns

### Prisma Schema

```swift
let prisma = schema.generatePrismaSchema()
```

Generates a complete Prisma schema file with:
- Models for all tables
- Relations for foreign keys
- Enums
- Many-to-many relationships

### Drizzle Schema

```swift
let drizzle = schema.generateDrizzleSchema()
```

Generates TypeScript Drizzle ORM schemas with:
- Table definitions
- Column types
- Foreign key relations
- Enums

### Zod Schemas

```swift
let zod = schema.generateZodSchemas()
```

Generates Zod validation schemas for:
- Runtime validation
- Type inference
- Nested objects and arrays

### Swift Models

```swift
let swiftModels = schema.generateSwiftModels()
```

Generates Swift structs with:
- Codable conformance
- CodingKeys
- Type-safe properties

### PowerSync Buckets

```swift
let buckets = schema.generatePowerSyncBucketDefinitions(
    dbPrefix: "",
    userIdColumn: "user_id"
)
```

Automatically generates PowerSync bucket definitions:
- Separates tables into global and user-specific buckets
- Includes all auto-generated tables (join tables, separate tables)
- Handles table name formatting

## 📖 Documentation

- [RLS Guide](Documentation/RLS_GUIDE.md) - Comprehensive Row Level Security documentation
- [Join Tables Guide](Documentation/JOIN_TABLES_GUIDE.md) - Understanding many-to-many relationships
- [Schema Examples](Documentation/SCHEMA_EXAMPLE_PROJECTS_TEAMS.md) - Real-world schema examples
- [ORM Comparison](Documentation/ORM_COMPARISON_BELONGSTOMANY.md) - Comparison with other ORMs
- [Circular Reference Analysis](Documentation/CIRCULAR_REFERENCE_ANALYSIS.md) - How circular references are handled

## 🎨 Example: Complete Schema

```swift
import ZyraForm

// Enums
let ProjectStatusEnum = ZyraEnum(
    name: "project_status",
    values: ["active", "archived", "deleted"]
)

// Tables
let Users = ZyraTable(
    name: "users",
    primaryKey: "id",
    columns: [
        zf.uuid("id").notNull(),
        zf.text("email").email().unique().notNull(),
        zf.text("username").minLength(2).notNull(),
        zf.url("avatar_url").nullable()
    ],
    rlsPolicies: [
        RLSPolicyBuilder(tableName: "users").canAccessOwn()
    ]
)

let Organizations = ZyraTable(
    name: "organizations",
    primaryKey: "id",
    columns: [
        zf.uuid("id").notNull(),
        zf.text("name").minLength(2).notNull(),
        zf.uuid("creator_user_id").references(Users).notNull()
    ]
)

let Projects = ZyraTable(
    name: "projects",
    primaryKey: "id",
    columns: [
        zf.uuid("id").notNull(),
        zf.text("name").encrypted().minLength(2).notNull(),
        zf.text("description").encrypted().nullable(),
        zf.uuid("owner_id").references(Users).nullable(),
        zf.uuid("org_id").references(Organizations).nullable(),
        zf.text("status").enum(ProjectStatusEnum).default("active").notNull(),
        // Many-to-many with teams
        zf.uuid("team_id").belongsToMany(
            "teams",
            joinTableName: "team_projects",
            additionalColumns: [
                zf.timestampz("granted_at").default(.now).notNull(),
                zf.text("permission_level").default("view").notNull()
            ]
        )
    ],
    rlsPolicies: [
        RLSPolicyBuilder(tableName: "projects").canAccessOwn(allowRoles: ["admin"])
    ]
)

// Schema
let schema = ZyraSchema(
    tables: [Users, Organizations, Projects],
    enums: [ProjectStatusEnum],
    dbPrefix: ""
)

// Generate code
let postgresSQL = schema.generateMigrationSQL()
let prismaSchema = schema.generatePrismaSchema()
let powerSyncBuckets = schema.generatePowerSyncBucketDefinitions()
```

## 🔒 Security Features

### Field Encryption

Mark sensitive fields for encryption. ZyraForm supports two encryption modes:

**1. Per-User Encryption (Deep Encryption) - `.encrypted()`**
- Uses user-specific keys - only the record owner can decrypt
- Best for highly sensitive data that should never be shared

```swift
zf.text("password").encrypted().notNull()
zf.text("ssn").encrypted().nullable()
```

**2. Shared/Master Key Encryption (Light Encryption) - `.encryptedLight()`**
- Uses a single master key - anyone with access can decrypt
- RLS and privacy controls determine access - encryption is just for at-rest protection
- Can be shared via `shared_fields` like non-encrypted fields

```swift
zf.text("api_key").encryptedLight().private().nullable()
zf.text("token").encryptedLight().nullable()
```

Encrypted fields are stored as TEXT in the database but validated on decrypted values.

### Row Level Security

Comprehensive RLS support with role-based access control using a new fluent API:

```swift
// Simple: Users can only access their own rows
table.fluentRls()
    .who([.authenticated])
    .access([.read, .write, .update, .delete])
    .own()
    .build()

// Advanced: Multiple roles with custom matching
table.fluentRls()
    .who([.authenticated, .admin])
    .permissive()
    .access([.read, .write, .update])
    .match("user_id = auth.uid() OR team_id IN (SELECT team_id FROM user_teams WHERE user_id = auth.uid())")
    .build()
```

See [RLS Guide](Documentation/RLS_GUIDE.md) for details.

## 🚨 Important Notes

### Circular References

ZyraForm automatically handles circular references by creating tables without foreign keys first, then adding foreign keys via `ALTER TABLE`. This allows tables to reference each other without errors.

### Nested Schema Recursion

Nested objects and arrays support deep nesting with automatic cycle detection:
- Maximum recursion depth: 10 levels
- Circular references detected and handled gracefully
- Falls back to JSONB for circular structures

### Many-to-Many Relationships

- Join tables are automatically created
- The marker column is removed from the original table
- Additional columns can be specified inline
- Many-to-many within nested objects only works with `.separateTable` strategy

### PowerSync Integration

- All auto-generated tables (join tables, separate tables) are included in bucket definitions
- Tables are automatically separated into global and user-specific buckets
- Table names are properly formatted for PowerSync

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

[Add your license here]

## 🙏 Acknowledgments

- Built for Swift and SwiftUI
- Integrates with PowerSync for offline-first apps
- Designed for Supabase PostgreSQL databases
- Inspired by Prisma, Drizzle, and Zod

---

**Version 2.0.6** - Added index support for tables. Indexes are now generated in PostgreSQL migrations, MySQL migrations, Prisma schemas, Drizzle schemas, and PowerSync tables. Use `PowerSync.Index` and `PowerSync.IndexedColumn` to define indexes on your tables.

**Version 2.0.5** - Added light encryption mode (`.encryptedLight()`) for shared/master key encryption. RLS and privacy controls handle access - encryption is just for at-rest protection. Per-user encryption (`.encrypted()`) remains for highly sensitive data.

**Version 2.0.4** - Added `zf.number()` and `zf.int()` convenience aliases for integer columns.

**Version 2.0.3** - Added simplified array syntax for `zf.object()` schema definition.

**Version 2.0.2** - Added `zf.bool()` convenience method for boolean columns.

**Version 2.0.0** - Major release with nested schemas, circular reference handling, and comprehensive code generation support.
