//
//  PowerSyncForm.swift
//  ZyraForm
//
//  Created by Michael Martell on 11/4/25.
//

import Foundation
import SwiftUI
import Combine
import PowerSync

// MARK: - Form Values Protocol

public protocol FormValues: Codable {
    init()
    func toDictionary() -> [String: Any]
    mutating func update(from dictionary: [String: Any])
}

// MARK: - Form Validation Mode

public enum FormValidationMode {
    case onChange    // Validate on every change
    case onBlur      // Validate when field loses focus
    case onSubmit    // Validate only on submit
    case onTouched   // Validate once field is touched
}

// MARK: - Form Errors

public struct FormErrors: Codable, Error {
    public private(set) var errors: [String: String] = [:]
    
    public init() {}
    
    public mutating func set(_ message: String, for field: String) {
        errors[field] = message
    }
    
    public mutating func remove(_ field: String) {
        errors.removeValue(forKey: field)
    }
    
    public mutating func clear() {
        errors.removeAll()
    }
    
    public func hasError(_ field: String) -> Bool {
        return errors[field] != nil
    }
    
    public func getError(_ field: String) -> String? {
        return errors[field]
    }
}

// MARK: - Field Visibility Rules

public struct FieldVisibilityRules {
    public private(set) var rules: [String: () -> Bool] = [:]
    
    public init() {}
    
    public mutating func addRule(for field: String, condition: @escaping () -> Bool) {
        rules[field] = condition
    }
    
    public func shouldShow(_ field: String) -> Bool {
        return rules[field]?() ?? true
    }
}

// MARK: - Zyra Form

@MainActor
public class ZyraForm<Values: FormValues>: ObservableObject {
    // MARK: - Published Properties
    
    @Published public private(set) var values: Values
    @Published public private(set) var errors = FormErrors()
    @Published public private(set) var isValid: Bool = false
    @Published public private(set) var isDirty: Bool = false
    @Published public private(set) var isSubmitting: Bool = false
    @Published public private(set) var visibleFields: Set<String> = []
    
    // MARK: - Private Properties
    
    private let schema: ZyraTable
    private var validationMode: FormValidationMode
    private var visibilityRules: FieldVisibilityRules
    private var initialValues: Values
    private var touchedFields: Set<String> = []
    private var blurredFields: Set<String> = []
    
    // MARK: - Initialization
    
    public init(
        schema: ZyraTable,
        initialValues: Values? = nil,
        mode: FormValidationMode = .onChange,
        visibilityRules: FieldVisibilityRules = FieldVisibilityRules()
    ) {
        self.schema = schema
        self.initialValues = initialValues ?? Values()
        self.values = self.initialValues
        self.validationMode = mode
        self.visibilityRules = visibilityRules
        
        updateVisibleFields()
        validate()
    }
    
    // MARK: - Bindings
    
    public func binding(for field: String) -> Binding<String> {
        return Binding(
            get: { [weak self] in
                guard let self = self else { return "" }
                let dict = self.values.toDictionary()
                return dict[field] as? String ?? ""
            },
            set: { [weak self] newValue in
                guard let self = self else { return }
                self.setValue(newValue, for: field)
            }
        )
    }
    
    public func bindingWithBlur(for field: String) -> Binding<String> {
        return Binding(
            get: { [weak self] in
                guard let self = self else { return "" }
                let dict = self.values.toDictionary()
                return dict[field] as? String ?? ""
            },
            set: { [weak self] newValue in
                guard let self = self else { return }
                self.setValue(newValue, for: field)
                Task { @MainActor in
                    self.handleBlur(field)
                }
            }
        )
    }
    
    public func intBinding(for field: String) -> Binding<String> {
        return Binding(
            get: { [weak self] in
                guard let self = self else { return "" }
                let dict = self.values.toDictionary()
                if let intValue = dict[field] as? Int {
                    return String(intValue)
                }
                return dict[field] as? String ?? ""
            },
            set: { [weak self] newValue in
                guard let self = self else { return }
                if let intValue = Int(newValue) {
                    self.setValue(intValue, for: field)
                } else {
                    self.setValue(newValue, for: field)
                }
            }
        )
    }
    
    public func doubleBinding(for field: String) -> Binding<String> {
        return Binding(
            get: { [weak self] in
                guard let self = self else { return "" }
                let dict = self.values.toDictionary()
                if let doubleValue = dict[field] as? Double {
                    return String(doubleValue)
                }
                return dict[field] as? String ?? ""
            },
            set: { [weak self] newValue in
                guard let self = self else { return }
                if let doubleValue = Double(newValue) {
                    self.setValue(doubleValue, for: field)
                } else {
                    self.setValue(newValue, for: field)
                }
            }
        )
    }
    
    public func boolBinding(for field: String) -> Binding<Bool> {
        return Binding(
            get: { [weak self] in
                guard let self = self else { return false }
                let dict = self.values.toDictionary()
                if let boolValue = dict[field] as? Bool {
                    return boolValue
                }
                if let intValue = dict[field] as? Int {
                    return intValue != 0
                }
                if let strValue = dict[field] as? String {
                    return strValue.lowercased() == "true" || strValue == "1"
                }
                return false
            },
            set: { [weak self] newValue in
                guard let self = self else { return }
                self.setValue(newValue, for: field)
            }
        )
    }
    
    // MARK: - Values Management
    
    public func setValue(_ value: Any?, for field: String) {
        guard let column = schema.columns.first(where: { $0.name == field }) else { return }
        
        // Update values dictionary
        var dict = values.toDictionary()
        dict[field] = value
        values.update(from: dict)
        
        // Mark as dirty
        if !isDirty {
            isDirty = true
        }
        
        // Mark as touched
        touchedFields.insert(field)
        
        // Validate based on mode
        switch validationMode {
        case .onChange:
            validateField(field)
        case .onTouched:
            if touchedFields.contains(field) {
                validateField(field)
            }
        default:
            break
        }
        
        updateVisibleFields()
    }
    
    public func setValues(_ newValues: [String: Any]) {
        values.update(from: newValues)
        isDirty = true
        updateVisibleFields()
        
        if validationMode == .onChange {
            validate()
        }
    }
    
    public func getValue(for field: String) -> Any? {
        let dict = values.toDictionary()
        return dict[field]
    }
    
    public func getValues() -> [String: Any] {
        return values.toDictionary()
    }
    
    public func updateValues(_ newValues: [String: Any]) {
        setValues(newValues)
    }
    
    public func setMode(_ newMode: FormValidationMode) {
        validationMode = newMode
    }
    
    // MARK: - Validation
    
    @discardableResult
    public func validate() -> Bool {
        var isValid = true
        
        for column in schema.columns {
            if !shouldShow(column.name) {
                continue
            }
            
            if !validateField(column.name) {
                isValid = false
            }
        }
        
        self.isValid = isValid
        return isValid
    }
    
    @discardableResult
    public func validateField(_ field: String) -> Bool {
        guard let column = schema.columns.first(where: { $0.name == field }) else { return true }
        
        let value = getValue(for: field)
        let error = validateColumn(column, value: value)
        
        if let error = error {
            errors.set(error, for: field)
            isValid = errors.errors.isEmpty
            return false
        } else {
            errors.remove(field)
            isValid = errors.errors.isEmpty
            return true
        }
    }
    
    private func validateColumn(_ column: ColumnMetadata, value: Any?) -> String? {
        // Check required
        if !column.isNullable && (value == nil || (value as? String)?.isEmpty == true) {
            return "\(column.name) is required"
        }
        
        guard let value = value else { return nil }
        
        // Email validation
        if column.isEmail == true {
            if let email = value as? String, !isValidEmail(email) {
                return "Please enter a valid email address"
            }
        }
        
        // URL validation
        if column.isUrl == true {
            if let url = value as? String, !isValidURL(url) {
                return "Please enter a valid URL"
            }
        }
        
        // String length validation
        if let strValue = value as? String {
            if let minLength = column.minLength, strValue.count < minLength {
                return "\(column.name) must be at least \(minLength) characters"
            }
            if let maxLength = column.maxLength, strValue.count > maxLength {
                return "\(column.name) must be \(maxLength) characters or less"
            }
        }
        
        // Integer validation
        if column.swiftType == .integer {
            if let intValue = value as? Int {
                if let intMin = column.intMin, intValue < intMin {
                    return "\(column.name) must be at least \(intMin)"
                }
                if let intMax = column.intMax, intValue > intMax {
                    return "\(column.name) must be \(intMax) or less"
                }
            } else if let strValue = value as? String, !strValue.isEmpty {
                if Int(strValue) == nil {
                    return "\(column.name) must be a valid number"
                }
            }
        }
        
        // Double validation
        if column.swiftType == .double {
            if let doubleValue = value as? Double {
                if let min = column.minimum, doubleValue < min {
                    return "\(column.name) must be at least \(min)"
                }
                if let max = column.maximum, doubleValue > max {
                    return "\(column.name) must be \(max) or less"
                }
            }
        }
        
        // Custom validation
        if let customValidation = column.customValidation {
            if !customValidation.1(value) {
                return customValidation.0
            }
        }
        
        return nil
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
    
    // MARK: - Submission
    
    public func submit(handler: @escaping (Values) -> Void) {
        guard validate() else { return }
        
        isSubmitting = true
        handler(values)
        isSubmitting = false
    }
    
    public func submit(handler: @escaping (Values) async throws -> Void) async throws {
        guard validate() else { return }
        
        isSubmitting = true
        do {
            try await handler(values)
            isSubmitting = false
        } catch {
            isSubmitting = false
            throw error
        }
    }
    
    public func submit() -> Result<Values, FormErrors> {
        guard validate() else {
            return .failure(errors)
        }
        return .success(values)
    }
    
    public func handleSubmit(handler: @escaping (Values) -> Void) {
        submit(handler: handler)
    }
    
    public func handleSubmit(handler: @escaping (Values) async throws -> Void) async throws {
        try await submit(handler: handler)
    }
    
    // MARK: - Field Watching
    
    public func watch(_ field: String) -> Any? {
        return getValue(for: field)
    }
    
    public func watch(_ fields: [String]) -> [String: Any?] {
        var result: [String: Any?] = [:]
        for field in fields {
            result[field] = watch(field)
        }
        return result
    }
    
    public func watchAll() -> [String: Any?] {
        var result: [String: Any?] = [:]
        for column in schema.columns {
            result[column.name] = watch(column.name)
        }
        return result
    }
    
    public func shouldShow(_ field: String) -> Bool {
        return visibilityRules.shouldShow(field) && visibleFields.contains(field)
    }
    
    // MARK: - PowerSync Integration
    
    public func loadFromPowerSync(
        recordId: String,
        service: ZyraSync,
        fields: [String]? = nil
    ) async throws {
        let config = schema.toTableFieldConfig()
        let fieldsToLoad = fields ?? config.allFields
        
        try await service.loadRecords(
            fields: fieldsToLoad,
            whereClause: "id = ?",
            parameters: [recordId],
            orderBy: config.defaultOrderBy,
            encryptedFields: config.encryptedFields,
            integerFields: config.integerFields,
            booleanFields: config.booleanFields
        )
        
        guard let record = service.records.first else {
            throw NSError(domain: "ZyraForm", code: 404, userInfo: [NSLocalizedDescriptionKey: "Record not found"])
        }
        
        loadFromRecord(record)
    }
    
    public func loadFromPowerSync(
        recordId: String,
        tableName: String,
        userId: String,
        database: PowerSync.PowerSyncDatabaseProtocol,
        fields: [String]? = nil
    ) async throws {
        let service = ZyraSync(tableName: tableName, userId: userId, database: database)
        try await loadFromPowerSync(recordId: recordId, service: service, fields: fields)
    }
    
    public func loadFromRecord(_ record: [String: Any]) {
        var dict: [String: Any] = [:]
        
        for column in schema.columns {
            if let value = record[column.name] {
                dict[column.name] = value
            }
        }
        
        setValues(dict)
        isDirty = false
    }
    
    // MARK: - Form Actions
    
    public func reset() {
        values = initialValues
        errors.clear()
        isDirty = false
        isValid = false
        touchedFields.removeAll()
        blurredFields.removeAll()
        updateVisibleFields()
        validate()
    }
    
    public func reset(to newValues: Values) {
        initialValues = newValues
        values = newValues
        errors.clear()
        isDirty = false
        isValid = false
        touchedFields.removeAll()
        blurredFields.removeAll()
        updateVisibleFields()
        validate()
    }
    
    public func handleBlur(_ field: String) {
        blurredFields.insert(field)
        touchedFields.insert(field)
        
        if validationMode == .onBlur || validationMode == .onTouched {
            validateField(field)
        }
    }
    
    // MARK: - Error Checking
    
    public func hasError(_ field: String) -> Bool {
        return errors.hasError(field)
    }
    
    public func getError(_ field: String) -> String? {
        return errors.getError(field)
    }
    
    public func isTouched(_ field: String) -> Bool {
        return touchedFields.contains(field)
    }
    
    public func isBlurred(_ field: String) -> Bool {
        return blurredFields.contains(field)
    }
    
    // MARK: - Private Helpers
    
    private func updateVisibleFields() {
        var visible: Set<String> = []
        for column in schema.columns {
            if visibilityRules.shouldShow(column.name) {
                visible.insert(column.name)
            }
        }
        visibleFields = visible
    }
}

// MARK: - FormValues Extension

extension FormValues {
    public mutating func update(from dictionary: [String: Any]) {
        // Default implementation: Try to decode from dictionary
        // Subclasses should override this for proper type conversion
        if let data = try? JSONSerialization.data(withJSONObject: dictionary),
           let decoded = try? JSONDecoder().decode(Self.self, from: data) {
            self = decoded
        }
    }
}

