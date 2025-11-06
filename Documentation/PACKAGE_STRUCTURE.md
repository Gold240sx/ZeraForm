//
//  PACKAGE_STRUCTURE.md
//  ZyraForm
//
//  Package structure documentation
//

# ZyraForm Package Structure

## Package Files

### Sources/ZyraForm/

**Core Files:**
- `ZyraForm.swift` - Main form class (renamed from PowerSyncForm)
- `ZyraFormManager.swift` - Main entry point for initialization
- `ZyraFormConfig.swift` - Configuration struct for user settings

**Schema & Database:**
- `ExtendedTable.swift` - Schema definition
- `GenericPowerSyncService.swift` - Database CRUD operations
- `EncryptionManager.swift` - Encryption handling

**Backend:**
- `SupabaseConnector.swift` - PowerSync backend connector

**Supporting Types:**
- `FormValues.swift` - FormValues protocol
- `FormValidationMode.swift` - Validation modes enum
- `FormErrors.swift` - Error handling struct

## User Responsibilities

Users only need to provide:

1. **Supabase Configuration:**
   - Supabase URL
   - Supabase anon key

2. **PowerSync Configuration:**
   - PowerSync endpoint URL
   - PowerSync encryption password

3. **Schema Definition:**
   - ExtendedTable definitions
   - ExtendedSchema with tables

4. **Form Values:**
   - FormValues conforming structs

## Package Responsibilities

The package handles:
- Form validation
- Field bindings
- PowerSync database initialization
- Supabase connection
- Data synchronization
- Encryption
- Error handling
- Field visibility rules

## Example Usage

```swift
// 1. Define schema
let schema = ExtendedSchema(tables: [employeesTable])

// 2. Configure
let config = ZyraFormConfig(
    supabaseURL: URL(string: "https://...")!,
    supabaseKey: "key",
    powerSyncEndpoint: "https://...",
    powerSyncPassword: "password",
    userId: "user123",
    schema: schema
)

// 3. Initialize
try await ZyraFormManager.initialize(with: config)

// 4. Use forms
let form = ZyraFormManager.shared!.form(for: employeesTable)
```

