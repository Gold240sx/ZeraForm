# Field-Level Privacy Guide

## Overview

Field-level privacy allows you to mark individual columns as potentially private, so that even if a table is viewable by all signed-in users, specific fields can be hidden unless the user owns the record or explicitly shares them.

**Key Principle:**
- ✅ **Non-private fields are ALWAYS returned** - Fields not marked `.private()` are visible to everyone
- 🔒 **Private fields are conditionally returned** - Only visible to record owner OR if explicitly shared

This feature avoids the need for duplicate tables and keeps data in sync automatically.

## How It Works

1. **Mark columns as potentially private** using `.private()` modifier
2. **Store privacy settings per record** in a JSONB column (auto-generated)
3. **Generate PostgreSQL views** that filter private columns based on ownership
4. **Use the views** instead of direct table access for queries

## Example Schema

```swift
let Projects = ZyraTable(
    name: "projects",
    primaryKey: "id",
    columns: [
        zf.uuid("id").notNull(),
        zf.uuid("user_id").references(Users).notNull(),
        zf.text("name").notNull(),                    // Public
        zf.text("description").nullable(),            // Public
        zf.text("api_key").private().nullable(),     // Private - only owner sees this
        zf.text("secret_token").private().nullable(), // Private - only owner sees this
        zf.number("revenue").private().nullable(),    // Private - only owner sees this
        zf.timestampz("created_at").default(.now).notNull()
    ],
    rlsPolicies: [
        // Allow all authenticated users to read projects
        RLSPolicyBuilder(tableName: "projects")
            .canRead(),
        
        // But only owners can modify
        RLSPolicyBuilder(tableName: "projects")
            .canUpdateOwn(),
        RLSPolicyBuilder(tableName: "projects")
            .canDeleteOwn()
    ]
)
```

## Generated Schema

When you use `.private()` on columns, ZyraForm automatically:

1. **Adds a `_private_fields` JSONB column** to track which fields are actually private per record (for future use)
2. **Adds a `shared_fields` JSONB array column** for user-controlled field sharing
3. **Generates a view** `projects_public` that filters private columns based on ownership AND shared_fields

### Example Generated SQL

```sql
-- Add privacy metadata columns
ALTER TABLE "projects" ADD COLUMN "_private_fields" JSONB DEFAULT '{}'::jsonb;
ALTER TABLE "projects" ADD COLUMN IF NOT EXISTS "shared_fields" JSONB DEFAULT '[]'::jsonb;

-- Create view that filters private columns
CREATE OR REPLACE VIEW "projects_public" AS
SELECT 
    id,
    user_id,
    name,
    description,
    created_at,
    -- Private fields only shown if user owns the record OR field is in shared_fields
    CASE 
        WHEN user_id::uuid = (auth.uid())::uuid 
             OR "shared_fields" @> '["api_key"]'::jsonb
        THEN api_key 
        ELSE NULL 
    END AS api_key,
    CASE 
        WHEN user_id::uuid = (auth.uid())::uuid 
             OR "shared_fields" @> '["revenue"]'::jsonb
        THEN revenue 
        ELSE NULL 
    END AS revenue
FROM "projects";

-- Grant access to the view
GRANT SELECT ON "projects_public" TO authenticated;
```

## Usage Patterns

### Pattern 1: All Fields Private by Default

```swift
let Projects = ZyraTable(
    name: "projects",
    primaryKey: "id",
    columns: [
        zf.uuid("id").notNull(),
        zf.uuid("user_id").references(Users).notNull(),
        zf.text("name").notNull(),
        zf.text("description").private().nullable(),  // Private by default
        zf.text("api_key").private().nullable()
    ]
)
```

### Pattern 2: Selective Privacy

```swift
let Projects = ZyraTable(
    name: "projects",
    primaryKey: "id",
    columns: [
        zf.uuid("id").notNull(),
        zf.uuid("user_id").references(Users).notNull(),
        zf.text("name").notNull(),                    // Always public
        zf.text("description").nullable(),            // Always public
        zf.text("api_key").private().nullable(),      // Private
        zf.text("secret_token").private().nullable()  // Private
    ]
)
```

### Pattern 3: User-Controlled Field Sharing

Users can control which private fields are shared per record using the `shared_fields` JSONB array:

```swift
let Projects = ZyraTable(
    name: "projects",
    primaryKey: "id",
    columns: [
        zf.uuid("id").notNull(),
        zf.uuid("user_id").references(Users).notNull(),
        zf.text("name").notNull(),                    // Always public
        zf.text("description").nullable(),            // Always public
        zf.text("api_key").private().nullable(),      // Private by default
        zf.number("revenue").private().nullable()     // Private by default
    ]
)
```

**User can share specific fields:**
```sql
-- User shares api_key but keeps revenue private
UPDATE projects 
SET shared_fields = '["api_key"]'::jsonb
WHERE id = '...';

-- User shares both fields
UPDATE projects 
SET shared_fields = '["api_key", "revenue"]'::jsonb
WHERE id = '...';

-- User shares nothing (default)
UPDATE projects 
SET shared_fields = '[]'::jsonb
WHERE id = '...';
```

**How it works:**
- Private fields marked with `.private()` are hidden by default
- Fields are visible if:
  1. User owns the record (`user_id = auth.uid()`), OR
  2. Field name is in the `shared_fields` JSONB array
- Users can add/remove fields from `shared_fields` to control sharing per record

## Querying Private Fields

### Using the Generated View

**Important:** When querying the `{table}_public` view:

- ✅ **Non-private fields are ALWAYS returned** - regardless of who queries the record
- ✅ **Private fields are conditionally returned** - only if user owns the record OR field is in `shared_fields`

```sql
-- Query the view instead of the table
SELECT * FROM projects_public WHERE user_id = '...';

-- Public fields (name, description) are ALWAYS visible to everyone
-- Private fields (api_key, revenue) are NULL unless:
--   - User owns the record, OR
--   - Field is in shared_fields array
```

### Security: Is This Safe?

**Yes, this is secure and by design:**

1. **Non-private fields are intentionally public** - If you don't mark a field with `.private()`, it's meant to be visible to everyone. This is the expected behavior.

2. **Private fields are protected** - Fields marked `.private()` are only shown when:
   - User owns the record (`user_id = auth.uid()`), OR
   - Field is explicitly shared (`shared_fields` contains the field name)

3. **Database-level enforcement** - The view enforces privacy at the database level, so even if your application code has bugs, private fields remain protected.

4. **Default is private** - Private fields default to hidden. Users must explicitly add them to `shared_fields` to share them.

**Example Query Results:**

```sql
-- User A queries their own project
SELECT * FROM projects_public WHERE id = 'project-123' AND user_id = auth.uid();
-- Result: ALL fields shown (name, description, api_key, revenue, ssn)

-- User B queries User A's project (nothing shared)
SELECT * FROM projects_public WHERE id = 'project-123';
-- Result: Only public fields shown (name, description)
--         Private fields are NULL (api_key=NULL, revenue=NULL, ssn=NULL)

-- User B queries User A's project (api_key shared, uses light encryption)
-- After: UPDATE projects SET shared_fields = '["api_key"]'::jsonb WHERE id = 'project-123';
SELECT * FROM projects_public WHERE id = 'project-123';
-- Result: Public fields + shared private field (name, description, api_key)
--         Non-shared private field is NULL (revenue=NULL)
--         Per-user encrypted field is NULL (ssn=NULL) - NEVER shared even if in shared_fields
--         Note: api_key is encrypted but uses shared key, so User B can decrypt it
```

### Encrypted Fields Special Handling

**Important:** Encrypted fields have two modes:

#### 1. Per-User Encryption (Deep Encryption) - `.encrypted()`

- Uses user-specific keys derived from user ID
- Only the record owner can decrypt
- **NEVER shared** - even if added to `shared_fields`
- Best for highly sensitive data that should never be shared

#### 2. Shared/Master Key Encryption (Light Encryption) - `.encryptedLight()`

- Uses a single master key (shared across all users)
- Anyone with access (via RLS/privacy) can decrypt
- **CAN be shared** via `shared_fields` like non-encrypted fields
- RLS and privacy controls determine access - encryption is just for at-rest protection
- Best when RLS/privacy handle access control and encryption is secondary

**Example:**
```swift
let Projects = ZyraTable(
    name: "projects",
    columns: [
        zf.text("name").notNull(),                                    // Public
        zf.text("api_key").private().encryptedLight().nullable(),     // Private + Light encryption - CAN be shared
        zf.text("ssn").private().encrypted().nullable()               // Private + Per-user encryption - NEVER shared
    ]
)
```

**Generated View Logic:**
```sql
-- api_key (private + light encryption): Can be shared
CASE 
    WHEN user_id::uuid = (auth.uid())::uuid 
         OR "shared_fields" @> '["api_key"]'::jsonb
    THEN api_key 
    ELSE NULL 
END AS api_key

-- ssn (private + per-user encryption): ONLY owner can see
CASE 
    WHEN user_id::uuid = (auth.uid())::uuid 
    THEN ssn 
    ELSE NULL 
END AS ssn
-- Note: shared_fields check is NOT included for per-user encrypted fields
```

### When to Use Each Encryption Mode

**Use `.encrypted()` (Per-User) when:**
- Data should NEVER be shared (SSN, passwords, credit cards)
- Each user must have their own encryption key
- Maximum security is required

**Use `.encryptedLight()` (Shared) when:**
- RLS and privacy controls handle access
- Encryption is for at-rest protection only
- Data might need to be shared via `shared_fields`
- You want simpler encryption/decryption (no user-specific keys)

### Application-Level Filtering

```swift
// In your Swift application
func getProject(id: UUID, userId: UUID) -> Project? {
    // Query the view instead of the table
    let query = """
        SELECT * FROM projects_public 
        WHERE id = $1
    """
    
    // Private fields are automatically filtered by the view
    return execute(query, [id])
}
```

## Benefits

1. **No Duplicate Tables** - Everything stays in one table
2. **Automatic Sync** - No need to keep tables in sync
3. **Flexible** - Users can control privacy per record
4. **Secure** - Database-level filtering via views
5. **Performance** - Views are efficient, no application-level filtering needed

## Implementation Details

### Privacy Logic

### How Fields Are Returned

**Public Fields (Not Marked `.private()`):**
- ✅ **ALWAYS returned** - regardless of who queries the record
- These fields are meant to be public and visible to everyone
- **Note:** Public encrypted fields are returned, but can only be decrypted by the record owner (encryption uses per-user keys)

**Private Fields (Marked `.private()`):**

**Non-Encrypted Private Fields:**
- ✅ **Returned if user owns the record** (`user_id = auth.uid()`)
- ✅ **Returned if field is in `shared_fields` array** (`shared_fields @> '["field_name"]'::jsonb`)
- ❌ **Returns NULL otherwise** - hidden from other users

**Encrypted Private Fields:**

**Per-User Encryption (`.encrypted()`):**
- ✅ **ONLY returned if user owns the record** (`user_id = auth.uid()`)
- ❌ **NEVER returned even if in `shared_fields`** - uses per-user keys, so:
  - Only the owner can decrypt them
  - Exposing encrypted hashes to other users is a security risk
  - Other users cannot decrypt them anyway (different encryption key)

**Shared Encryption (`.encryptedLight()`):**
- ✅ **Returned if user owns the record** (`user_id = auth.uid()`)
- ✅ **Returned if field is in `shared_fields` array** (`shared_fields @> '["field_name"]'::jsonb`)
- ❌ **Returns NULL otherwise** - hidden from other users
- Uses master key - anyone with access can decrypt (RLS/privacy control access)

### Security Considerations

**Is it a security risk to always return non-private fields?**

**No, this is by design and secure:**

1. **Public fields are intentionally public** - Fields not marked `.private()` are meant to be visible to everyone. This is the expected behavior.

2. **Private fields are protected** - Fields marked `.private()` are only shown to:
   - The record owner (always)
   - Other users only if explicitly shared via `shared_fields` (non-encrypted fields only)

3. **Encrypted fields have special protection** - Encrypted private fields are **NEVER** shared, even if added to `shared_fields`, because:
   - They're encrypted with the owner's user-specific key
   - Other users cannot decrypt them (different key derivation)
   - Exposing encrypted hashes is a security risk
   - Only the record owner can decrypt and see the plaintext

4. **Database-level enforcement** - The view enforces this at the database level, so even if application code has bugs, private fields remain protected.

5. **Explicit opt-in sharing** - Users must explicitly add fields to `shared_fields` to share them. Default is private.

**Example:**
```swift
// Public fields - always visible
zf.text("name").notNull()           // ✅ Always returned
zf.text("description").nullable()   // ✅ Always returned

// Private non-encrypted fields - conditionally visible  
zf.text("api_key").private()        // ❌ Hidden unless owner OR shared
zf.number("revenue").private()      // ❌ Hidden unless owner OR shared

// Private encrypted fields - per-user (deep encryption)
zf.text("ssn").private().encrypted()            // 🔒 ONLY owner can see (never shared)

// Private encrypted fields - shared (light encryption)
zf.text("api_key").private().encryptedLight()  // ✅ Can be shared via shared_fields
zf.text("token").private().encryptedLight()    // ✅ Can be shared via shared_fields
```

### How Private Fields Are Shown

Private fields are visible in the `{table}_public` view if **EITHER**:

1. **User owns the record**: `user_id = auth.uid()`
2. **Field is in shared_fields**: `shared_fields @> '["field_name"]'::jsonb`

### Example Scenarios

**Scenario 1: User owns the record**
```sql
-- User sees all fields (including private ones)
SELECT * FROM projects_public WHERE user_id = auth.uid();
-- Result: All fields shown, including api_key and revenue
```

**Scenario 2: User doesn't own, but field is shared**
```sql
-- Project owner shared api_key
UPDATE projects SET shared_fields = '["api_key"]'::jsonb WHERE id = '...';

-- Other users see api_key but not revenue
SELECT * FROM projects_public WHERE id = '...';
-- Result: api_key shown, revenue is NULL
```

**Scenario 3: User doesn't own, nothing shared**
```sql
-- Project owner shares nothing
UPDATE projects SET shared_fields = '[]'::jsonb WHERE id = '...';

-- Other users see only public fields
SELECT * FROM projects_public WHERE id = '...';
-- Result: Only name, description shown; api_key and revenue are NULL
```

## Migration Path

If you already have a table and want to add privacy:

1. Add `.private()` to columns in your schema
2. Regenerate migration SQL
3. Run migration to add `_private_fields` column
4. Create the view
5. Update your queries to use the view

## Limitations

1. **PostgreSQL Only** - Views with `auth.uid()` require PostgreSQL/Supabase
2. **View Updates** - Updates must go through the base table, not the view
3. **Complex Queries** - Some complex queries may need to reference the base table

## Best Practices

1. **Use views for SELECT queries** - Always query the `_public` view for reads
2. **Use base table for writes** - INSERT/UPDATE/DELETE on the base table
3. **Index private fields** - If you query private fields, add indexes
4. **Document privacy** - Make it clear which fields are private in your API docs

