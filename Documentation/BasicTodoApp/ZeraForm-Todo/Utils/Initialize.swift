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
    // MARK: - Supabase Configuration
    // Get these from your Supabase project dashboard:
    // 1. Go to https://app.supabase.com
    // 2. Select your project
    // 3. Go to Settings → API
    // 4. Copy "Project URL" and "anon public" key
    static let supabaseURL = URL(string: "https://YOUR_PROJECT_ID.supabase.co")! // ⚠️ REPLACE WITH YOUR SUPABASE URL
    static let supabaseKey = "YOUR_SUPABASE_ANON_KEY" // ⚠️ REPLACE WITH YOUR SUPABASE ANON KEY
    
    // MARK: - PowerSync Configuration
    // Get these from your PowerSync dashboard:
    // 1. Go to https://app.powersync.com
    // 2. Select your instance
    // 3. Copy the "Instance URL" and "Instance Password"
    static let powerSyncEndpoint = "https://YOUR_INSTANCE_ID.powersync.journeyapps.com" // ⚠️ REPLACE WITH YOUR POWERSYNC ENDPOINT
    static let powerSyncPassword = "YOUR_POWERSYNC_PASSWORD" // ⚠️ REPLACE WITH YOUR POWERSYNC PASSWORD
    
    // MARK: - User Configuration
    // In a real app, get this from Supabase Auth after user signs in
    static let userId = "YOUR_USER_ID" // ⚠️ REPLACE WITH ACTUAL USER ID FROM AUTH
    
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
