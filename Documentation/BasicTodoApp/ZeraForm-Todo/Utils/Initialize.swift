//
//  Initialize.swift
//  ZeraForm-Todo
//
//  Created by Michael Martell on 11/7/25.
//

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
