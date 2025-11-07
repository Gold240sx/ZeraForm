//
//  ZeraForm_TodoApp.swift
//  ZeraForm-Todo
//
//  Created by Michael Martell on 11/7/25.
//

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
