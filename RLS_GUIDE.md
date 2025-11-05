# Row Level Security (RLS) Guide for ZyraForm

## Overview

Row Level Security (RLS) is a PostgreSQL feature that allows fine-grained access control at the row level. With ZyraForm, you can easily define RLS policies for your tables using a fluent, type-safe API.

RLS ensures that users can only access rows they're authorized to see, modify, or delete based on policies you define. This is especially useful for multi-tenant applications and applications where users should only access their own data.

## Quick Start

```swift
import ZyraForm

let userTable = ZyraTable(
    name: "users",
    columns: [
        zf.text("email").email().notNull(),
        zf.text("name").notNull()
    ],
    rlsPolicies: [
        RLSPolicyBuilder(tableName: "users").canAccessOwn()
    ]
)
```

When you generate migration SQL, RLS will be automatically enabled and policies will be created:

```sql
ALTER TABLE "users" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_own_access" 
ON "users" AS PERMISSIVE FOR ALL 
USING (user_id::uuid = (auth.uid())::uuid) 
WITH CHECK (user_id::uuid = (auth.uid())::uuid);
```

**Note:** All `auth.uid()` comparisons use UUID casting: `(auth.uid())::uuid`. If your `user_id` columns are TEXT type, they're automatically cast: `user_id::uuid = (auth.uid())::uuid`.

## RLS Policy Types

### RLSOperation

Defines which database operations the policy applies to:

- `.select` - SELECT queries
- `.insert` - INSERT operations
- `.update` - UPDATE operations
- `.delete` - DELETE operations
- `.all` - All operations (SELECT, INSERT, UPDATE, DELETE)

### RLSPolicyType

Defines how policies are combined:

- `.permissive` - Multiple policies can be combined with OR (default)
- `.restrictive` - Multiple policies are combined with AND (more restrictive)

## Common RLS Patterns

### 1. Users Can Only Access Their Own Rows

**Use Case:** Personal data, user-specific content

```swift
let personalTable = ZyraTable(
    name: "personal_notes",
    columns: [
        zf.text("content").notNull()
    ],
    rlsPolicies: [
        RLSPolicyBuilder(tableName: "personal_notes", userIdColumn: "user_id")
            .canAccessOwn()
    ]
)
```

**Generated SQL:**
```sql
CREATE POLICY "personal_notes_own_access" 
ON "personal_notes" AS PERMISSIVE FOR ALL 
USING (user_id::uuid = (auth.uid())::uuid) 
WITH CHECK (user_id::uuid = (auth.uid())::uuid);
```

### 2. Users Can Access All Rows

**Use Case:** Public data, read-only tables

```swift
let publicTable = ZyraTable(
    name: "public_posts",
    columns: [
        zf.text("content").notNull()
    ],
    rlsPolicies: [
        RLSPolicyBuilder(tableName: "public_posts").canAccessAll()
    ]
)
```

**Generated SQL:**
```sql
CREATE POLICY "public_posts_all_access" PERMISSIVE ON "public_posts" 
FOR ALL 
USING (true);
```

### 3. Read All, Modify Own

**Use Case:** Social media posts, comments, shared documents

```swift
let postsTable = ZyraTable(
    name: "posts",
    columns: [
        zf.text("title").notNull(),
        zf.text("content").notNull()
    ],
    rlsPolicies: RLSPolicyBuilder(tableName: "posts", userIdColumn: "author_id")
        .canReadAllModifyOwnSeparate()
)
```

**Generated SQL:**
```sql
CREATE POLICY "posts_read_all" 
ON "posts" AS PERMISSIVE FOR SELECT 
USING (true);

CREATE POLICY "posts_modify_own" 
ON "posts" AS PERMISSIVE FOR UPDATE 
USING (author_id::uuid = (auth.uid())::uuid) 
WITH CHECK (author_id::uuid = (auth.uid())::uuid);

CREATE POLICY "posts_delete_own" 
ON "posts" AS PERMISSIVE FOR DELETE 
USING (author_id::uuid = (auth.uid())::uuid);

CREATE POLICY "posts_insert_own" 
ON "posts" AS PERMISSIVE FOR INSERT 
USING (true) 
WITH CHECK (author_id::uuid = (auth.uid())::uuid);
```

## Custom RLS Policies

### Using Custom SQL Expressions

For complex access control logic:

```swift
let teamTable = ZyraTable(
    name: "team_documents",
    columns: [
        zf.text("content").notNull(),
        zf.text("team_id").notNull()
    ],
    rlsPolicies: [
        RLSPolicyBuilder(tableName: "team_documents").custom(
            name: "team_member_access",
            operation: .all,
            usingExpression: """
                team_id IN (
                    SELECT team_id FROM user_teams 
                    WHERE user_id = auth.uid()::text
                )
            """,
            withCheckExpression: """
                team_id IN (
                    SELECT team_id FROM user_teams 
                    WHERE user_id = auth.uid()::text
                )
            """
        )
    ]
)
```

### Using Supabase auth.uid()

For Supabase integration with UUID casting:

```swift
let secureTable = ZyraTable(
    name: "secrets",
    columns: [
        zf.text("data").encrypted().notNull(),
        zf.text("owner_id").notNull()
    ],
    rlsPolicies: [
        // Using auth.uid() with UUID casting (default)
        RLSPolicyBuilder(tableName: "secrets").usingAuthUid(
            operation: .all,
            column: "owner_id",
            function: "(auth.uid())::uuid"  // Default function
        ),
        
        // With role bypass
        RLSPolicyBuilder(tableName: "secrets").usingAuthUid(
            operation: .all,
            column: "owner_id",
            allowRoles: ["admin", "moderator"]
        )
    ]
)
```

**Note:** The default function is `(auth.uid())::uuid`, and columns are automatically cast to UUID: `owner_id::uuid = (auth.uid())::uuid`.

### Using Custom Functions

For application-specific authentication:

```swift
let customAuthTable = ZyraTable(
    name: "private_data",
    columns: [
        zf.text("data").notNull()
    ],
    rlsPolicies: [
        RLSPolicyBuilder(tableName: "private_data").usingFunction(
            name: "app_user_access",
            operation: .all,
            functionCall: "is_user_authorized(current_setting('app.user_id'))",
            withCheckFunction: "is_user_authorized(current_setting('app.user_id'))"
        )
    ]
)
```

## Advanced RLS Patterns

### Multi-Column Access Control

```swift
let sharedTable = ZyraTable(
    name: "shared_resources",
    columns: [
        zf.text("name").notNull(),
        zf.text("owner_id").notNull(),
        zf.text("shared_with_id").nullable()
    ],
    rlsPolicies: [
        // Owners can access their own resources
        RLSPolicyBuilder(tableName: "shared_resources").custom(
            name: "owner_access",
            operation: .all,
            usingExpression: "owner_id::uuid = (auth.uid())::uuid"
        ),
        // Users can access resources shared with them
        RLSPolicyBuilder(tableName: "shared_resources").custom(
            name: "shared_access",
            operation: .select,
            usingExpression: "shared_with_id::uuid = (auth.uid())::uuid"
        )
    ]
)
```

### Role-Based Access Control (RBAC)

ZyraForm uses [Supabase RBAC](https://supabase.com/features/role-based-access-control) for role-based permissions. Roles are stored in a `role` column (default) in your users table:

```swift
let adminTable = ZyraTable(
    name: "admin_settings",
    columns: [
        zf.text("setting").notNull(),
        zf.text("value").notNull()
    ],
    rlsPolicies: [
        // Simple admin check
        table.rls().admin(operation: .all),
        
        // Or use hasRole for specific roles
        table.rls().hasRole("admin", operation: .all),
        
        // Multiple roles
        table.rls().hasRole(["admin", "super_admin"], operation: .all),
        
        // Custom role check
        RLSPolicyBuilder(tableName: "admin_settings", roleColumn: "role").custom(
            name: "admin_only",
            operation: .all,
            usingExpression: """
                EXISTS (
                    SELECT 1 FROM public.users 
                    WHERE id = (auth.uid())::uuid 
                    AND role = 'admin'
                )
            """
        )
    ]
)
```

**Built-in RBAC Methods:**
- `admin()` - Users with "admin" role
- `editor()` - Users with "admin" or "editor" role
- `hasRole(_ roles:)` - Check for specific role(s)
- `canAccessOwn(allowRoles:)` - Own access + role bypass
- `canRead(allowRoles:)` - Read access + roles
- `canUpdateOwn(allowRoles:)` - Update own + roles

### Time-Based Access

```swift
let timeRestrictedTable = ZyraTable(
    name: "temporary_access",
    columns: [
        zf.text("content").notNull(),
        zf.text("expires_at").notNull()
    ],
    rlsPolicies: [
        RLSPolicyBuilder(tableName: "temporary_access").custom(
            name: "valid_time_window",
            operation: .select,
            usingExpression: "expires_at > NOW()"
        )
    ]
)
```

## Policy Operations

### Separate Policies for Different Operations

Sometimes you need different rules for SELECT vs INSERT vs UPDATE:

```swift
let granularTable = ZyraTable(
    name: "documents",
    columns: [
        zf.text("content").notNull(),
        zf.text("status").notNull()
    ],
    rlsPolicies: [
        // Anyone can read published documents
        RLSPolicyBuilder(tableName: "documents").custom(
            name: "read_published",
            operation: .select,
            usingExpression: "status = 'published'"
        ),
        // Only owners can modify
        RLSPolicyBuilder(tableName: "documents").custom(
            name: "modify_own",
            operation: .update,
            usingExpression: "user_id::uuid = (auth.uid())::uuid",
            withCheckExpression: "user_id::uuid = (auth.uid())::uuid"
        ),
        // Only owners can delete
        RLSPolicyBuilder(tableName: "documents").custom(
            name: "delete_own",
            operation: .delete,
            usingExpression: "user_id::uuid = (auth.uid())::uuid"
        ),
        // Anyone authenticated can create
        RLSPolicyBuilder(tableName: "documents").custom(
            name: "insert_authenticated",
            operation: .insert,
            usingExpression: "true",
            withCheckExpression: "auth.uid() IS NOT NULL"
        )
    ]
)
```

## Restrictive Policies

Restrictive policies combine with AND (all must pass):

```swift
let strictTable = ZyraTable(
    name: "high_security",
    columns: [
        zf.text("data").encrypted().notNull()
    ],
    rlsPolicies: [
        RLSPolicy(
            name: "strict_access",
            operation: .all,
            policyType: .restrictive,  // Use restrictive
            usingExpression: "user_id::uuid = (auth.uid())::uuid",
            withCheckExpression: "user_id::uuid = (auth.uid())::uuid"
        ),
        // If you add another restrictive policy, BOTH must pass
        RLSPolicy(
            name: "verified_user",
            operation: .all,
            policyType: .restrictive,
            usingExpression: """
                EXISTS (
                    SELECT 1 FROM public.users 
                    WHERE id = (auth.uid())::uuid 
                    AND verified = true
                )
            """
        )
    ]
)
```

## Best Practices

### 1. Always Include User ID Column

For user-specific access, ensure your table has a user identifier column:

```swift
let table = ZyraTable(
    name: "user_data",
    columns: [
        zf.text("user_id").notNull(),  // Required for canAccessOwn()
        zf.text("data").notNull()
    ],
    rlsPolicies: [
        RLSPolicyBuilder(tableName: "user_data", userIdColumn: "user_id")
            .canAccessOwn()
    ]
)
```

### 2. Use Separate Policies for Different Operations

Instead of one complex policy, use separate policies for clarity:

```swift
// ✅ Good: Separate policies
rlsPolicies: RLSPolicyBuilder(tableName: "posts")
    .canReadAllModifyOwnSeparate()

// ❌ Avoid: Single complex policy trying to handle everything
```

### 3. Test Your Policies

Always test RLS policies with different user contexts:

```sql
-- Test as user 1
SET LOCAL request.jwt.claim.sub = 'user-1-id';
SELECT * FROM your_table;

-- Test as user 2
SET LOCAL request.jwt.claim.sub = 'user-2-id';
SELECT * FROM your_table;
```

### 4. Use WITH CHECK for INSERT/UPDATE

Always include `WITH CHECK` for INSERT and UPDATE operations to prevent users from inserting/updating rows they shouldn't:

```swift
RLSPolicyBuilder(tableName: "posts").custom(
    name: "insert_own",
    operation: .insert,
    usingExpression: "true",
    withCheckExpression: "author_id::uuid = (auth.uid())::uuid"  // ✅ Prevents setting wrong author_id
)
```

### 5. Consider Performance

RLS policies are evaluated for every query. Keep them simple and ensure indexed columns:

```swift
// ✅ Good: Uses indexed column with UUID casting
"user_id::uuid = (auth.uid())::uuid"

// ⚠️ Can be slow: Complex subquery
"id IN (SELECT ... FROM ... WHERE ...)"
```

## Integration with Migration SQL

RLS policies are automatically included when generating migration SQL:

```swift
let schema = ZyraSchema(tables: [userTable, postsTable])

// Generate migration SQL (includes RLS)
let migrationSQL = schema.generateMigrationSQL()

// Or generate RLS SQL separately
let rlsSQL = userTable.generateRLSSQL()
```

The generated SQL will include:
1. `ALTER TABLE ... ENABLE ROW LEVEL SECURITY`
2. `CREATE POLICY` statements for each policy

## RLS in Code Generation

When generating Zera schema code (Swift code that recreates your schema), RLS policies are preserved and intelligently converted back to builder calls:

```swift
// Your original schema
let table = ZyraTable(
    name: "posts",
    rlsPolicies: [
        table.rls().canAccessOwn(),
        table.rls().admin(operation: .delete)
    ]
)

// Generated Zera code includes:
rlsPolicies: [
    RLSPolicyBuilder(tableName: "posts").canAccessOwn(),
    RLSPolicyBuilder(tableName: "posts").admin(operation: .delete),
]
```

The generator detects common patterns:
- `.canAccessOwn()` - Matches `user_id::uuid = (auth.uid())::uuid` patterns
- `.canAccessAll()` - Matches `true` expressions
- `.authenticated()` - Matches `auth.uid() IS NOT NULL`
- `.anonymous()` - Matches `auth.uid() IS NULL`
- `.admin()` - Matches admin role checks
- `.custom()` - For complex SQL expressions

This ensures your RLS policies are preserved when exporting and sharing schemas.

## API Reference

### RLSPolicyBuilder Methods

| Method | Description | Returns |
|--------|-------------|---------|
| `canAccessOwn(allowRoles:)` | Users can only access their own rows (with optional role bypass) | `RLSPolicy` |
| `canAccessAll()` | Users can access all rows | `RLSPolicy` |
| `canReadAllModifyOwnSeparate(allowRoles:)` | Read all, modify own (separate policies with optional role bypass) | `[RLSPolicy]` |
| `canRead(allowRoles:)` | Read access for authenticated users (with optional role bypass) | `RLSPolicy` |
| `canWriteOwn(operation:allowRoles:)` | Write own records (with optional role bypass) | `RLSPolicy` |
| `canUpdateOwn(allowRoles:)` | Update own records (with optional role bypass) | `RLSPolicy` |
| `canDeleteOwn(allowRoles:)` | Delete own records (with optional role bypass) | `RLSPolicy` |
| `authenticated(operation:)` | Only authenticated users | `RLSPolicy` |
| `anonymous(operation:)` | Only anonymous users | `RLSPolicy` |
| `hasRole(_ roles:operation:)` | Users with specific role(s) | `RLSPolicy` |
| `admin(operation:)` | Users with admin role | `RLSPolicy` |
| `editor(operation:)` | Users with admin or editor role | `RLSPolicy` |
| `online(operation:)` | Only online users | `RLSPolicy` |
| `userOrPermission(name:operation:permission:permissionColumn:)` | User OR has permission | `RLSPolicy` |
| `custom(name:operation:usingExpression:withCheckExpression:)` | Custom policy with SQL | `RLSPolicy` |
| `usingAuthUid(operation:column:function:allowRoles:)` | Policy using Supabase auth.uid() (with optional role bypass) | `RLSPolicy` |
| `usingFunction(name:operation:functionCall:withCheckFunction:)` | Policy using custom function | `RLSPolicy` |

### ZyraTable RLS Methods

| Method/Property | Description | Returns |
|-----------------|-------------|---------|
| `rlsPolicies` | Array of RLS policies | `[RLSPolicy]` |
| `hasRLS` | Check if RLS is enabled | `Bool` |
| `rls(userIdColumn:usersTableName:roleColumn:isOnlineColumn:)` | Get RLS policy builder | `RLSPolicyBuilder` |
| `generateRLSSQL()` | Generate RLS SQL | `String` |

**RLS Builder Parameters:**
- `userIdColumn`: Column name for user ID (default: `"user_id"`)
- `usersTableName`: Name of users table (default: `"users"`)
- `roleColumn`: Column name for role in users table (default: `"role"`) - Used for RBAC
- `isOnlineColumn`: Column name for online status (default: `"is_online"`)

### RLSPolicy Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | Policy name |
| `operation` | `RLSOperation` | Operation type (SELECT, INSERT, etc.) |
| `policyType` | `RLSPolicyType` | PERMISSIVE or RESTRICTIVE |
| `usingExpression` | `String` | SQL expression for USING clause |
| `withCheckExpression` | `String?` | SQL expression for WITH CHECK clause |

## Common Patterns Summary

| Pattern | Method | Use Case |
|---------|--------|----------|
| User-specific data | `canAccessOwn()` | Personal notes, settings |
| Public read-only | `canAccessAll()` | Public posts, announcements |
| Social content | `canReadAllModifyOwnSeparate()` | Posts, comments, likes |
| Team data | `custom()` with team check | Team documents, channels |
| Admin only | `custom()` with role check | Admin settings, logs |
| Time-based | `custom()` with date check | Temporary access, expiring content |

## Troubleshooting

### RLS Not Working?

1. **Check if RLS is enabled:**
   ```sql
   SELECT tablename, rowsecurity FROM pg_tables WHERE tablename = 'your_table';
   ```

2. **Verify policies exist:**
   ```sql
   SELECT * FROM pg_policies WHERE tablename = 'your_table';
   ```

3. **Check user context:**
   ```sql
   SELECT auth.uid();
   ```

4. **Test policy directly:**
   ```sql
   SELECT * FROM your_table WHERE user_id::uuid = (auth.uid())::uuid;
   ```

### Common Issues

- **"No policies found"** - Ensure policies are created after table creation
- **"Permission denied"** - Check that USING expression allows access
- **"Insert blocked"** - Verify WITH CHECK expression is correct
- **"Slow queries"** - Optimize USING expressions and add indexes

## Examples

See the [Examples](./examples) directory for complete working examples:
- Basic user authentication
- Multi-tenant applications
- Role-based access control
- Team collaboration
- Time-based access control

