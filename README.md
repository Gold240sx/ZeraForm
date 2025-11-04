//
//  README.md
//  ZyraForm
//
//  Swift Package for building forms with PowerSync and Supabase
//

# ZyraForm

A Swift Package for building powerful, validated forms with PowerSync and Supabase integration.

## Installation

Add ZyraForm to your Package.swift:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/ZyraForm.git", from: "1.0.0")
]
```

## Quick Start

1. **Define your schema:**

```swift
import ZyraForm

let employeesTable = ExtendedTable(
    name: "employees",
    primaryKey: "id",
    columns: [
        zf.text("email").email().notNull(),
        zf.text("name").minLength(2).maxLength(50).notNull(),
        zf.integer("age").intMin(18).intMax(120).nullable(),
        zf.text("website").url().nullable()
    ]
)

let schema = ExtendedSchema(tables: [employeesTable])
```

2. **Initialize ZyraForm:**

```swift
import ZyraForm

let config = ZyraFormConfig(
    supabaseURL: URL(string: "https://your-project.supabase.co")!,
    supabaseKey: "your-supabase-anon-key",
    powerSyncEndpoint: "https://your-id.powersync.journeyapps.com",
    powerSyncPassword: "your-powersync-password",
    dbPrefix: "app_",
    userId: "current-user-id",
    schema: schema
)

try await ZyraFormManager.initialize(with: config)
```

3. **Create a form:**

```swift
struct EmployeeFormValues: FormValues {
    var email: String = ""
    var name: String = ""
    var age: String = ""
    var website: String = ""
    
    func toDictionary() -> [String: Any] {
        return [
            "email": email,
            "name": name,
            "age": age.isEmpty ? nil : Int(age),
            "website": website
        ]
    }
    
    mutating func update(from dictionary: [String: Any]) {
        email = dictionary["email"] as? String ?? ""
        name = dictionary["name"] as? String ?? ""
        if let ageValue = dictionary["age"] as? Int {
            age = String(ageValue)
        }
        website = dictionary["website"] as? String ?? ""
    }
}

@StateObject var form = ZyraFormManager.shared!.form(
    for: employeesTable,
    mode: .onChange
)
```

4. **Use in your SwiftUI view:**

```swift
Form {
    TextField("Email", text: form.binding(for: "email"))
    if form.hasError("email") {
        Text(form.getError("email") ?? "")
            .foregroundColor(.red)
    }
    
    TextField("Name", text: form.binding(for: "name"))
    
    Button("Save") {
        await form.submit { values in
            let service = ZyraFormManager.shared!.service(for: "employees")
            try await service.createRecord(fields: values.toDictionary())
        }
    }
    .disabled(!form.isValid || form.isSubmitting)
}
```

## Features

- ✅ Automatic validation based on schema
- ✅ Multiple validation modes (onChange, onBlur, onSubmit, onTouched)
- ✅ PowerSync integration for offline-first apps
- ✅ Supabase backend sync
- ✅ Field visibility rules
- ✅ Type-safe bindings
- ✅ Error handling
- ✅ Built-in logging for debugging (404s, connection errors, key issues)

## Logging

ZyraForm includes comprehensive built-in logging to help debug issues:

### Enable/Disable Logging

```swift
// Disable logging (default: enabled)
ZyraFormLogger.isEnabled = false

// Enable logging
ZyraFormLogger.isEnabled = true
```

### Log Levels

The logger automatically detects and logs:
- **Supabase 404 Errors**: When tables or records are not found
- **PowerSync Key Errors**: When endpoint or credentials are incorrect
- **Connection Errors**: Network and host connectivity issues
- **HTTP Status Codes**: 401 (Unauthorized), 403 (Forbidden), 404 (Not Found)

### Example Log Output

```
ℹ️ [ZyraForm INFO] 🚀 Initializing ZyraForm...
ℹ️ [ZyraForm INFO] 📋 Supabase URL: https://your-project.supabase.co
ℹ️ [ZyraForm INFO] 📋 PowerSync Endpoint: https://id.powersync.journeyapps.com
❌ [ZyraForm ERROR] ❌ [SUPABASE 404] Resource not found
❌ [ZyraForm ERROR] 📋 Table: employees
❌ [ZyraForm ERROR] 💡 Possible causes:
❌ [ZyraForm ERROR]    1. Table 'employees' does not exist in Supabase
❌ [ZyraForm ERROR]    2. Record with id 'xxx' was already deleted
❌ [ZyraForm ERROR]    3. Row Level Security (RLS) policy is blocking access

🔑 [POWERSYNC KEY ERROR]
💡 Possible causes:
   1. PowerSync endpoint URL is incorrect
   2. PowerSync password/key is incorrect
   3. Supabase session token is invalid
```

# ZeraForm
