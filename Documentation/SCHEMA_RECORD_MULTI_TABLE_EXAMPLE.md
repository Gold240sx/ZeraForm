# SchemaRecord with Multi-Table Forms - Complete Example

This document shows how `SchemaRecord` works seamlessly with multi-table forms and forms with defined field sets.

## Signup Form Example: users_public + users_private

### Step 1: Define Schemas

```swift
import ZyraForm

// Public user table (email, username visible to all)
let usersPublicTable = ZyraTable(
    name: "users_public",
    primaryKey: "id",
    columns: [
        zf.text("email").email().notNull().unique(),
        zf.text("username").minLength(3).maxLength(30).notNull().unique(),
        zf.text("display_name").maxLength(100).nullable()
    ]
)

// Private user table (sensitive data)
let usersPrivateTable = ZyraTable(
    name: "users_private",
    primaryKey: "id",
    columns: [
        zf.text("user_id").notNull().references(usersPublicTable),
        zf.text("has_illness").default("false").notNull(),
        zf.text("medical_notes").nullable()
    ]
)
```

### Step 2: Create Multi-Table Form

```swift
import SwiftUI
import ZyraForm

struct SignupView: View {
    @StateObject private var form = ZyraMultiTableForm(
        schemas: [
            (table: usersPublicTable, fields: ["email", "username", "display_name"]),
            (table: usersPrivateTable, fields: ["has_illness", "medical_notes"])
        ],
        relationship: .firstToSecond(foreignKey: "user_id")
    )
    
    @State private var showSuccess = false
    
    var body: some View {
        Form {
            Section("Public Profile") {
                TextField("Email", text: Binding(
                    get: { form.getValue(for: "email") as? String ?? "" },
                    set: { form.setValue($0, for: "email") }
                ))
                if form.errors.hasError("email") {
                    Text(form.errors.getError("email") ?? "")
                        .foregroundColor(.red)
                }
                
                TextField("Username", text: Binding(
                    get: { form.getValue(for: "username") as? String ?? "" },
                    set: { form.setValue($0, for: "username") }
                ))
                
                TextField("Display Name (optional)", text: Binding(
                    get: { form.getValue(for: "display_name") as? String ?? "" },
                    set: { form.setValue($0, for: "display_name") }
                ))
            }
            
            Section("Private Information") {
                Toggle("Has Illness", isOn: Binding(
                    get: { form.getValue(for: "has_illness") as? String == "true" },
                    set: { form.setValue($0 ? "true" : "false", for: "has_illness") }
                ))
                
                TextField("Medical Notes (optional)", text: Binding(
                    get: { form.getValue(for: "medical_notes") as? String ?? "" },
                    set: { form.setValue($0, for: "medical_notes") }
                ), axis: .vertical)
                    .lineLimit(3...10)
            }
            
            Button("Sign Up") {
                Task {
                    await submitForm()
                }
            }
            .disabled(!form.isValid || form.isSubmitting)
        }
    }
    
    func submitForm() async {
        guard let manager = ZyraFormManager.shared else { return }
        
        do {
            // Submit using SchemaRecord - returns SchemaRecords for each table!
            let results = try await form.submitWithSchemaRecords(
                userId: "current-user-id",
                database: manager.database
            )
            
            // Access the created records with type safety
            if let publicRecord = results["users_public"] {
                let email: String = publicRecord.get("email", as: String.self) ?? ""
                let username: String = publicRecord.get("username", as: String.self) ?? ""
                print("Created public user: \(username) (\(email))")
            }
            
            if let privateRecord = results["users_private"] {
                let hasIllness: Bool = privateRecord.get("has_illness", as: Bool.self) ?? false
                print("Has illness: \(hasIllness)")
            }
            
            showSuccess = true
        } catch {
            print("Signup failed: \(error)")
        }
    }
}
```

## Using withFields() for Filtered Schemas

If you want to create a form that only uses specific fields from a table:

```swift
// Create a filtered version of the table with only specific fields
let publicFieldsOnly = usersPublicTable.withFields(["email", "username"])

// Use it in a multi-table form
let form = ZyraMultiTableForm(
    schemas: [
        (table: publicFieldsOnly, fields: ["email", "username"]),
        (table: usersPrivateTable, fields: ["has_illness"])
    ],
    relationship: .firstToSecond(foreignKey: "user_id")
)
```

## Accessing Form Data as SchemaRecords

You can preview what will be submitted without actually submitting:

```swift
// Get current form values as SchemaRecords
let currentRecords = form.getCurrentRecords()

if let publicRecord = currentRecords["users_public"] {
    let email = publicRecord.get("email", as: String.self) ?? ""
    // Preview email before submission
    print("Will submit email: \(email)")
}
```

## Benefits

✅ **No Model Generation** - Works directly with schemas
✅ **Type-Safe Access** - `get("field", as: Type.self)` with automatic conversion
✅ **Multi-Table Support** - Handles relationships automatically
✅ **Field Filtering** - Use `withFields()` to limit which fields are included
✅ **Validation** - Automatic validation from schema rules
✅ **Clean API** - `submitWithSchemaRecords()` returns typed records

## Comparison: SchemaRecord vs Generated Models

### SchemaRecord (Option 1 - Recommended)
```swift
// No code generation needed
let form = ZyraMultiTableForm(...)
let results = try await form.submitWithSchemaRecords(...)
let email = results["users_public"]?.get("email", as: String.self)
```

### Generated Models (Option 2)
```swift
// Requires code generation
struct UserPublic: ZyraModel { ... }
struct UserPrivate: ZyraModel { ... }
let results = try await form.submit(publicType: UserPublic.self, ...)
let email = results.publicId.email  // Compile-time type safety
```

**Recommendation**: Use SchemaRecord for rapid development and flexibility. Use generated models if you need compile-time type safety and don't mind the code generation step.

