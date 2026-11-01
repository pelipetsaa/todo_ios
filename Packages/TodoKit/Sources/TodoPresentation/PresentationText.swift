import Foundation
import TodoDomain

public extension AppError {
    var messageKey: String {
        switch self {
        case .invalidCredentials: "Incorrect email or password."
        case .sessionExpired: "Your session has expired. Please sign in again."
        case .emailTaken: "An account with this email already exists."
        case .notFound: "This task no longer exists."
        case .validation: "Please check the entered information."
        case .rateLimited: "Too many attempts. Please wait a minute and try again."
        case .network: "Cannot reach the server. Check your connection and try again."
        case .server: "The server is temporarily unavailable. Please try again."
        case .invalidResponse: "The server returned an unexpected response."
        case .secureStorage: "Cannot access secure storage. Please restart the app and try again."
        case .configuration: "The app configuration is invalid. Check Configuration/Config.xcconfig."
        }
    }
}

extension TodoStatus {
    public var titleKey: String {
        switch self {
        case .todo: "To do"
        case .inProgress: "In progress"
        case .done: "Done"
        }
    }
}

extension TodoPeriod {
    public var titleKey: String {
        switch self { case .today: "Today"; case .week: "This week"; case .month: "This month" }
    }
}

extension ValidationIssue {
    var messageKey: String {
        switch self {
        case .emailBlank: "Enter your email."
        case .emailInvalid: "Enter a valid email address."
        case .passwordBlank: "Enter your password."
        case .passwordTooShort: "Use at least 8 characters."
        case .passwordTooLong: "Use no more than 128 characters."
        case .titleBlank: "Enter a task title."
        case .titleTooLong: "Use no more than 200 characters."
        case .descriptionTooLong: "Use no more than 2000 characters."
        case .passwordMismatch: "Passwords do not match."
        }
    }
}

func errorKey(_ error: Error) -> String {
    if error is ValidationFailure { return AppError.validation.messageKey }
    return (error as? AppError ?? .server).messageKey
}

extension TodoStatus {
    var identifier: String { switch self { case .todo: "TODO"; case .inProgress: "IN_PROGRESS"; case .done: "DONE" } }
}

extension TodoPeriod {
    var emptyTitleKey: String {
        switch self {
        case .today: "Nothing planned for today"
        case .week: "Nothing planned for this week"
        case .month: "Nothing planned for this month"
        }
    }
}
