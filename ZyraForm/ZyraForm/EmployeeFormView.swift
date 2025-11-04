//
//  EmployeeFormView.swift
//  ZyraForm
//
//  Created by Michael Martell on 11/4/25.
//

import SwiftUI
import Foundation

// MARK: - Employee Form Values

struct EmployeeFormValues: FormValues {
    var email: String = ""
    var name: String = ""
    var age: String = ""
    var website: String = ""
    
    init() {}
    
    init(from record: [String: Any]) {
        self.email = record["email"] as? String ?? ""
        self.name = record["name"] as? String ?? ""
        if let ageValue = record["age"] as? Int {
            self.age = String(ageValue)
        } else if let ageStr = record["age"] as? String {
            self.age = ageStr
        }
        self.website = record["website"] as? String ?? ""
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "email": email,
            "name": name
        ]
        
        if !age.isEmpty, let ageInt = Int(age) {
            dict["age"] = ageInt
        }
        
        if !website.isEmpty {
            dict["website"] = website
        }
        
        return dict
    }
    
    mutating func update(from dictionary: [String: Any]) {
        self.email = dictionary["email"] as? String ?? ""
        self.name = dictionary["name"] as? String ?? ""
        if let ageValue = dictionary["age"] as? Int {
            self.age = String(ageValue)
        } else if let ageStr = dictionary["age"] as? String {
            self.age = ageStr
        }
        self.website = dictionary["website"] as? String ?? ""
    }
}

// MARK: - Employee Form View

struct EmployeeFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var service: GenericPowerSyncService
    
    let employeeId: String?
    let onSave: (() -> Void)?
    
    @State private var formValues = EmployeeFormValues()
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let config: TableFieldConfig = {
        return schema.toTableFieldConfig()
    }()
    
    init(service: GenericPowerSyncService, employeeId: String? = nil, onSave: (() -> Void)? = nil) {
        self.service = service
        self.employeeId = employeeId
        self.onSave = onSave
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
                        TextField("email@example.com", text: $formValues.email)
                            .textContentType(.emailAddress)
                            .autocorrectionDisabled()
                        
                        if !formValues.email.isEmpty && !isValidEmail(formValues.email) {
                            Text("Please enter a valid email address")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Name field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Full Name", text: $formValues.name)
                        
                        if !formValues.name.isEmpty && formValues.name.count < 2 {
                            Text("Name must be at least 2 characters")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        if formValues.name.count > 50 {
                            Text("Name must be 50 characters or less")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Age field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Age (Optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Age", text: $formValues.age)
                        
                        if !formValues.age.isEmpty {
                            if let ageInt = Int(formValues.age) {
                                if ageInt < 18 {
                                    Text("Age must be at least 18")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                } else if ageInt > 120 {
                                    Text("Age must be 120 or less")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            } else {
                                Text("Please enter a valid age")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    // Website field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Website (Optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("https://example.com", text: $formValues.website)
                            .textContentType(.URL)
                            .autocorrectionDisabled()
                        
                        if !formValues.website.isEmpty && !isValidURL(formValues.website) {
                            Text("Please enter a valid URL")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
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
                    .disabled(!isFormValid || isLoading)
                }
            }
            .task {
                if let employeeId = employeeId {
                    await loadEmployee(id: employeeId)
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        guard !formValues.email.isEmpty,
              !formValues.name.isEmpty,
              isValidEmail(formValues.email),
              formValues.name.count >= 2,
              formValues.name.count <= 50 else {
            return false
        }
        
        if !formValues.age.isEmpty {
            guard let ageInt = Int(formValues.age),
                  ageInt >= 18,
                  ageInt <= 120 else {
                return false
            }
        }
        
        if !formValues.website.isEmpty {
            guard isValidURL(formValues.website) else {
                return false
            }
        }
        
        return true
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              url.scheme != nil,
              url.host != nil else {
            return false
        }
        return true
    }
    
    private func loadEmployee(id: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await service.loadRecords(
                fields: config.allFields,
                whereClause: "id = ?",
                parameters: [id],
                orderBy: config.defaultOrderBy,
                encryptedFields: config.encryptedFields,
                integerFields: config.integerFields,
                booleanFields: config.booleanFields
            )
            
            if let employee = service.records.first {
                await MainActor.run {
                    formValues = EmployeeFormValues(from: employee)
                    isLoading = false
                }
            } else {
                await MainActor.run {
                    errorMessage = "Employee not found"
                    isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
            PrintDebug("Failed to load employee: \(error)", debug: true)
        }
    }
    
    private func saveEmployee() async {
        guard isFormValid else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let fields = formValues.toDictionary()
            
            if let employeeId = employeeId {
                // Update existing employee
                try await service.updateRecord(
                    id: employeeId,
                    fields: fields,
                    encryptedFields: config.encryptedFields,
                    autoTimestamp: true
                )
            } else {
                // Create new employee
                _ = try await service.createRecord(
                    fields: fields,
                    encryptedFields: config.encryptedFields,
                    autoGenerateId: true,
                    autoTimestamp: true
                )
            }
            
            await MainActor.run {
                isLoading = false
                dismiss()
                onSave?() // Trigger list refresh
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
            PrintDebug("Failed to save employee: \(error)", debug: true)
        }
    }
}

#Preview {
    EmployeeFormView(
        service: GenericPowerSyncService(
            tableName: "\(AppConfig.shared.dbPrefix)employees",
            userId: userId
        )
    )
}

