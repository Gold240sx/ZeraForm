//
//  README.md
//  ZyraFormSupabase
//
//  Optional Supabase connector helper
//

# ZyraFormSupabase

Optional Supabase connector for ZyraForm. Import this module only if you want Supabase support.

## Usage

```swift
import ZyraForm
import ZyraFormSupabase

// Create Supabase connector
let connector = SupabaseConnector(
    supabaseURL: URL(string: "https://your-project.supabase.co")!,
    supabaseKey: "your-anon-key",
    powerSyncEndpoint: "https://your-id.powersync.journeyapps.com",
    powerSyncPassword: "your-password"
)

// Use with ZyraFormConfig
let config = ZyraFormConfig(
    connector: connector,
    powerSyncPassword: "your-password",
    userId: "user123",
    schema: yourSchema
)
```

## Custom Connectors

If you don't want to use Supabase, you can implement your own connector:

```swift
import ZyraForm
import PowerSync

class MyCustomConnector: PowerSyncBackendConnectorProtocol {
    func fetchCredentials() async throws -> PowerSync.PowerSyncCredentials? {
        // Your custom auth logic
        return PowerSyncCredentials(
            endpoint: "https://your-powersync-endpoint.com",
            token: "your-auth-token"
        )
    }
    
    func uploadData(database: any PowerSync.PowerSyncDatabaseProtocol) async throws {
        // Your custom upload logic
    }
}
```

