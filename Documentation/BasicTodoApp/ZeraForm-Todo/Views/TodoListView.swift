//
//  TodoListView.swift
//  ZeraForm-Todo
//
//  Created by Michael Martell on 11/7/25.
//

import SwiftUI
import ZyraForm

struct TodoListView: View {
    @StateObject private var todoService: TodoService
    @State private var showingAddTodo = false
    @State private var newTodoTitle = ""
    @State private var newTodoDescription = ""
    
    init(userId: String = AppConfig.userId) {
        _todoService = StateObject(wrappedValue: TodoService(userId: userId))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if todoService.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if todoService.todos.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "checklist")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No todos yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Tap the + button to add your first todo")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(todoService.todos, id: \.id) { todo in
                            TodoItemView(todo: todo, todoService: todoService)
                        }
                        .onDelete { indexSet in
                            Task {
                                for index in indexSet {
                                    await deleteTodo(todoService.todos[index])
                                }
                            }
                        }
                    }
                    .refreshable {
                        await todoService.loadTodos()
                    }
                }
            }
            .navigationTitle("Todos")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddTodo = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTodo) {
                AddTodoView(todoService: todoService)
            }
            .task {
                await todoService.loadTodos()
            }
        }
    }
    
    private func deleteTodo(_ todo: SchemaRecord) async {
        do {
            try await todoService.deleteTodo(todo)
        } catch {
            print("Failed to delete todo: \(error)")
        }
    }
}

struct AddTodoView: View {
    @ObservedObject var todoService: TodoService
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Todo Details")) {
                    TextField("Title", text: $title)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Todo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveTodo()
                        }
                    }
                    .disabled(title.isEmpty || isSaving)
                }
            }
        }
    }
    
    private func saveTodo() async {
        guard !title.isEmpty else { return }
        
        isSaving = true
        do {
            try await todoService.createTodo(title: title, description: description)
            dismiss()
        } catch {
            print("Failed to create todo: \(error)")
            isSaving = false
        }
    }
}

#Preview {
    TodoListView()
}
