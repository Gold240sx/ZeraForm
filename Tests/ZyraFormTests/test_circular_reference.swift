import Foundation
import ZyraForm

// Mock AppConfig for testing
struct AppConfig {
    static let dbPrefix = "test_"
}

let ProjectCollabEnum = ZyraEnum(
    name: "\(AppConfig.dbPrefix)project_collaboration_status",
    values: [
        "independent",
        "team",
        "open_source",
        "seeking_contributors",
        "seeking_maintainers",
        "archived",
        "private"
    ]
)

let ProjectStatusEnum = ZyraEnum(
    name: "\(AppConfig.dbPrefix)project_status",
    values: [
        "active",
        "archived",
        "deleted"
    ]
)

let ProjectPermissionLevelEnum = ZyraEnum(
    name: "\(AppConfig.dbPrefix)project_permission_level",
    values: [
        "read",
        "write",
        "admin"
    ]
)

let UserTypes = ZyraTable(
    name: "\(AppConfig.dbPrefix)user_types",
    primaryKey: "id",
    columns: [
        zf.text("name").minLength(2).notNull(),
        zf.text("description").nullable(),
    ]
)

let Organizations = ZyraTable(
    name: "\(AppConfig.dbPrefix)organizations",
    primaryKey: "id",
    columns: [
        zf.text("name").minLength(2).notNull(),
        zf.uuid("creator_user_id").notNull().references("\(AppConfig.dbPrefix)user_public")
    ]
)

let Users = ZyraTable(
    name: "\(AppConfig.dbPrefix)user_public",
    primaryKey: "id",
    columns: [
        zf.uuid("user_id").notNull(),
        zf.text("username").minLength(2).notNull(),
        zf.text("display_name").minLength(2).notNull(),
        zf.url("avatar_url").nullable(),
        zf.text("bio").nullable(),
        zf.email("email").notNull(),
        zf.text("github_username").nullable(),
        zf.url("website_url").nullable(),
        zf.uuid("user_type_id").nullable().references(UserTypes),
        zf.text("location").nullable().minLength(2),
        zf.text("password").encrypted().minLength(8).notNull(),
        zf.text("primary_organization_id").references("\(AppConfig.dbPrefix)organizations").nullable(),
        zf.uuid("organization_id").belongsToMany(
            "\(AppConfig.dbPrefix)organizations",
            joinTableName: "user_organizations",
            additionalColumns: [
                zf.timestampz("joined_at").default(.now).notNull(),
                zf.text("title").nullable().default("employee"),
                zf.text("department").nullable(),
            ]
        )
    ]
)

let Teams = ZyraTable(
    name: "\(AppConfig.dbPrefix)teams",
    primaryKey: "id",
    columns: [
        zf.text("name").minLength(2).notNull(),
        zf.uuid("org_id").notNull().references(Organizations),
    ]
)

let Projects = ZyraTable(
    name: "\(AppConfig.dbPrefix)projects",
    primaryKey: "id",
    columns: [
        zf.text("name").encrypted().minLength(2).notNull(),
        zf.uuid("owner_id").nullable().references(Users),
        zf.uuid("org_id").nullable().references(Organizations),
        zf.uuid("creator_id").notNull().references(Users),
        zf.text("description").encrypted().nullable(),
        zf.url("repo_url").encrypted().nullable(),
        zf.url("live_url").encrypted().nullable(),
        zf.url("icon_url").encrypted().nullable(),
        zf.url("hosting_url").encrypted().nullable(),
        zf.url("design_url").encrypted().nullable(),
        zf.text("collaboration_status").enum(ProjectCollabEnum).notNull().default("independent"),
        zf.text("project_path").nullable(),
        zf.text("team_id").belongsToMany(
            "\(AppConfig.dbPrefix)teams",
            joinTableName: "team_projects",
            additionalColumns: [
                zf.timestampz("granted_at").default(.now).notNull(),
                zf.text("granted_by").references(Users).nullable(),
                zf.text("permission_level").enum(ProjectPermissionLevelEnum).notNull().default("view")
            ]
        ),
        zf.text("status").enum(ProjectStatusEnum).notNull().default("active"),
    ]
)

let schema = ZyraSchema(
    tables: [
        UserTypes,
        Organizations,
        Users,
        Teams,
        Projects
    ],
    enums: [
        ProjectCollabEnum,
        ProjectStatusEnum,
        ProjectPermissionLevelEnum
    ],
    dbPrefix: AppConfig.dbPrefix
)

// Test PostgreSQL SQL generation
print("=== PostgreSQL SQL ===")
let pgSQL = schema.generateMigrationSQL()
print(pgSQL)
print("\n")

// Test Drizzle schema generation
print("=== Drizzle Schema ===")
let drizzleSchema = schema.generateDrizzleSchema(dbPrefix: AppConfig.dbPrefix)
print(drizzleSchema)
print("\n")

// Test MySQL SQL generation
print("=== MySQL SQL ===")
let mysqlSQL = schema.generateMySQLMigrationSQL()
print(mysqlSQL)

