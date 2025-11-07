//
//  TodoService.swift
//  ZeraForm-Todo
//
//  Created by Michael Martell on 11/7/25.
//

import Foundation
import Combine
import ZyraForm

@MainActor
class TodoService: ObservableObject {
    private var service: SchemaBasedSync?
    let userId: String
    private var cancellables = Set<AnyCancellable>()
    
    @Published var todos: [SchemaRecord] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init(userId: String) {
        self.userId = userId
        // Service will be initialized lazily when loadTodos() is called
    }
    
    private func ensureService() throws -> SchemaBasedSync {
        if let existingService = service {
            return existingService
        }
        
        guard let manager = ZyraFormManager.shared else {
            throw NSError(domain: "TodoService", code: 1, userInfo: [NSLocalizedDescriptionKey: "ZyraFormManager not initialized"])
        }
        
        // Use SchemaBasedSync - works directly with todoTable schema!
        // watchForUpdates defaults to true, enabling real-time PowerSync sync from Supabase
        let newService = SchemaBasedSync(
            schema: todoTable,
            userId: userId,
            database: manager.database
            // watchForUpdates defaults to true - real-time sync enabled by default!
        )
        
        // Observe service.records for real-time updates
        // When PowerSync detects changes in Supabase, service.records updates automatically
        newService.$records
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedRecords in
                self?.todos = updatedRecords
            }
            .store(in: &cancellables)
        
        self.service = newService
        return newService
    }
    
    func loadTodos() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let service = try ensureService()
            
            // This sets up the PowerSync watch query
            // After this, any changes in Supabase will automatically update todos via the Combine publisher
            try await service.loadRecords(
                whereClause: "user_id = ?",
                parameters: [userId]
            )
            // Initial load - subsequent updates come via Combine publisher
            todos = service.records
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            print("Failed to load todos: \(error)")
        }
    }
    
    func createTodo(title: String, description: String = "") async throws {
        let service = try ensureService()
        
        // Create record directly from schema - clean syntax!
        let record = todoTable.createEmptyRecord()
            .setting([
                "title": title,
                "description": description,
                "is_completed": "false",
                "user_id": userId
            ])
        
        _ = try await service.createRecord(record)
        // No need to reload - PowerSync watch will automatically update todos
    }
    
    func updateTodo(_ todo: SchemaRecord) async throws {
        let service = try ensureService()
        try await service.updateRecord(todo)
        // No need to reload - PowerSync watch will automatically update todos
    }
    
    func toggleTodo(_ todo: SchemaRecord) async throws {
        let currentCompleted = todo.get("is_completed", as: Bool.self) ?? false
        let updatedTodo = todo.setting("is_completed", to: !currentCompleted ? "true" : "false")
        try await updateTodo(updatedTodo)
    }
    
    func deleteTodo(_ todo: SchemaRecord) async throws {
        let service = try ensureService()
        try await service.deleteRecord(todo)
        // No need to reload - PowerSync watch will automatically update todos
    }
    
    // Helper methods for type-safe access
    func getTitle(_ todo: SchemaRecord) -> String {
        return todo.get("title", as: String.self) ?? ""
    }
    
    func getDescription(_ todo: SchemaRecord) -> String {
        return todo.get("description", as: String.self) ?? ""
    }
    
    func getCompleted(_ todo: SchemaRecord) -> Bool {
        return todo.get("is_completed", as: Bool.self) ?? false
    }
}

