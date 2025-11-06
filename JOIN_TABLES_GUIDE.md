# Join Tables Guide

## Understanding When Join Tables Are Necessary

Join tables (also called pivot tables or junction tables) are needed for **many-to-many relationships**. Understanding the difference between relationship types is key:

### Relationship Types

#### 1. **One-to-Many** (No Join Table Needed)
One record in Table A relates to many records in Table B, but each record in Table B belongs to only one record in Table A.

**Example:** Posts and Comments
- One post can have many comments
- Each comment belongs to only one post

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
        zf.text("post_id")
            .references("posts")  // Regular foreign key - NO join table
            .notNull(),
        zf.text("content").notNull()
    ]
)
```

**Result:** The `comments` table has a `post_id` column that references `posts.id`. No join table is created.

---

#### 2. **Many-to-Many** (Join Table Required)
Many records in Table A relate to many records in Table B, and vice versa.

**Example:** Posts and Tags
- One post can have many tags
- One tag can be on many posts

```swift
let Posts = ZyraTable(
    name: "posts",
    primaryKey: "id",
    columns: [
        zf.text("title").notNull(),
        zf.text("content").notNull(),
        // This creates a join table automatically
        zf.text("tag_id").belongsToMany("tags")
    ]
)

let Tags = ZyraTable(
    name: "tags",
    primaryKey: "id",
    columns: [
        zf.text("name").unique().notNull()
    ]
)
```

**Result:** ZyraForm automatically creates a `posts_tags` join table with:
- `id` (primary key)
- `post_id` (foreign key to posts)
- `tag_id` (foreign key to tags)

---

## How ZyraForm Creates Join Tables

### Automatic Join Table Generation

When you use `.belongsToMany()`, ZyraForm:

1. **Detects the relationship** during schema initialization
2. **Creates a join table** with a generated name (or custom name if provided)
3. **Adds foreign keys** to both tables
4. **Removes the marker column** from the original table (it's just a marker, not an actual column)

### Join Table Naming

**Default naming:** Table names are sorted alphabetically and combined:
- `posts` + `tags` → `posts_tags`
- `users` + `roles` → `roles_users` (alphabetically sorted)

**Custom naming:**
```swift
zf.text("tag_id").belongsToMany("tags", joinTableName: "post_tag_assignments")
```

### Join Table Structure

The automatically generated join table includes:

```swift
// Generated join table structure
ZyraTable(
    name: "posts_tags",  // or custom name
    primaryKey: "id",
    columns: [
        zf.text("post_id")
            .references("posts")
            .notNull(),
        zf.text("tag_id")
            .references("tags")
            .notNull()
        // Plus any additional columns you specify
    ]
)
```

### Adding Extra Columns to Join Tables

You can add additional columns to store metadata about the relationship:

```swift
let Posts = ZyraTable(
    name: "posts",
    primaryKey: "id",
    columns: [
        zf.text("title").notNull(),
        zf.text("tag_id").belongsToMany(
            "tags",
            additionalColumns: [
                zf.timestamp("assigned_at").default("NOW()").notNull(),
                zf.text("assigned_by").references("users").nullable()
            ]
        )
    ]
)
```

This creates a join table with:
- `id` (primary key)
- `post_id` (foreign key)
- `tag_id` (foreign key)
- `assigned_at` (timestamp)
- `assigned_by` (foreign key to users)

---

## Decision Tree: Do You Need a Join Table?

Ask yourself these questions:

### ❓ Question 1: Can one record in Table A relate to multiple records in Table B?
- **No** → Use a regular foreign key (one-to-many)
- **Yes** → Continue to Question 2

### ❓ Question 2: Can one record in Table B relate to multiple records in Table A?
- **No** → Use a regular foreign key (one-to-many, but reversed)
- **Yes** → **You need a join table!** (many-to-many)

### Examples

**Posts ↔ Comments**
- One post → many comments? ✅ Yes
- One comment → many posts? ❌ No
- **Result:** One-to-many, use `.references()`

**Posts ↔ Tags**
- One post → many tags? ✅ Yes
- One tag → many posts? ✅ Yes
- **Result:** Many-to-many, use `.belongsToMany()`

**Students ↔ Courses**
- One student → many courses? ✅ Yes
- One course → many students? ✅ Yes
- **Result:** Many-to-many, use `.belongsToMany()`

**Authors ↔ Books**
- One author → many books? ✅ Yes
- One book → many authors? ✅ Yes (co-authors)
- **Result:** Many-to-many, use `.belongsToMany()`

**Users ↔ Orders**
- One user → many orders? ✅ Yes
- One order → many users? ❌ No (one order belongs to one user)
- **Result:** One-to-many, use `.references()`

---

## Common Patterns

### Pattern 1: Simple Many-to-Many

```swift
let Posts = ZyraTable(
    name: "posts",
    primaryKey: "id",
    columns: [
        zf.text("title").notNull(),
        zf.text("tag_id").belongsToMany("tags")
    ]
)

let Tags = ZyraTable(
    name: "tags",
    primaryKey: "id",
    columns: [
        zf.text("name").unique().notNull()
    ]
)
```

### Pattern 2: Many-to-Many with Metadata

```swift
let Students = ZyraTable(
    name: "students",
    primaryKey: "id",
    columns: [
        zf.text("name").notNull(),
        zf.text("course_id").belongsToMany(
            "courses",
            additionalColumns: [
                zf.timestamp("enrolled_at").default("NOW()").notNull(),
                zf.text("grade").nullable(),
                zf.integer("semester").notNull()
            ]
        )
    ]
)
```

### Pattern 3: Custom Join Table Name

```swift
let Users = ZyraTable(
    name: "users",
    primaryKey: "id",
    columns: [
        zf.text("email").notNull(),
        zf.text("role_id").belongsToMany(
            "roles",
            joinTableName: "user_role_assignments"  // Custom name
        )
    ]
)
```

### Pattern 4: Custom Foreign Key Actions

```swift
let Posts = ZyraTable(
    name: "posts",
    primaryKey: "id",
    columns: [
        zf.text("title").notNull(),
        zf.text("tag_id").belongsToMany(
            "tags",
            referenceRemoved: .cascade,      // Delete join record if post deleted
            otherReferenceRemoved: .cascade, // Delete join record if tag deleted
            referenceUpdated: .cascade,
            otherReferenceUpdated: .cascade
        )
    ]
)
```

---

## How Join Tables Appear in Generated Code

### SQL Migration

```sql
-- Join table is created automatically
CREATE TABLE "posts_tags" (
    id TEXT PRIMARY KEY,
    post_id TEXT NOT NULL,
    tag_id TEXT NOT NULL,
    FOREIGN KEY (post_id) REFERENCES "posts"(id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES "tags"(id) ON DELETE CASCADE ON UPDATE CASCADE
);
```

### Prisma Schema

```prisma
model Post {
  id    String @id
  title String
  tags  PostTag[]
}

model Tag {
  id    String @id
  name  String @unique
  posts PostTag[]
}

model PostTag {
  id     String @id
  postId String
  tagId  String
  post   Post   @relation(fields: [postId], references: [id])
  tag    Tag    @relation(fields: [tagId], references: [id])
}
```

### PowerSync Bucket Definitions

```yaml
buckets:
  - parameters:
      tables:
        - posts
        - tags
        - JOIN-posts_tags  # Join tables get "JOIN-" prefix
```

---

## Important Notes

1. **The marker column is removed:** When you use `.belongsToMany()`, that column doesn't actually appear in the final table. It's just a marker to tell ZyraForm to create a join table.

2. **Join tables are created automatically:** You don't need to manually define the join table. ZyraForm creates it during schema initialization.

3. **Join tables get "JOIN-" prefix in PowerSync:** For PowerSync bucket definitions, join tables are prefixed with "JOIN-" to distinguish them from regular tables.

4. **Both directions work:** You only need to define `.belongsToMany()` on one side of the relationship. ZyraForm handles both directions automatically.

5. **Table names are sorted:** Join table names are generated by sorting the two table names alphabetically, so `posts_tags` not `tags_posts`.

---

## Troubleshooting

### Issue: "Referenced table not found"
**Cause:** The table name in `.belongsToMany()` doesn't match any table in your schema.
**Solution:** Make sure the table name matches exactly (case-sensitive).

### Issue: Join table not appearing
**Cause:** The schema wasn't initialized properly, or the marker column wasn't processed.
**Solution:** Ensure you're creating a `ZyraSchema` with all your tables, and the `.belongsToMany()` is called on a column builder.

### Issue: Want to query the join table directly
**Solution:** Join tables are regular tables - you can query them like any other table. They're included in `schema.getAllTables()`.

---

## Summary

- **Use `.references()`** for one-to-many relationships (no join table)
- **Use `.belongsToMany()`** for many-to-many relationships (creates join table automatically)
- **Join tables are created automatically** - you don't define them manually
- **Join table names** are auto-generated (alphabetically sorted) or can be custom
- **Additional columns** can be added to join tables for relationship metadata

