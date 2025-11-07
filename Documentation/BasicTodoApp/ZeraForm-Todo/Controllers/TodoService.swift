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
    private let service: SchemaBasedSync
    let userId: String
    private var cancellables = Set<AnyCancellable>()
    
    @Published var todos: [SchemaRecord] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init(userId: String) {
        self.userId = userId
        
        guard let manager = ZyraFormManager.shared else {
            fatalError("ZyraFormManager not initialized")
        }
        
        // Use SchemaBasedSync - works directly with todoTable schema!
        // watchForUpdates defaults to true, enabling real-time PowerSync sync from Supabase
        self.service = SchemaBasedSync(
            schema: todoTable,
            userId: userId,
            database: manager.database
            // watchForUpdates defaults to true - real-time sync enabled by default!
        )
        
        // Observe service.records for real-time updates
        // When PowerSync detects changes in Supabase, service.records updates automatically
        service.$records
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedRecords in
                self?.todos = updatedRecords
            }
            .store(in: &cancellables)
    }
    
    func loadTodos() async {
        isLoading = true
        errorMessage = nil
        
        do {
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
        // Create record directly from schema - clean syntax!
        let record = todoTable.createEmptyRecord()
            .setting([
                "title": title,
                "description": description,
                "is_completed": "false",
                "user_id": userId
            ])
        
        _ = try await service.createRecord(record)
        await loadTodos()
    }
    
    func updateTodo(_ todo: SchemaRecord) async throws {
        try await service.updateRecord(todo)
        await loadTodos()
    }
    
    func toggleTodo(_ todo: SchemaRecord) async throws {
        let currentCompleted = todo.get("is_completed", as: Bool.self) ?? false
        let updatedTodo = todo.setting("is_completed", to: !currentCompleted ? "true" : "false")
        try await updateTodo(updatedTodo)
    }
    
    func deleteTodo(_ todo: SchemaRecord) async throws {
        try await service.deleteRecord(todo)
        await loadTodos()
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

