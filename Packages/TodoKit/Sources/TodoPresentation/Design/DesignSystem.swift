#if os(iOS)
import SwiftUI
import TodoDomain
import TodoApplication

func localized(_ key: String) -> String { String(localized: String.LocalizationValue(key)) }

extension TodoStatus {
    var color: Color {
        switch self { case .todo: .secondary; case .inProgress: .accentColor; case .done: .teal }
    }
}

struct StatusBadge: View {
    let status: TodoStatus
    var body: some View {
        Text(localized(status.titleKey))
            .font(.caption.weight(.medium))
            .foregroundStyle(status.color)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(status.color.opacity(0.15), in: Capsule())
            .fixedSize(horizontal: true, vertical: false)
    }
}

struct ErrorNotice: View {
    let message: String
    var body: some View {
        Text(localized(message))
            .font(.subheadline).foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("errorNotice")
    }
}

struct PrimaryButton: View {
    let title: String
    var busy = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                Text(localized(title)).opacity(busy ? 0 : 1)
                if busy { ProgressView().tint(.white) }
            }.frame(maxWidth: .infinity, minHeight: 22)
        }
        .buttonStyle(.borderedProminent).controlSize(.large)
        .disabled(busy)
    }
}

struct InputField<Content: View>: View {
    let title: String
    var error: String?
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localized(title)).font(.subheadline).foregroundStyle(.secondary)
            content().textFieldStyle(.roundedBorder).accessibilityLabel(localized(title))
            FieldError(message: error)
        }
    }
}

struct FieldError: View {
    let message: String?
    var body: some View {
        if let message {
            Text(localized(message)).font(.caption).foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
#endif
