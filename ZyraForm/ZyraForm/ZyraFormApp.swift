//
//  ZyraFormApp.swift
//  ZyraForm
//
//  Created by Michael Martell on 11/4/25.
//

import SwiftUI

@main
struct ZyraFormApp: App {
    init() {
        // Connect PowerSync to Supabase when app launches
        Task {
            do {
                try await db.connect(connector: SupabaseConnector.shared)
                print("[PowerSync] ✅ Connected to Supabase")
            } catch {
                print("[PowerSync] ❌ Failed to connect to Supabase: \(error)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
