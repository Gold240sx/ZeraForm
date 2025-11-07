# SchemaBasedSync Query Syntax Guide

Complete reference for querying records with `SchemaBasedSync`.

## Setup

```swift
let service = SchemaBasedSync(
    schema: todoTable,
    userId: userId,
    database: manager.database,
    watchForUpdates: true  // Enable real-time sync
)
```

## Query Methods

### 1. Get All Records

Get all records for the current user:

```swift
// Method 1: Using convenience method
let allTodos = try await service.getAll()

// Method 2: Using loadRecords (then access service.records)
try await service.loadRecords()
let allTodos = service.records
```

**Note:** By default, `loadRecords()` filters by `user_id` automatically.

### 2. Get One Record by ID

Get a single record by its ID:

```swift
let todoId = "some-uuid-here"
let todo = try await service.getOne(id: todoId)

if let todo = todo {
    let title = todo.get("title", as: String.self) ?? ""
    print("Found todo: \(title)")
} else {
    print("Todo not found")
}
```

### 3. Get All Where (Filtered)

Get all records matching a condition:

```swift
// Get all completed todos
let completedTodos = try await service.getAll(
    where: "is_completed = ?",
    parameters: ["true"]
)

// Get todos with specific title
let matchingTodos = try await service.getAll(
    where: "title LIKE ?",
    parameters: ["%important%"]
)

// Multiple conditions
let filteredTodos = try await service.getAll(
    where: "is_completed = ? AND user_id = ?",
    parameters: ["false", userId]
)

// With ordering
let recentTodos = try await service.getAll(
    where: "is_completed = ?",
    parameters: ["false"],
    orderBy: "created_at DESC"
)
```

### 4. Get First Where

Get the first record matching a condition:

```swift
// Get first incomplete todo
let firstIncomplete = try await service.getFirst(
    where: "is_completed = ?",
    parameters: ["false"]
)

if let todo = firstIncomplete {
    let title = todo.get("title", as: String.self) ?? ""
    print("First incomplete: \(title)")
}

// Get most recent todo
let mostRecent = try await service.getFirst(
    where: "user_id = ?",
    parameters: [userId],
    orderBy: "created_at DESC"
)

// Get oldest incomplete todo
let oldestIncomplete = try await service.getFirst(
    where: "is_completed = ?",
    parameters: ["false"],
    orderBy: "created_at ASC"
)
```

## Advanced: Using loadRecords Directly

For more control, use `loadRecords()` directly:

```swift
// Load with custom fields
try await service.loadRecords(
    fields: ["id", "title", "is_completed"],  // Only load these fields
    whereClause: "is_completed = ?",
    parameters: ["false"],
    orderBy: "created_at DESC"
)
let todos = service.records

// Load all fields (default)
try await service.loadRecords(
    whereClause: "user_id = ?",
    parameters: [userId]
)
let todos = service.records
```

## Real-Time Updates

When `watchForUpdates: true` is set, `service.records` automatically updates when data changes in Supabase:

```swift
// Observe for real-time updates
service.$records
    .sink { updatedRecords in
        // This fires automatically when Supabase data changes!
        print("Records updated: \(updatedRecords.count)")
    }
    .store(in: &cancellables)
```

## Complete Example

```swift
@MainActor
class TodoService: ObservableObject {
    private let service: SchemaBasedSync
    @Published var todos: [SchemaRecord] = []
    
    init(userId: String, database: PowerSync.PowerSyncDatabaseProtocol) {
        self.service = SchemaBasedSync(
            schema: todoTable,
            userId: userId,
            database: database,
            watchForUpdates: true
        )
        
        // Observe real-time updates
        service.$records
            .sink { [weak self] records in
                self?.todos = records
            }
            .store(in: &cancellables)
    }
    
    // Get all todos
    func loadAllTodos() async throws {
        try await service.loadRecords()
        todos = service.records
    }
    
    // Get completed todos
    func getCompletedTodos() async throws -> [SchemaRecord] {
        return try await service.getAll(
            where: "is_completed = ?",
            parameters: ["true"]
        )
    }
    
    // Get one todo by ID
    func getTodo(id: String) async throws -> SchemaRecord? {
        return try await service.getOne(id: id)
    }
    
    // Get first incomplete todo
    func getFirstIncomplete() async throws -> SchemaRecord? {
        return try await service.getFirst(
            where: "is_completed = ?",
            parameters: ["false"],
            orderBy: "created_at ASC"
        )
    }
}
```

## WHERE Clause Syntax

Use SQL WHERE clause syntax (without the "WHERE" keyword):

- **Equality**: `"is_completed = ?"`
- **Inequality**: `"is_completed != ?"`
- **LIKE**: `"title LIKE ?"` (use `%` for wildcards: `"%important%"`)
- **AND/OR**: `"is_completed = ? AND user_id = ?"`
- **IN**: `"id IN (?, ?)"`
- **Comparison**: `"created_at > ?"`, `"price < ?"`

Always use `?` placeholders and pass values in the `parameters` array for security.

## ORDER BY Syntax

- `"created_at DESC"` - Newest first
- `"created_at ASC"` - Oldest first
- `"title ASC"` - Alphabetical
- `"is_completed ASC, created_at DESC"` - Multiple columns

