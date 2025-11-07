# Building a Minimal Todo App with ZyraForm

This guide walks you through building the simplest possible todo app using ZyraForm with full CRUD functionality.

## Prerequisites

- Xcode 15+
- Swift 5.9+
- ZyraForm framework (add via SPM or include in your project)
- Supabase account (for backend sync) - Optional but recommended
- PowerSync account (for offline sync) - Optional but recommended

## Step 1: Project Setup

1. Create a new SwiftUI app in Xcode
2. Add ZyraForm dependencies:
   - `ZyraForm` (core framework)
   - `ZyraFormSupabase` (for Supabase integration)
   - `PowerSync` (for offline sync)

## Step 2: Define Your Schema

Create a new file `TodoSchema.swift`:

```swift
import ZyraForm

// Define the todo table schema
let todoTable = ZyraTable(
    name: "todos",  // Table name (no prefix needed for simple apps)
    primaryKey: "id",
    columns: [
        zf.text("title").minLength(1).maxLength(200).notNull(),
        zf.text("description").nullable(),
        zf.text("is_completed").default("false").notNull(), // Boolean as text
        zf.text("user_id").notNull() // For multi-user support
    ],
    rlsPolicies: [
        // Users can only access their own todos
        RLSPolicyBuilder(tableName: "todos")
            .canAccessOwn()
    ]
)

// Create the schema
let todoSchema = ZyraSchema(
    tables: [todoTable],
    dbPrefix: "" // No prefix for simple apps
)
```

## Step 3: Initialize ZyraForm

Create `AppConfig.swift`:

```swift
import Foundation
import ZyraForm
import ZyraFormSupabase

struct AppConfig {
    // Supabase Configuration
    static let supabaseURL = URL(string: "https://your-project.supabase.co")!
    static let supabaseKey = "your-supabase-anon-key"
    
    // PowerSync Configuration (optional - for offline sync)
    static let powerSyncEndpoint = "https://your-id.powersync.journeyapps.com"
    static let powerSyncPassword = "your-powersync-password"
    
    // User ID (in a real app, get this from authentication)
    static let userId = "current-user-id"
    
    // Create ZyraForm configuration
    static func createConfig() -> ZyraFormConfig {
        let connector = SupabaseConnector(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey,
            powerSyncEndpoint: powerSyncEndpoint,
            powerSyncPassword: powerSyncPassword
        )
        
        return ZyraFormConfig(
            connector: connector,
            powerSyncPassword: powerSyncPassword,
            dbPrefix: "",
            userId: userId,
            schema: todoSchema
        )
    }
}
```

In your `App.swift` or main view, initialize ZyraForm:

```swift
import SwiftUI
import ZyraForm

@main
struct TodoApp: App {
    @State private var isInitialized = false
    
    var body: some Scene {
        WindowGroup {
            if isInitialized {
                TodoListView()
            } else {
                ProgressView("Initializing...")
                    .task {
                        await initializeZyraForm()
                    }
            }
        }
    }
    
    func initializeZyraForm() async {
        do {
            let config = AppConfig.createConfig()
            try await ZyraFormManager.initialize(with: config)
            isInitialized = true
        } catch {
            print("Failed to initialize ZyraForm: \(error)")
        }
    }
}
```

## Step 4: Use Your Schema (No Model Generation Needed!)

**Best Option: Use SchemaRecord directly** - No code generation, no copy/paste, just use your schema!

### Option 1: Use SchemaRecord (Recommended - Zero Boilerplate!)

Skip model generation entirely! Use `SchemaRecord` which works directly with your schema:

```swift
import Foundation
import ZyraForm

// That's it! No Todo struct needed - SchemaRecord works with todoTable directly
```

Then in your service, use `SchemaBasedSync`:

```swift
@MainActor
class TodoService: ObservableObject {
    private let service: SchemaBasedSync
    let userId: String
    
    @Published var todos: [SchemaRecord] = []
    @Published var isLoading = false
    
    init(userId: String) {
        self.userId = userId
        
        guard let manager = ZyraFormManager.shared else {
            fatalError("ZyraFormManager not initialized")
        }
        
        // Use SchemaBasedSync - works directly with todoTable schema!
        self.service = SchemaBasedSync(
            schema: todoTable,
            userId: userId,
            database: manager.database
        )
    }
    
    func loadTodos() async {
        isLoading = true
        do {
            try await service.loadRecords(
                whereClause: "user_id = ?",
                parameters: [userId]
            )
            todos = service.records
            isLoading = false
        } catch {
            print("Failed to load todos: \(error)")
            isLoading = false
        }
    }
    
    func createTodo(title: String, description: String = "") async throws {
        // Create record directly from schema - clean syntax!
        let record = todoTable.createEmptyRecord()
            .setting([
                "title": title,
                "description": description,
                "is_completed": "false",
                "user_id": userId
            ])
        
        _ = try await service.createRecord(record)
        await loadTodos()
    }
    
    // Access fields with type safety
    func getTodoTitle(_ todo: SchemaRecord) -> String {
        return todo.get("title", as: String.self) ?? ""
    }
    
    func getTodoCompleted(_ todo: SchemaRecord) -> Bool {
        return todo.get("is_completed", as: Bool.self) ?? false
    }
}
```

**Benefits:**
- ✅ **Zero code generation** - use schema directly
- ✅ **Type-safe access** - `get("field", as: Type.self)`
- ✅ **No copy/paste** - everything inferred from schema
- ✅ **Runtime flexibility** - works with any schema

### Option 2: Generate Model Code (If You Want Strong Typing)

If you prefer compile-time type safety with generated structs:

```swift
// Generate the model code
let todoModelCode = todoTable.generateSwiftModel(
    modelName: "Todo",
    schemaVariableName: "todoTable"
)

// Print and copy into Todo.swift
print(todoModelCode)
```

Then use `TypedZyraSync<Todo>` as shown in Step 5.

### Generated Model Example (Option 2 Only)

If you choose Option 2, the generated `Todo.swift` will look like this:

```swift
// MARK: - Todo

import Foundation
import ZyraForm

struct Todo: ZyraModel {
    // Reference to the schema - provides automatic validation and type safety
    static let schema = todoTable
    
    let id: String
    let title: String
    let description: String?
    let isCompleted: Bool
    let userId: String
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case isCompleted = "is_completed"
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Initialize from database record dictionary
    init(from record: [String: Any]) throws {
        self.id = record["id"] as? String ?? UUID().uuidString
        self.title = record["title"] as? String ?? ""
        self.description = record["description"] as? String
        self.isCompleted = {
            if let completed = record["is_completed"] as? String {
                return completed.lowercased() == "true" || completed == "1"
            } else if let completed = record["is_completed"] as? Bool {
                return completed
            } else if let completed = record["is_completed"] as? Int {
                return completed != 0
            }
            return false
        }()
        self.userId = record["user_id"] as? String ?? ""
        self.createdAt = {
            if let dateValue = record["created_at"] as? Date {
                return dateValue
            } else if let strValue = record["created_at"] as? String {
                return ISO8601DateFormatter().date(from: strValue)
            }
            return nil
        }()
        self.updatedAt = {
            if let dateValue = record["updated_at"] as? Date {
                return dateValue
            } else if let strValue = record["updated_at"] as? String {
                return ISO8601DateFormatter().date(from: strValue)
            }
            return nil
        }()
    }
    
    // Convert to dictionary for saving
    func toDictionary(excluding columns: [String] = []) -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "title": title,
            "description": description,
            "is_completed": isCompleted ? "true" : "false",
            "user_id": userId,
            "created_at": createdAt != nil ? ISO8601DateFormatter().string(from: createdAt!) : nil,
            "updated_at": updatedAt != nil ? ISO8601DateFormatter().string(from: updatedAt!) : nil
        ]
        
        // Remove excluded columns
        for column in columns {
            dict.removeValue(forKey: column)
        }
        
        return dict
    }
}
```

**Key Benefits:**
- ✅ **Zero duplication**: Everything generated from schema
- ✅ **Schema-driven**: Model automatically uses `todoTable` schema for validation
- ✅ **Type-safe**: Compile-time type checking
- ✅ **Automatic**: No manual typing - just generate and use!

## Step 5: Create the Todo Service

Choose your approach based on Step 4:

### Option A: Using SchemaRecord (No Model Generation)

If you chose Option 1 in Step 4, your service is already done! See the example in Step 4.

### Option B: Using Generated Model (TypedZyraSync)

If you chose Option 2 in Step 4, create `TodoService.swift` using the typed `TypedZyraSync` service:

```swift
import Foundation
import ZyraForm

@MainActor
class TodoService: ObservableObject {
    private let service: TypedZyraSync<Todo>
    let userId: String
    
    @Published var todos: [Todo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init(userId: String) {
        self.userId = userId
        
        guard let manager = ZyraFormManager.shared else {
            fatalError("ZyraFormManager not initialized")
        }
        
        // TypedZyraSync automatically uses Todo.schema for configuration
        self.service = TypedZyraSync<Todo>(
            userId: userId,
            database: manager.database
        )
    }
    
    // Load all todos for the current user - returns typed [Todo]
    func loadTodos() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Typed service automatically handles field configuration from schema
            try await service.loadRecords(
                whereClause: "user_id = ?",
                parameters: [userId]
            )
            
            // Records are already typed as [Todo]
            todos = service.records
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            print("Failed to load todos: \(error)")
        }
    }
    
    // Create a new todo - type-safe!
    func createTodo(title: String, description: String = "") async throws {
        // Create Todo instance
        let todo = try Todo(from: [
            "id": UUID().uuidString,
            "title": title,
            "description": description,
            "is_completed": false,
            "user_id": userId
        ])
        
        // Create record - service handles encryption/config automatically
        _ = try await service.createRecord(todo)
        
        // Reload todos to get the new one
        await loadTodos()
    }
    
    // Update an existing todo - type-safe!
    func updateTodo(_ todo: Todo) async throws {
        // Service automatically handles encryption and timestamps from schema
        try await service.updateRecord(todo)
        
        // Reload todos to reflect changes
        await loadTodos()
    }
    
    // Toggle completion status
    func toggleTodo(_ todo: Todo) async throws {
        var updatedTodo = todo
        updatedTodo.isCompleted.toggle()
        try await updateTodo(updatedTodo)
    }
    
    // Delete a todo
    func deleteTodo(_ todo: Todo) async throws {
        try await service.deleteRecord(todo)
        await loadTodos()
    }
}
```

**Key Benefits:**
- ✅ **Type-safe**: Returns `[Todo]` instead of `[[String: Any]]`
- ✅ **Automatic config**: Uses `Todo.schema` for encryption fields, types, etc.
- ✅ **Cleaner code**: No manual field configuration needed
- ✅ **Compile-time safety**: Type errors caught at compile time

## Step 6: Create the Todo List View

Create `TodoListView.swift`:

```swift
import SwiftUI

struct TodoListView: View {
    @StateObject private var todoService: TodoService
    @State private var showingAddTodo = false
    @State private var newTodoTitle = ""
    @State private var newTodoDescription = ""
    
    init(userId: String) {
        _todoService = StateObject(wrappedValue: TodoService(userId: userId))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if todoService.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if todoService.todos.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "checklist")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No todos yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Tap + to add your first todo")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(todoService.todos) { todo in
                            TodoRowView(todo: todo, todoService: todoService)
                        }
                        .onDelete { indexSet in
                            Task {
                                for index in indexSet {
                                    await deleteTodo(todoService.todos[index])
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Todos")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddTodo = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTodo) {
                AddTodoView(todoService: todoService)
            }
            .task {
                await todoService.loadTodos()
            }
            .refreshable {
                await todoService.loadTodos()
            }
        }
    }
    
    private func deleteTodo(_ todo: Todo) async {
        do {
            try await todoService.deleteTodo(todo)
        } catch {
            print("Failed to delete todo: \(error)")
        }
    }
}
```

## Step 7: Create the Todo Row View

Create `TodoRowView.swift`:

```swift
import SwiftUI

struct TodoRowView: View {
    let todo: Todo
    @ObservedObject var todoService: TodoService
    
    var body: some View {
        HStack {
            Button(action: {
                Task {
                    do {
                        try await todoService.toggleTodo(todo)
                    } catch {
                        print("Failed to toggle todo: \(error)")
                    }
                }
            }) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(todo.isCompleted ? .green : .gray)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(todo.title)
                    .strikethrough(todo.isCompleted)
                    .foregroundColor(todo.isCompleted ? .secondary : .primary)
                
                if !todo.description.isEmpty {
                    Text(todo.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .strikethrough(todo.isCompleted)
                }
            }
            
            Spacer()
        }
        .contentShape(Rectangle())
    }
}
```

## Step 8: Create the Add Todo View

Create `AddTodoView.swift`:

```swift
import SwiftUI

struct AddTodoView: View {
    @ObservedObject var todoService: TodoService
    @Environment(\.dismiss) var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Todo Details")) {
                    TextField("Title", text: $title)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Todo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveTodo()
                        }
                    }
                    .disabled(title.isEmpty || isSaving)
                }
            }
        }
    }
    
    private func saveTodo() async {
        guard !title.isEmpty else { return }
        
        isSaving = true
        do {
            try await todoService.createTodo(title: title, description: description)
            dismiss()
        } catch {
            print("Failed to create todo: \(error)")
            isSaving = false
        }
    }
}
```

## Step 9: Update Your App Entry Point

Update your main app file to use the TodoListView:

```swift
import SwiftUI
import ZyraForm

@main
struct TodoApp: App {
    @State private var isInitialized = false
    
    var body: some Scene {
        WindowGroup {
            if isInitialized {
                TodoListView(userId: AppConfig.userId)
            } else {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Initializing ZyraForm...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task {
                    await initializeZyraForm()
                }
            }
        }
    }
    
    func initializeZyraForm() async {
        do {
            let config = AppConfig.createConfig()
            try await ZyraFormManager.initialize(with: config)
            isInitialized = true
        } catch {
            print("Failed to initialize ZyraForm: \(error)")
        }
    }
}
```

## Step 10: Set Up Supabase (Optional but Recommended)

1. Create a new Supabase project
2. Run this SQL in the Supabase SQL Editor to create the todos table:

```sql
-- Create todos table
CREATE TABLE todos (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    title TEXT NOT NULL,
    description TEXT,
    is_completed TEXT NOT NULL DEFAULT 'false',
    user_id TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE todos ENABLE ROW LEVEL SECURITY;

-- Create RLS policy: Users can only access their own todos
CREATE POLICY "todos_own_access"
ON todos
FOR ALL
USING (user_id = auth.uid()::text)
WITH CHECK (user_id = auth.uid()::text);
```

3. Update your `AppConfig.swift` with your Supabase credentials

## Step 11: Test Your App

1. Build and run the app
2. Tap the + button to add a todo
3. Tap the circle to toggle completion
4. Swipe to delete todos
5. Pull down to refresh

## Key Concepts Explained

### ZyraModel Protocol
- `ZyraModel` provides schema-driven type safety
- Models reference their schema via `static let schema: ZyraTable`
- Validation rules come automatically from schema (no rewriting!)
- Runtime schema access: `Todo.schema`, `Todo.requiredFields`, etc.

### TypedZyraSync Service
- `TypedZyraSync<Model: ZyraModel>` provides type-safe CRUD operations
- Returns `[Model]` instead of `[[String: Any]]`
- Automatically uses model's schema for field configuration
- Handles encryption, validation, and sync automatically
- Works offline with PowerSync integration

### CRUD Operations (Typed)
- **Create**: `service.createRecord(_ model: Model)` - takes typed model
- **Read**: `service.loadRecords(...)` - returns `[Model]`
- **Update**: `service.updateRecord(_ model: Model)` - takes typed model
- **Delete**: `service.deleteRecord(_ model: Model)` - takes typed model

### Schema Definition
- Use `ZyraTable` to define tables (single source of truth)
- Use `zf.text()`, `zf.integer()`, etc. for column types
- Add validations with `.minLength()`, `.maxLength()`, `.notNull()`, etc.
- Define RLS policies with `RLSPolicyBuilder`
- Schema provides validation, types, and structure - define once, use everywhere!

### Offline Support
- PowerSync automatically syncs data when online
- Works completely offline - changes queue and sync when connection returns
- No additional code needed!

## Troubleshooting

### "ZyraFormManager not initialized"
- Make sure you call `ZyraFormManager.initialize()` before using services
- Check that initialization completes successfully

### "Table not found"
- Verify your schema includes the table definition
- Check that the table name matches exactly (case-sensitive)

### "RLS policy violation"
- Ensure your RLS policies match your user_id structure
- Check that `user_id` is set correctly when creating records

## Next Steps

- Add categories/tags to todos
- Add due dates and reminders
- Add search and filtering
- Add user authentication
- Add sharing/collaboration features

## Complete File Structure

```
TodoApp/
├── App.swift
├── AppConfig.swift
├── TodoSchema.swift
├── Todo.swift
├── TodoService.swift
├── TodoListView.swift
├── TodoRowView.swift
└── AddTodoView.swift
```

That's it! You now have a fully functional todo app with offline sync, encryption support, and automatic backend synchronization. 🎉

