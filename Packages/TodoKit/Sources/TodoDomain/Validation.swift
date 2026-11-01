import Foundation

public enum Validation {
    public static func email(_ value: String) -> ValidationIssue? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .emailBlank }
        if trimmed.utf16.count > 254 || trimmed.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) == nil {
            return .emailInvalid
        }
        return nil
    }

    public static func password(_ value: String, registration: Bool) -> ValidationIssue? {
        if value.isEmpty { return .passwordBlank }
        if registration && value.utf16.count < 8 { return .passwordTooShort }
        if registration && value.utf16.count > 128 { return .passwordTooLong }
        return nil
    }

    public static func confirmation(_ value: String, password: String) -> ValidationIssue? {
        value == password ? nil : .passwordMismatch
    }

    public static func title(_ value: String) -> ValidationIssue? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .titleBlank }
        if trimmed.utf16.count > 200 { return .titleTooLong }
        return nil
    }

    public static func description(_ value: String) -> ValidationIssue? {
        value.utf16.count > 2000 ? .descriptionTooLong : nil
    }
}
