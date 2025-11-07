//
//  TodoItemView.swift
//  ZeraForm-Todo
//
//  Created by Michael Martell on 11/7/25.
//

import SwiftUI
import ZyraForm

struct TodoItemView: View {
    let todo: SchemaRecord
    @ObservedObject var todoService: TodoService
    var onTap: (() -> Void)?
    @State private var isToggling = false
    
    var body: some View {
        HStack {
            Button(action: {
                Task {
                    await toggleTodo()
                }
            }) {
                Image(systemName: todoService.getCompleted(todo) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(todoService.getCompleted(todo) ? .green : .gray)
                    .font(.title2)
            }
            .disabled(isToggling)
            
            Button(action: {
                onTap?()
            }) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(todoService.getTitle(todo))
                        .font(.headline)
                        .strikethrough(todoService.getCompleted(todo))
                        .foregroundColor(todoService.getCompleted(todo) ? .secondary : .primary)
                    
                    if let description = todo.get("description", as: String.self), !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
        }
        .contentShape(Rectangle())
    }
    
    private func toggleTodo() async {
        isToggling = true
        do {
            try await todoService.toggleTodo(todo)
        } catch {
            print("Failed to toggle todo: \(error)")
        }
        isToggling = false
    }
}

#Preview {
    let sampleTodo = todoTable.createRecord(from: [
        "id": UUID().uuidString,
        "title": "Sample Todo",
        "description": "This is a sample description",
        "is_completed": "false",
        "user_id": "test-user"
    ])
    
    List {
        TodoItemView(
            todo: sampleTodo,
            todoService: TodoService(userId: "test-user"),
            onTap: {}
        )
    }
}
