//
//  ZyraFormApp.swift
//  ZyraForm
//
//  Created by Michael Martell on 11/4/25.
//

import SwiftUI
import ZyraForm

@main
struct ZyraFormApp: App {
    init() {
        // Initialize ZyraForm with configuration from environment variables
        Task {
            do {
                // Create schema from the app's schema definition
                let zyraSchema = ZyraSchema(tables: [schema])
                
                // Create configuration from environment variables
                let config = AppConfig.createZyraFormConfig(schema: zyraSchema)
                
                // Initialize ZyraFormManager (this will connect to PowerSync/Supabase)
                try await ZyraFormManager.initialize(with: config)
                print("[ZyraForm] ✅ Successfully initialized and connected")
            } catch {
                print("[ZyraForm] ❌ Failed to initialize: \(error)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
