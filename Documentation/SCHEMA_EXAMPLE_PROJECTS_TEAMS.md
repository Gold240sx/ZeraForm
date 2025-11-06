# Projects, Teams, and Organizations Schema Example

## Relationship Summary

### One-to-Many Relationships (No Join Tables)
- **User → Projects**: One user can own many projects
- **Organization → Projects**: One organization can own many projects  
- **Organization → Users**: One organization has many users
- **Organization → Teams**: One organization has many teams
- **Team → Organization**: One team belongs to one organization

### Many-to-Many Relationships (Join Tables Required)
- **Teams ↔ Projects**: Teams can access many projects, projects can be accessed by many teams
  - **Join Table**: `team_project_access` (created automatically)
  - **Additional Metadata**: `granted_at`, `granted_by`, `permission_level`
- **Users ↔ Organizations**: Users can belong to many companies, companies can have many users
  - **Join Table**: `user_organizations` (created automatically)
  - **Additional Metadata**: `joined_at`, `role`, `department`, `is_active`

### Special Case: Polymorphic Ownership
- **Projects** can belong to EITHER a User OR an Organization (but not both)
- Handled with two nullable foreign keys: `owner_user_id` and `owner_organization_id`
- Consider adding a database CHECK constraint to ensure only one is set

---

```swift
// MARK: - Core Tables

let Users = ZyraTable(
    name: "users",
    primaryKey: "id",
    columns: [
        zf.text("email").notNull().unique(),
        zf.text("name").notNull(),
        zf.text("organization_id")
            .references("organizations")  // One-to-many: User belongs to one org
            .nullable()  // Allow null if user isn't in an org yet
    ]
)

let Organizations = ZyraTable(
    name: "organizations",
    primaryKey: "id",
    columns: [
        zf.text("name").notNull(),
        zf.text("slug").notNull().unique()
    ]
)

let Teams = ZyraTable(
    name: "teams",
    primaryKey: "id",
    columns: [
        zf.text("name").notNull(),
        zf.text("organization_id")
            .references("organizations")  // One-to-many: Team belongs to one org
            .notNull(),
        zf.text("description").nullable()
    ]
)

// MARK: - Projects (Polymorphic Ownership + Team Access)

let Projects = ZyraTable(
    name: "projects",
    primaryKey: "id",
    columns: [
        zf.text("name").notNull(),
        zf.text("description").nullable(),
        
        // Polymorphic relationship: Can belong to EITHER user OR organization
        // Only one should be set at a time
        zf.text("owner_user_id")
            .references("users")  // One-to-many: User can have many projects
            .nullable(),
        zf.text("owner_organization_id")
            .references("organizations")  // One-to-many: Org can have many projects
            .nullable(),
        
        // Many-to-many: Teams can access many projects, projects can be accessed by many teams
        // This creates a join table automatically: team_project_access
        zf.text("team_id").belongsToMany(
            "teams",
            joinTableName: "team_project_access",  // Custom name for clarity
            additionalColumns: [
                zf.timestampz("granted_at").default(.now).notNull(),
                zf.text("granted_by").references("users").nullable(),  // Who granted access
                zf.text("permission_level").default("view").notNull()  // e.g., "view", "edit", "admin"
            ]
        )
        
        // Note: You might want to add a check constraint in SQL for the polymorphic relationship:
        // CHECK ((owner_user_id IS NOT NULL AND owner_organization_id IS NULL) 
        //     OR (owner_user_id IS NULL AND owner_organization_id IS NOT NULL))
    ]
)

// MARK: - Complete Schema

let schema = ZyraSchema(
    tables: [
        Organizations,
        Users,
        Teams,
        Projects
    ],
    dbPrefix: ""
)
```

---

## Generated Tables

When you create this schema, ZyraForm will generate:

1. **organizations** - Core table
2. **users** - Core table (with `organization_id` FK)
3. **teams** - Core table (with `organization_id` FK)
4. **projects** - Core table (with `owner_user_id` and `owner_organization_id` FKs)
5. **team_project_access** - **Join table** (created automatically by `.belongsToMany()`)
   - `id` (primary key)
   - `project_id` (FK to projects)
   - `team_id` (FK to teams)
   - `granted_at` (timestamp)
   - `granted_by` (FK to users, nullable)
   - `permission_level` (text)

## Query Examples

### Get all projects a team can access:
```sql
SELECT p.* 
FROM projects p
JOIN team_project_access tpa ON p.id = tpa.project_id
WHERE tpa.team_id = ?
```

### Get all teams that can access a project:
```sql
SELECT t.* 
FROM teams t
JOIN team_project_access tpa ON t.id = tpa.team_id
WHERE tpa.project_id = ?
```

### Get projects owned by a user:
```sql
SELECT * FROM projects WHERE owner_user_id = ?
```

### Get projects owned by an organization:
```sql
SELECT * FROM projects WHERE owner_organization_id = ?
```

---

## Example: Users Belonging to Multiple Companies

If you need **one person to belong to many companies** (many-to-many), here's how to model it:

```swift
let Users = ZyraTable(
    name: "users",
    primaryKey: "id",
    columns: [
        zf.text("email").notNull().unique(),
        zf.text("name").notNull(),
        
        // Optional: Primary organization (one-to-many)
        zf.text("primary_organization_id")
            .references("organizations")
            .nullable(),
        
        // Many-to-many: User can belong to many companies
        // This creates a join table automatically: user_organizations
        zf.text("organization_id").belongsToMany(
            "organizations",
            joinTableName: "user_organizations",  // Custom name
            additionalColumns: [
                zf.timestampz("joined_at").default(.now).notNull(),
                zf.text("role").default("member").notNull(),  // e.g., "admin", "member", "viewer"
                zf.text("department").nullable(),
                zf.text("is_active").bool().default(true).notNull()
            ]
        )
    ]
)

let Organizations = ZyraTable(
    name: "organizations",
    primaryKey: "id",
    columns: [
        zf.text("name").notNull(),
        zf.text("slug").notNull().unique()
    ]
)
```

### Generated Tables

This creates:
1. **users** - Core table (with optional `primary_organization_id`)
2. **organizations** - Core table
3. **user_organizations** - **Join table** (created automatically)
   - `id` (primary key)
   - `user_id` (FK to users)
   - `organization_id` (FK to organizations)
   - `joined_at` (timestamp)
   - `role` (text)
   - `department` (text, nullable)
   - `is_active` (boolean)

### Query Examples

**Get all companies a user belongs to:**
```sql
SELECT o.*, uo.role, uo.joined_at, uo.is_active
FROM organizations o
JOIN user_organizations uo ON o.id = uo.organization_id
WHERE uo.user_id = ? AND uo.is_active = true
```

**Get all users in a company:**
```sql
SELECT u.*, uo.role, uo.joined_at
FROM users u
JOIN user_organizations uo ON u.id = uo.user_id
WHERE uo.organization_id = ? AND uo.is_active = true
```

**Get users with a specific role in a company:**
```sql
SELECT u.*
FROM users u
JOIN user_organizations uo ON u.id = uo.user_id
WHERE uo.organization_id = ? 
  AND uo.role = 'admin'
  AND uo.is_active = true
```

### Design Patterns

**Pattern 1: Primary + Multiple Memberships**
- Use `primary_organization_id` for the main/default organization
- Use `belongsToMany()` for additional company memberships
- Useful when users have one "home" company but can work with others

**Pattern 2: Only Many-to-Many**
- Remove `primary_organization_id`
- Use only `belongsToMany()` for all memberships
- All companies are equal, no primary

**Pattern 3: With Status Tracking**
- Add `is_active`, `joined_at`, `left_at` columns to join table
- Track membership history and current status
- Useful for audit trails

