# PowerSync Real-Time Sync - How It Works

## ✅ Yes, Your App Uses PowerSync!

Your BasicTodoApp is fully configured for **real-time bidirectional sync** with Supabase via PowerSync.

## How It Works

### 1. **PowerSync Configuration**
Your app initializes PowerSync in `Initialize.swift`:
```swift
let connector = SupabaseConnector(
    supabaseURL: supabaseURL,
    supabaseKey: supabaseKey,
    powerSyncEndpoint: powerSyncEndpoint,  // PowerSync endpoint
    powerSyncPassword: powerSyncPassword  // PowerSync password
)
```

### 2. **Real-Time Watching**
`SchemaBasedSync` uses PowerSync's `watch()` API which:
- ✅ Sets up a **real-time subscription** to your Supabase database
- ✅ Automatically receives updates when data changes in Supabase
- ✅ Updates the local SQLite database (PowerSync's local cache)
- ✅ Publishes changes via Combine to update your UI

### 3. **Automatic UI Updates**
`TodoService` observes `service.$records` using Combine:
```swift
service.$records
    .sink { updatedRecords in
        self.todos = updatedRecords  // UI updates automatically!
    }
```

## What Happens When You Update in Supabase

1. **Change in Supabase** → PowerSync detects it via webhook/streaming
2. **PowerSync syncs** → Updates local SQLite database
3. **ZyraSync.watch()** → Detects the change in local DB
4. **service.records updates** → Combine publisher fires
5. **TodoService observes** → `todos` array updates
6. **SwiftUI updates** → UI refreshes automatically! 🎉

## Bidirectional Sync

- **App → Supabase**: When you create/update/delete in the app, PowerSync queues the change and syncs it to Supabase
- **Supabase → App**: When you update in Supabase (SQL editor, another app, etc.), PowerSync syncs it back to your app automatically

## Offline Support

PowerSync also provides:
- ✅ **Offline-first**: Works completely offline, queues changes
- ✅ **Automatic sync**: When connection returns, syncs queued changes
- ✅ **Conflict resolution**: Handles conflicts automatically

## Testing Real-Time Sync

1. **Run your app** and create some todos
2. **Open Supabase SQL Editor** and update a todo:
   ```sql
   UPDATE todos SET title = 'Updated from Supabase!' WHERE id = 'your-todo-id';
   ```
3. **Watch your app** - the todo should update automatically! ✨

## Configuration Checklist

Make sure you have:
- ✅ Supabase project URL and anon key
- ✅ PowerSync endpoint URL
- ✅ PowerSync password
- ✅ PowerSync bucket configured in Supabase (for your `todos` table)
- ✅ RLS policies set up (your schema defines them)

That's it! Your app is fully set up for real-time sync. 🚀

