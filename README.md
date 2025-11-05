# ZyraForm

A comprehensive Swift package for building database schemas, forms, and applications with PowerSync, Supabase, and PostgreSQL. Define your schema once in Swift and generate code for multiple platforms.

## Why Use ZyraForm?

### 🎯 Single Source of Truth
Define your database schema once in Swift using familiar, fluent syntax. ZyraForm serves as your single source of truth, eliminating schema drift and inconsistencies across your stack.

### 🔄 Code Export & Familiarity
Generate code for multiple platforms from your Swift schema:
- **Prisma Schema** - For Node.js/TypeScript backends
- **Drizzle ORM Schema** - For TypeScript projects
- **Zod Schemas** - For runtime validation
- **Swift Models** - For SwiftData and your Swift app

This means your team can work with familiar tools while maintaining consistency.

### 🏗️ Internal App Use
Beyond schema generation, ZyraForm provides:
- **Form validation** with multiple validation modes
- **CRUD operations** via `ZyraSync` service
- **Automatic encryption** for sensitive fields
- **Row Level Security (RLS)** policy generation
- **Many-to-many relationship** handling with automatic join tables

### 📦 Familiar Syntax
If you've used libraries like Prisma, Drizzle, or Zod, ZyraForm's syntax will feel instantly familiar:

```swift
zf.text("email").email().unique().notNull()
zf.text("name").minLength(2).maxLength(50).notNull()
zf.integer("age").intMin(18).intMax(120).nullable()
```

## Installation

Add ZyraForm to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/ZyraForm.git", from: "1.2.0")
]
```

Or add it via Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select version `1.2.0` or later

## Quick Start

### 1. Define Your Schema

```swift
import ZyraForm

let employeesTable = ZyraTable(
    name: "\(AppConfig.dbPrefix)employees",
    columns: [
        zf.text("email").email().unique().notNull(),
        zf.text("name").minLength(2).maxLength(50).notNull(),
        zf.integer("age").intMin(18).intMax(120).nullable(),
        zf.text("website").url().nullable()
    ],
    rlsPolicies: [
        RLSPolicyBuilder(tableName: "\(AppConfig.dbPrefix)employees")
            .canAccessOwn()
    ]
)

let schema = ZyraSchema(tables: [employeesTable])
```

### 2. Initialize ZyraForm

```swift
import ZyraForm
import ZyraFormSupabase  // Optional: for Supabase integration

let connector = SupabaseConnector(
    supabaseURL: URL(string: "https://your-project.supabase.co")!,
    supabaseKey: "your-supabase-anon-key"
)

let config = ZyraFormConfig(
    connector: connector,
    powerSyncEndpoint: "https://your-id.powersync.journeyapps.com",
    powerSyncPassword: "your-powersync-password",
    userId: "current-user-id",
    schema: schema
)

try await ZyraFormManager.initialize(with: config)
```

### 3. Use Forms and Services

```swift
// Get a service for CRUD operations
let service = ZyraFormManager.shared!.service(for: "\(AppConfig.dbPrefix)employees")

// Create a record
try await service.createRecord(
    fields: ["email": "john@example.com", "name": "John Doe"],
    encryptedFields: ["email", "name"],
    autoGenerateId: true,
    autoTimestamp: true
)

// Load records
try await service.loadRecords(
    fields: ["*"],
    whereClause: "user_id = ?",
    parameters: [userId],
    encryptedFields: ["email", "name"]
)
```

## Usage

### Schema Definition

ZyraForm uses a fluent API for defining tables and columns:

```swift
let usersTable = ZyraTable(
    name: "\(AppConfig.dbPrefix)users",
    columns: [
        zf.text("email").email().unique().notNull(),
        zf.text("username").unique().notNull(),
        zf.text("password").notNull(),
        zf.integer("age").intMin(0).intMax(150).nullable(),
        zf.bool("is_online").default(false).notNull(),
        zf.text("role").enum(UserRoleEnum).default("user").notNull()
    ]
)
```

### Column Types

- **Text**: `zf.text("column_name")`
- **Integer**: `zf.integer("column_name")` or `zf.text("column_name").int()`
- **Boolean**: `zf.bool("column_name")` or `zf.text("column_name").bool()`
- **Double**: `zf.double("column_name")` or `zf.text("column_name").double()`
- **UUID**: `zf.text("column_name").uuid()`
- **Date**: `zf.text("column_name").date()` (stored as TIMESTAMPTZ)

### Column Modifiers

- `.notNull()` - Column is required
- `.nullable()` - Column is optional
- `.unique()` - Column has unique constraint
- `.encrypted()` - Column should be encrypted
- `.default(value)` - Set default value
- `.default(.now)` - Default to current timestamp

## Row Level Security (RLS)

ZyraForm provides comprehensive RLS support with both convenience methods and custom SQL expressions.

### Quick Start RLS

```swift
let postsTable = ZyraTable(
    name: "\(AppConfig.dbPrefix)posts",
    columns: [
        zf.text("title").notNull(),
        zf.text("content").notNull(),
        zf.text("user_id").notNull()
    ],
    rlsPolicies: [
        // Users can only access their own posts
        table.rls().canAccessOwn(),
        
        // Admins can delete any post
        table.rls().adminCanDelete()
    ]
)
```

### Shortform RLS Methods

ZyraForm provides convenient shortform methods for common RLS patterns:

```swift
// Permission-based policies
table.rls().authenticated()      // Only authenticated users
table.rls().anonymous()          // Only anonymous users
table.rls().superUser()          // Only superusers
table.rls().admin()              // Only admins
table.rls().editor()             // Admins or editors
table.rls().online()             // Only online users

// Convenience methods
table.rls().canRead()            // Read access for authenticated users
table.rls().canWriteOwn()        // Write own records
table.rls().canUpdateOwn()       // Update own records
table.rls().canDeleteIfSuperuser() // Delete if superuser

// Admin shortcuts
table.rls().adminCanDelete()     // Admin can delete
table.rls().adminCanUpdate()     // Admin can update
table.rls().adminCanInsert()     // Admin can insert
table.rls().adminCanSelect()     // Admin can select
```

### Common RLS Patterns

```swift
// Users can only access their own rows
table.rls().canAccessOwn()

// Everyone can read, but only owners can modify
table.rls().canReadAllModifyOwnSeparate()

// Allow all operations (no restrictions)
table.rls().canAccessAll()

// Custom SQL expression
table.rls().custom(
    name: "custom_policy",
    operation: .select,
    usingExpression: "published = true OR user_id = auth.uid()::text"
)
```

### User Role Permissions

ZyraForm includes built-in helpers for role-based access control:

```swift
// Check for admin role
table.rls().admin(operation: .delete)

// Check for editor role (admin or editor)
table.rls().editor(operation: .all)

// Check for superuser status
table.rls().superUser(operation: .all)

// Custom role check
table.rls().userOrPermission(
    name: "moderator_access",
    operation: .all,
    permission: "moderator",
    permissionColumn: "role"
)
```

### isOnline RLS Permissions

Check if users are online before allowing access:

```swift
let messagesTable = ZyraTable(
    name: "\(AppConfig.dbPrefix)messages",
    columns: [...],
    rlsPolicies: [
        // Only online users can send messages
        table.rls(isOnlineColumn: "is_online").online(operation: .insert),
        
        // Online users can read all messages
        table.rls().online(operation: .select)
    ]
)
```

### RLS Policy Builder

The `RLSPolicyBuilder` provides fine-grained control:

```swift
RLSPolicyBuilder(
    tableName: "posts",
    userIdColumn: "author_id",
    usersTableName: "users",
    isSuperUserColumn: "is_superuser",
    isOnlineColumn: "is_online"
)
.custom(
    name: "authors_can_edit",
    operation: .update,
    usingExpression: "author_id = auth.uid()::text",
    withCheckExpression: "author_id = auth.uid()::text"
)
```

See [RLS_GUIDE.md](RLS_GUIDE.md) for complete RLS documentation.

## Validations

ZyraForm provides comprehensive validation rules similar to Zod:

### String Validations

```swift
zf.text("email")
    .email()                    // Must be valid email
    .url()                      // Must be valid URL
    .isHttpUrl()                // Must be HTTP/HTTPS URL
    .uuid()                     // Must be UUID format
    .minLength(2)               // Minimum length
    .maxLength(50)              // Maximum length
    .exactLength(10)            // Exact length
    .startsWith("https://")    // Must start with string
    .endsWith(".com")           // Must end with string
    .includes("example")        // Must include string
    .isUppercase()              // Must be uppercase
    .isLowercase()              // Must be lowercase
    .regex(pattern: "^[A-Z]")   // Custom regex
```

### Number Validations

```swift
zf.integer("age")
    .intMin(18)                 // Minimum value
    .intMax(120)                // Maximum value
    .positive()                 // Must be positive
    .negative()                 // Must be negative
    .isEven()                   // Must be even
    .isOdd()                    // Must be odd
```

### Enum Validations

```swift
let UserRoleEnum = DatabaseEnum(
    name: "user_role",
    values: ["admin", "editor", "user"]
)

zf.text("role")
    .enum(UserRoleEnum)
    .default("user")
    .notNull()
```

### Custom Validations

```swift
zf.text("custom_field")
    .customValidation(
        "Custom Rule",
        validator: { value in
            // Your custom validation logic
            return value.count > 5
        }
    )
```

## Errors

ZyraForm provides comprehensive error handling:

### Form Errors

```swift
// Check if field has error
if form.hasError("email") {
    let errorMessage = form.getError("email")
    // Display error message
}

// Clear all errors
form.errors.clear()

// Remove specific error
form.errors.remove("email")
```

### Validation Modes

```swift
let form = ZyraFormManager.shared!.form(
    for: table,
    mode: .onChange    // Validate on every change
    // .onBlur        // Validate when field loses focus
    // .onSubmit      // Validate only on submit
    // .onTouched     // Validate once field is touched
)
```

### Error Handling in Services

```swift
do {
    try await service.createRecord(fields: fields)
} catch {
    // Handle error
    print("Error: \(error.localizedDescription)")
}
```

## Code Output

ZyraForm can generate code for multiple platforms from your Swift schema.

### Prisma Schema

```swift
let prismaSchema = schema.generatePrismaSchema(dbPrefix: "app_")
print(prismaSchema)
```

Generates:
```prisma
model Employee {
  id        String   @id @default(uuid())
  email     String   @unique
  name      String
  age       Int?
  website   String?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  
  @@map("app_employees")
}
```

### Drizzle Schema

```swift
let drizzleSchema = schema.generateDrizzleSchema(dbPrefix: "app_")
print(drizzleSchema)
```

Generates:
```typescript
export const employees = pgTable("app_employees", {
  id: text("id").primaryKey(),
  email: text("email").notNull().unique(),
  name: text("name").notNull(),
  age: integer("age"),
  website: text("website"),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true })
});
```

### Zod Schema

```swift
let zodSchema = schema.generateZodSchema(dbPrefix: "app_")
print(zodSchema)
```

Generates:
```typescript
export const EmployeeSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  name: z.string().min(2).max(50),
  age: z.number().int().min(18).max(120).optional(),
  website: z.string().url().optional(),
  createdAt: z.string().datetime(),
  updatedAt: z.string().datetime().optional()
});
```

### Swift Models

```swift
let swiftModel = table.generateSwiftModel()
print(swiftModel)
```

Generates:
```swift
struct Employee: Codable, Identifiable, Hashable {
    let id: String
    let email: String
    let name: String
    let age: Int?
    let website: String?
    let createdAt: String
    let updatedAt: String?
}
```

### SQL Migrations

```swift
let sql = schema.generateSQL()
print(sql)
```

Generates:
```sql
CREATE TABLE "app_employees" (
    id TEXT PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    age TEXT,
    website TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ
);

-- RLS Policies
ALTER TABLE "app_employees" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "app_employees_own_access" PERMISSIVE ON "app_employees"
FOR ALL USING (user_id = auth.uid()::text)
WITH CHECK (user_id = auth.uid()::text);
```

## Encryption

ZyraForm automatically encrypts sensitive fields:

### Marking Fields as Encrypted

```swift
let usersTable = ZyraTable(
    name: "users",
    columns: [
        zf.text("email").email().encrypted().notNull(),
        zf.text("ssn").encrypted().notNull(),
        zf.text("name").notNull()  // Not encrypted
    ]
)
```

### Using Encrypted Fields

```swift
// Encryption is handled automatically
try await service.createRecord(
    fields: ["email": "user@example.com", "ssn": "123-45-6789"],
    encryptedFields: ["email", "ssn"]  // Auto-detected from schema
)
```

### Encryption Manager

The `SecureEncryptionManager` handles encryption/decryption:

```swift
// Set encryption password (done automatically during initialization)
SecureEncryptionManager.shared.setPassword("your-password")

// Fields marked with .encrypted() are automatically encrypted/decrypted
```

## Many-to-Many Relationships

ZyraForm automatically handles many-to-many relationships by creating join tables:

```swift
let postsTable = ZyraTable(
    name: "posts",
    columns: [
        zf.text("title").notNull(),
        zf.text("content").notNull()
    ]
)

let tagsTable = ZyraTable(
    name: "tags",
    columns: [
        zf.text("name").unique().notNull()
    ]
)

// Many-to-many relationship
let postsWithTagsTable = ZyraTable(
    name: "posts",
    columns: [
        zf.text("title").notNull(),
        zf.text("content").notNull(),
        zf.text("tag_id").belongsToMany(tagsTable)  // Creates join table
    ]
)
```

ZyraForm automatically creates:
- `posts_tags` join table
- Foreign keys with proper cascade/set null actions
- Indexes for efficient queries

## Foreign Keys

Define relationships between tables with foreign key constraints:

```swift
let commentsTable = ZyraTable(
    name: "comments",
    columns: [
        zf.text("post_id")
            .references("posts", column: "id", 
                       referenceUpdated: .cascade,
                       referenceRemoved: .cascade)
            .notNull(),
        zf.text("content").notNull()
    ]
)
```

### Foreign Key Actions

- `.cascade` - Cascade updates/deletes
- `.setNull` - Set to NULL on delete
- `.restrict` - Prevent delete if referenced
- `.noAction` - No action (database default)

## Database Enums

Define enums that work across all code generators:

```swift
let UserRoleEnum = DatabaseEnum(
    name: "user_role",
    values: ["admin", "editor", "user", "guest"]
)

let usersTable = ZyraTable(
    name: "users",
    columns: [
        zf.text("role")
            .enum(UserRoleEnum)
            .default("user")
            .notNull()
    ]
)
```

Enums are generated in:
- Prisma: `enum UserRole { ... }`
- Drizzle: `pgEnum("user_role", ...)`
- Zod: `z.enum(["admin", "editor", "user", "guest"])`
- Swift: Custom enum type

## Logging

ZyraForm includes comprehensive logging for debugging:

### Enable/Disable Logging

```swift
// Disable logging
ZyraFormLogger.isEnabled = false

// Enable logging
ZyraFormLogger.isEnabled = true
```

### Logged Events

- Supabase connection errors
- PowerSync endpoint issues
- 404 errors (table/record not found)
- Authentication errors (401, 403)
- Encryption/decryption errors
- RLS policy violations

### Example Log Output

```
ℹ️ [ZyraForm INFO] 🚀 Initializing ZyraForm...
ℹ️ [ZyraForm INFO] 📋 Supabase URL: https://your-project.supabase.co
ℹ️ [ZyraForm INFO] 📋 PowerSync Endpoint: https://id.powersync.journeyapps.com
❌ [ZyraForm ERROR] ❌ [SUPABASE 404] Resource not found
❌ [ZyraForm ERROR] 📋 Table: employees
❌ [ZyraForm ERROR] 💡 Possible causes:
❌ [ZyraForm ERROR]    1. Table 'employees' does not exist in Supabase
❌ [ZyraForm ERROR]    2. Record with id 'xxx' was already deleted
❌ [ZyraForm ERROR]    3. Row Level Security (RLS) policy is blocking access
```

## Optional Supabase Integration

ZyraForm core is Supabase-agnostic. Use the optional `ZyraFormSupabase` module:

```swift
import ZyraFormSupabase

let connector = SupabaseConnector(
    supabaseURL: URL(string: "https://your-project.supabase.co")!,
    supabaseKey: "your-anon-key"
)

let config = ZyraFormConfig(
    connector: connector,  // Uses your connector
    // ... other config
)
```

Or implement your own `PowerSyncBackendConnectorProtocol`:

```swift
class CustomConnector: PowerSyncBackendConnectorProtocol {
    // Implement your backend connector
}
```

## Architecture

### Single Source of Truth

Your Swift schema (`ZyraTable` and `ZyraSchema`) is the single source of truth. All code generation derives from this schema, ensuring consistency.

### Code Generation Flow

```
Swift Schema (ZyraTable/ZyraSchema)
    ↓
├─→ Prisma Schema
├─→ Drizzle Schema
├─→ Zod Schema
├─→ Swift Models
└─→ SQL Migrations
```

### PowerSync Integration

ZyraForm integrates seamlessly with PowerSync for offline-first applications:
- Automatic schema generation for PowerSync
- Encrypted field handling
- CRUD operations via `ZyraSync`
- Real-time synchronization

## Examples

See the example app in `ZyraForm/ZyraForm/` for:
- Complete schema definitions
- Form usage examples
- RLS policy examples
- CRUD operations

## Version

Current version: **1.2.0**

## License

[Add your license here]

## Contributing

[Add contribution guidelines here]

## Support

[Add support information here]
