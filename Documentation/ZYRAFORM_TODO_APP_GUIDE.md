# Building a Minimal Todo App with ZyraForm

This guide walks you through building the simplest possible todo app using ZyraForm with full CRUD functionality and real-time sync.

**Updated for ZyraForm v2.0.7+** - Uses `SchemaRecord` and `SchemaBasedSync` for zero-boilerplate, schema-first development.

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
    private var cancellables = Set<AnyCancellable>()
    
    @Published var todos: [SchemaRecord] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init(userId: String) {
        self.userId = userId
        
        guard let manager = ZyraFormManager.shared else {
            fatalError("ZyraFormManager not initialized")
        }
        
        // Use SchemaBasedSync - works directly with todoTable schema!
        // watchForUpdates: true enables real-time PowerSync sync from Supabase
        self.service = SchemaBasedSync(
            schema: todoTable,
            userId: userId,
            database: manager.database,
            watchForUpdates: true  // Enable real-time sync!
        )
        
        // Observe service.records for real-time updates
        // When PowerSync detects changes in Supabase, service.records updates automatically
        service.$records
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedRecords in
                self?.todos = updatedRecords
            }
            .store(in: &cancellables)
    }
    
    func loadTodos() async {
        isLoading = true
        do {
            // This sets up the PowerSync watch query
            // After this, any changes in Supabase will automatically update todos via the Combine publisher
            try await service.loadRecords(
                whereClause: "user_id = ?",
                parameters: [userId]
            )
            // Initial load - subsequent updates come via Combine publisher
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
        // No need to reload - real-time sync will update automatically!
    }
    
    func updateTodo(_ todo: SchemaRecord) async throws {
        try await service.updateRecord(todo)
        // No need to reload - real-time sync will update automatically!
    }
    
    func toggleTodo(_ todo: SchemaRecord) async throws {
        let currentCompleted = todo.get("is_completed", as: Bool.self) ?? false
        let updatedTodo = todo.setting("is_completed", to: !currentCompleted ? "true" : "false")
        try await updateTodo(updatedTodo)
    }
    
    func deleteTodo(_ todo: SchemaRecord) async throws {
        try await service.deleteRecord(todo)
        // No need to reload - real-time sync will update automatically!
    }
    
    // Access fields with type safety
    func getTitle(_ todo: SchemaRecord) -> String {
        return todo.get("title", as: String.self) ?? ""
    }
    
    func getDescription(_ todo: SchemaRecord) -> String {
        return todo.get("description", as: String.self) ?? ""
    }
    
    func getCompleted(_ todo: SchemaRecord) -> Bool {
        return todo.get("is_completed", as: Bool.self) ?? false
    }
}
```

**Benefits:**
- ✅ **Zero code generation** - use schema directly
- ✅ **Type-safe access** - `get("field", as: Type.self)`
- ✅ **No copy/paste** - everything inferred from schema
- ✅ **Runtime flexibility** - works with any schema
- ✅ **Real-time sync** - automatically updates when Supabase changes
- ✅ **Query methods** - `getAll()`, `getOne(id:)`, `getAll(where:)`, `getFirst(where:)`

### Query Examples

```swift
// Get all todos
let allTodos = try await service.getAll()

// Get one todo by ID
let todo = try await service.getOne(id: todoId)

// Get all completed todos
let completed = try await service.getAll(
    where: "is_completed = ?",
    parameters: ["true"]
)

// Get first incomplete todo
let firstIncomplete = try await service.getFirst(
    where: "is_completed = ?",
    parameters: ["false"],
    orderBy: "created_at ASC"
)
```

### Option 2: Generate Model Code (Advanced - For Compile-Time Types)

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

Then use `TypedZyraSync<Todo>` instead of `SchemaBasedSync`. See Step 5 Option B for details.

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

### Option B: Using Generated Model (TypedZyraSync) - Advanced

**Note**: Option 1 (SchemaRecord) is recommended for most use cases. Option 2 provides compile-time type safety but requires code generation and doesn't include built-in real-time sync.

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

**Note**: `TypedZyraSync` doesn't include built-in real-time sync like `SchemaBasedSync`. You'll need to manually reload after changes or implement Combine publishers yourself.

## Step 6: Create the Todo List View

Create `TodoListView.swift` with edit and delete functionality:

```swift
import SwiftUI
import ZyraForm

struct TodoListView: View {
    @StateObject private var todoService: TodoService
    @State private var showingAddTodo = false
    @State private var showingEditTodo = false
    @State private var editingTodo: SchemaRecord?
    
    init(userId: String = AppConfig.userId) {
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
                        Text("Tap the + button to add your first todo")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(todoService.todos, id: \.id) { todo in
                            TodoItemView(
                                todo: todo,
                                todoService: todoService,
                                onTap: {
                                    editingTodo = todo
                                    showingEditTodo = true
                                }
                            )
                        }
                        .onDelete { indexSet in
                            Task {
                                for index in indexSet {
                                    await deleteTodo(todoService.todos[index])
                                }
                            }
                        }
                    }
                    .refreshable {
                        await todoService.loadTodos()
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
            .sheet(isPresented: $showingEditTodo) {
                if let todo = editingTodo {
                    EditTodoView(todo: todo, todoService: todoService)
                }
            }
            .task {
                await todoService.loadTodos()
            }
        }
    }
    
    private func deleteTodo(_ todo: SchemaRecord) async {
        do {
            try await todoService.deleteTodo(todo)
        } catch {
            print("Failed to delete todo: \(error)")
        }
    }
}
```

## Step 7: Create the Todo Item View

Create `TodoItemView.swift`:

```swift
import SwiftUI
import ZyraForm

struct TodoItemView: View {
    let todo: SchemaRecord
    @ObservedObject var todoService: TodoService
    var onTap: (() -> Void)?
    @State private var isToggling = false
    
    var body: some View {
        HStack {
            Button(action: {
                Task {
                    await toggleTodo()
                }
            }) {
                Image(systemName: todoService.getCompleted(todo) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(todoService.getCompleted(todo) ? .green : .gray)
                    .font(.title2)
            }
            .disabled(isToggling)
            
            Button(action: {
                onTap?()
            }) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(todoService.getTitle(todo))
                        .font(.headline)
                        .strikethrough(todoService.getCompleted(todo))
                        .foregroundColor(todoService.getCompleted(todo) ? .secondary : .primary)
                    
                    if let description = todo.get("description", as: String.self), !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
        }
        .contentShape(Rectangle())
    }
    
    private func toggleTodo() async {
        isToggling = true
        do {
            try await todoService.toggleTodo(todo)
        } catch {
            print("Failed to toggle todo: \(error)")
        }
        isToggling = false
    }
}
```

## Step 8: Create Add and Edit Todo Views

The `AddTodoView` and `EditTodoView` are included in `TodoListView.swift`. Here's what they do:

### AddTodoView
- Modal sheet for creating new todos
- Form with title and description fields
- Save button validates and creates the todo

### EditTodoView  
- Modal sheet for editing existing todos
- Pre-fills with current todo data
- Save button updates the todo
- Delete button removes the todo

Both views are included in the `TodoListView.swift` file above. Here's the complete implementation:

```swift
import SwiftUI
import ZyraForm

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

struct EditTodoView: View {
    let todo: SchemaRecord
    @ObservedObject var todoService: TodoService
    @Environment(\.dismiss) var dismiss
    @State private var title: String
    @State private var description: String
    @State private var isSaving = false
    
    init(todo: SchemaRecord, todoService: TodoService) {
        self.todo = todo
        self.todoService = todoService
        _title = State(initialValue: todoService.getTitle(todo))
        _description = State(initialValue: todoService.getDescription(todo))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Todo Details")) {
                    TextField("Title", text: $title)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Button(role: .destructive, action: {
                        Task {
                            await deleteTodo()
                        }
                    }) {
                        HStack {
                            Spacer()
                            Text("Delete Todo")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Todo")
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
            let updatedTodo = todo.setting([
                "title": title,
                "description": description
            ])
            try await todoService.updateTodo(updatedTodo)
            dismiss()
        } catch {
            print("Failed to update todo: \(error)")
            isSaving = false
        }
    }
    
    private func deleteTodo() async {
        do {
            try await todoService.deleteTodo(todo)
            dismiss()
        } catch {
            print("Failed to delete todo: \(error)")
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

### SchemaRecord (Recommended Approach)
- `SchemaRecord` works directly with `ZyraTable` schemas - **no model generation needed!**
- Type-safe field access: `todo.get("field", as: Type.self)`
- Zero boilerplate - use your schema directly
- Perfect for rapid development and multi-table forms
- Runtime flexibility - works with any schema

### SchemaBasedSync Service
- `SchemaBasedSync` provides CRUD operations with `SchemaRecord`
- Automatically uses schema for field configuration
- **Real-time sync** - automatically updates when Supabase changes (via PowerSync)
- Handles encryption, validation, and sync automatically
- Works offline with PowerSync integration

### Query Methods
- **Get All**: `service.getAll()` - all records for current user
- **Get One**: `service.getOne(id:)` - single record by ID
- **Get All Where**: `service.getAll(where:parameters:orderBy:)` - filtered records
- **Get First Where**: `service.getFirst(where:parameters:orderBy:)` - first matching record

### CRUD Operations
- **Create**: `service.createRecord(_ record: SchemaRecord)` - creates and syncs
- **Read**: `service.loadRecords(...)` or use query methods - returns `[SchemaRecord]`
- **Update**: `service.updateRecord(_ record: SchemaRecord)` - updates and syncs
- **Delete**: `service.deleteRecord(_ record: SchemaRecord)` - deletes and syncs
- **Real-time**: Changes automatically sync via PowerSync - no manual reload needed!

### Schema Definition
- Use `ZyraTable` to define tables (single source of truth)
- Use `zf.text()`, `zf.integer()`, etc. for column types
- Add validations with `.minLength()`, `.maxLength()`, `.notNull()`, etc.
- Define RLS policies with `RLSPolicyBuilder`
- Schema provides validation, types, and structure - define once, use everywhere!

### PowerSync Real-Time Sync
- Changes in Supabase automatically appear in your app
- Changes in your app automatically sync to Supabase
- Works offline - queues changes and syncs when online
- No manual refresh needed - UI updates automatically via Combine publishers

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
├── App.swift (or ZeraForm_TodoApp.swift)
├── AppConfig.swift (or Utils/Initialize.swift)
├── Models/
│   └── Schema.swift (contains todoTable definition)
├── Controllers/
│   └── TodoService.swift (uses SchemaBasedSync)
├── Views/
│   ├── TodoListView.swift (includes AddTodoView and EditTodoView)
│   └── TodoItemView.swift
└── ContentView.swift
```

**Note**: No `Todo.swift` model file needed! We use `SchemaRecord` directly from the schema.

That's it! You now have a fully functional todo app with:
- ✅ Zero boilerplate - no model generation needed
- ✅ Real-time sync - automatic updates from Supabase
- ✅ Offline support - works completely offline
- ✅ Full CRUD - Create, Read, Update, Delete
- ✅ Type-safe access - `get("field", as: Type.self)`
- ✅ Schema-first - single source of truth 🎉

