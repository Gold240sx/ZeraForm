//
//  PowerSyncFormExample.swift
//  ZyraForm
//
//  Example of how to use PowerSyncForm
//

import SwiftUI

// MARK: - Example: Simple Employee Form using PowerSyncForm

struct SimpleEmployeeFormView: View {
    @StateObject private var form: PowerSyncForm<EmployeeFormValues>
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var service: GenericPowerSyncService
    
    let employeeId: String?
    let onSave: (() -> Void)?
    
    init(service: GenericPowerSyncService, employeeId: String? = nil, onSave: (() -> Void)? = nil) {
        self.service = service
        self.employeeId = employeeId
        self.onSave = onSave
        
        // Initialize form with schema
        _form = StateObject(wrappedValue: PowerSyncForm(
            schema: schema,
            mode: .onChange  // Validate on every change
        ))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Employee Information") {
                    // Email field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Email")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("email@example.com", text: form.binding(for: "email"))
                            .textContentType(.emailAddress)
                            .autocorrectionDisabled()
                        
                        if form.hasError("email"), let error = form.getError("email") {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Name field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Full Name", text: form.binding(for: "name"))
                        
                        if form.hasError("name"), let error = form.getError("name") {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Age field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Age (Optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Age", text: form.intBinding(for: "age"))
                        
                        if form.hasError("age"), let error = form.getError("age") {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Website field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Website (Optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("https://example.com", text: form.binding(for: "website"))
                            .textContentType(.URL)
                            .autocorrectionDisabled()
                        
                        if form.hasError("website"), let error = form.getError("website") {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle(employeeId == nil ? "New Employee" : "Edit Employee")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveEmployee()
                        }
                    }
                    .disabled(!form.isValid || form.isSubmitting)
                }
            }
            .task {
                if let employeeId = employeeId {
                    await loadEmployee(id: employeeId)
                }
            }
        }
    }
    
    private func loadEmployee(id: String) async {
        do {
            try await form.loadFromPowerSync(
                recordId: id,
                service: service
            )
        } catch {
            PrintDebug("Failed to load employee: \(error)", debug: true)
        }
    }
    
    private func saveEmployee() async {
        let config = schema.toTableFieldConfig()
        
        await form.submit { values in
            Task {
                do {
                    let fields = values.toDictionary()
                    
                    if let employeeId = employeeId {
                        try await service.updateRecord(
                            id: employeeId,
                            fields: fields,
                            encryptedFields: config.encryptedFields,
                            autoTimestamp: true
                        )
                    } else {
                        _ = try await service.createRecord(
                            fields: fields,
                            encryptedFields: config.encryptedFields,
                            autoGenerateId: true,
                            autoTimestamp: true
                        )
                    }
                    
                    await MainActor.run {
                        dismiss()
                        onSave?()
                    }
                } catch {
                    PrintDebug("Failed to save employee: \(error)", debug: true)
                }
            }
        }
    }
}

