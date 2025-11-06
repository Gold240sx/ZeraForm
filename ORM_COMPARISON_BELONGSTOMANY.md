# Many-to-Many Relationship Syntax Comparison

Yes! The `belongsToMany()` syntax is used by several popular ORMs. Here's how different frameworks handle many-to-many relationships:

## ZyraForm (Swift)

```swift
let Projects = ZyraTable(
    name: "projects",
    columns: [
        zf.text("name").notNull(),
        zf.text("team_id").belongsToMany(
            "teams",
            joinTableName: "team_projects",
            additionalColumns: [
                zf.timestamp("granted_at").default(.now).notNull(),
                zf.text("granted_by").references(Users).nullable(),
                zf.text("permission_level").enum(ProjectPermissionLevelEnum).notNull().default("view")
            ]
        )
    ]
)
```

**Features:**
- Auto-creates join table
- Can specify custom join table name
- Can add additional columns to join table
- Column is removed from original table (it's just a marker)

---

## Laravel Eloquent (PHP)

```php
class Project extends Model
{
    public function teams()
    {
        return $this->belongsToMany(Team::class, 'team_projects')
                    ->withPivot('granted_at', 'granted_by', 'permission_level')
                    ->withTimestamps();
    }
}

class Team extends Model
{
    public function projects()
    {
        return $this->belongsToMany(Project::class, 'team_projects')
                    ->withPivot('granted_at', 'granted_by', 'permission_level');
    }
}
```

**Similarities:**
- ✅ Uses `belongsToMany()` method name
- ✅ Can specify custom join table name
- ✅ Can add additional columns via `withPivot()`

**Differences:**
- Requires defining the relationship on both models
- Join table must exist in database (not auto-created)
- Uses `withPivot()` for additional columns

---

## Sequelize (JavaScript/Node.js)

```javascript
const Project = sequelize.define('Project', {
    name: DataTypes.STRING
});

const Team = sequelize.define('Team', {
    name: DataTypes.STRING
});

// Define many-to-many relationship
Project.belongsToMany(Team, {
    through: 'team_projects',
    foreignKey: 'project_id',
    otherKey: 'team_id'
});

Team.belongsToMany(Project, {
    through: 'team_projects',
    foreignKey: 'team_id',
    otherKey: 'project_id'
});

// With additional columns
const TeamProject = sequelize.define('team_projects', {
    granted_at: DataTypes.DATE,
    granted_by: DataTypes.UUID,
    permission_level: DataTypes.STRING
});

Project.belongsToMany(Team, { through: TeamProject });
Team.belongsToMany(Project, { through: TeamProject });
```

**Similarities:**
- ✅ Uses `belongsToMany()` method name
- ✅ Can specify custom join table via `through`
- ✅ Can add additional columns by defining the join table model

**Differences:**
- Requires defining on both models
- Join table model must be explicitly defined for additional columns

---

## Prisma (TypeScript)

```prisma
model Project {
  id        String   @id
  name      String
  teams     TeamProject[]
}

model Team {
  id        String   @id
  name      String
  projects  TeamProject[]
}

model TeamProject {
  id              String   @id
  projectId       String
  teamId          String
  grantedAt       DateTime @default(now())
  grantedBy       String?
  permissionLevel String   @default("view")
  
  project         Project  @relation(fields: [projectId], references: [id])
  team            Team     @relation(fields: [teamId], references: [id])
}
```

**Differences:**
- ❌ No `belongsToMany()` syntax
- Uses explicit join table model definition
- More verbose but more explicit

---

## Django (Python)

```python
from django.db import models

class Project(models.Model):
    name = models.CharField(max_length=255)
    teams = models.ManyToManyField(
        'Team',
        through='TeamProject',
        related_name='projects'
    )

class Team(models.Model):
    name = models.CharField(max_length=255)

class TeamProject(models.Model):
    project = models.ForeignKey(Project, on_delete=models.CASCADE)
    team = models.ForeignKey(Team, on_delete=models.CASCADE)
    granted_at = models.DateTimeField(auto_now_add=True)
    granted_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True)
    permission_level = models.CharField(max_length=50, default='view')
```

**Differences:**
- Uses `ManyToManyField` instead of `belongsToMany()`
- Requires explicit join table model for additional columns
- More explicit about the join table structure

---

## Rails/ActiveRecord (Ruby)

```ruby
class Project < ApplicationRecord
  has_many :team_projects
  has_many :teams, through: :team_projects
end

class Team < ApplicationRecord
  has_many :team_projects
  has_many :projects, through: :team_projects
end

class TeamProject < ApplicationRecord
  belongs_to :project
  belongs_to :team
  belongs_to :granted_by, class_name: 'User', optional: true
  
  # Additional columns
  # granted_at, permission_level defined in migration
end
```

**Differences:**
- Uses `has_many :through` pattern
- Requires explicit join table model
- More verbose but very explicit

---

## Drizzle ORM (TypeScript)

```typescript
import { pgTable, uuid, timestamp, text } from 'drizzle-orm/pg-core';
import { relations } from 'drizzle-orm';

export const projects = pgTable('projects', {
  id: uuid('id').primaryKey(),
  name: text('name').notNull(),
});

export const teams = pgTable('teams', {
  id: uuid('id').primaryKey(),
  name: text('name').notNull(),
});

export const teamProjects = pgTable('team_projects', {
  id: uuid('id').primaryKey(),
  projectId: uuid('project_id').references(() => projects.id),
  teamId: uuid('team_id').references(() => teams.id),
  grantedAt: timestamp('granted_at').defaultNow(),
  grantedBy: uuid('granted_by').references(() => users.id),
  permissionLevel: text('permission_level').default('view'),
});

// Relations
export const projectsRelations = relations(projects, ({ many }) => ({
  teams: many(teamProjects),
}));

export const teamsRelations = relations(teams, ({ many }) => ({
  projects: many(teamProjects),
}));
```

**Differences:**
- ❌ No `belongsToMany()` syntax
- Requires explicit join table definition
- Relations defined separately

---

## SQL (Raw)

```sql
-- No ORM syntax - you manually create everything

CREATE TABLE projects (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL
);

CREATE TABLE teams (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL
);

CREATE TABLE team_projects (
    id UUID PRIMARY KEY,
    project_id UUID REFERENCES projects(id),
    team_id UUID REFERENCES teams(id),
    granted_at TIMESTAMPTZ DEFAULT NOW(),
    granted_by UUID REFERENCES users(id),
    permission_level TEXT DEFAULT 'view',
    UNIQUE(project_id, team_id)
);
```

**Differences:**
- ❌ No ORM syntax at all
- Everything is manual
- Most verbose but most control

---

## Summary

| ORM | Syntax | Auto-creates Join Table | Additional Columns |
|-----|--------|------------------------|-------------------|
| **ZyraForm** | `belongsToMany()` | ✅ Yes | ✅ Via `additionalColumns` |
| **Laravel** | `belongsToMany()` | ❌ No | ✅ Via `withPivot()` |
| **Sequelize** | `belongsToMany()` | ❌ No | ✅ Via join table model |
| **Prisma** | Explicit model | ❌ No | ✅ Via join table model |
| **Django** | `ManyToManyField` | ✅ Basic | ✅ Via explicit model |
| **Rails** | `has_many :through` | ❌ No | ✅ Via join table model |
| **Drizzle** | Explicit table | ❌ No | ✅ Via explicit table |
| **SQL** | N/A | ❌ No | ✅ Manual |

---

## Key Takeaway

**Yes, `belongsToMany()` is a common pattern!** It's used by:
- ✅ **Laravel Eloquent** (PHP)
- ✅ **Sequelize** (JavaScript)
- ✅ **CakePHP** (PHP)
- ✅ **Quick ORM** (ColdFusion)

**ZyraForm's approach is unique because:**
1. It **auto-creates** the join table (most ORMs require you to create it manually)
2. The marker column is **removed** from the original table (it's just a hint)
3. Additional columns can be specified **inline** without defining a separate model

This makes ZyraForm's `belongsToMany()` more declarative and less verbose than most ORMs!

