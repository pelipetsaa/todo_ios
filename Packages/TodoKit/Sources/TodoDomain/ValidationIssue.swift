import Foundation

public enum ValidationIssue: Error, Equatable, Sendable {
    case emailBlank, emailInvalid, passwordBlank, passwordTooShort, passwordTooLong, passwordMismatch
    case titleBlank, titleTooLong, descriptionTooLong
}

public struct ValidationFailure: Error, Equatable, Sendable {
    public let issues: [ValidationIssue]
    public init(issues: [ValidationIssue]) { self.issues = issues }
}
