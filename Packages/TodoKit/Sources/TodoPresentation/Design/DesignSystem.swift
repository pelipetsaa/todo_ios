#if os(iOS)
import SwiftUI
import TodoDomain
import TodoApplication

func localized(_ key: String) -> String { String(localized: String.LocalizationValue(key)) }

extension TodoStatus {
    var color: Color {
        switch self { case .todo: .secondary; case .inProgress: .indigo; case .done: .teal }
    }
    var symbol: String {
        switch self { case .todo: "circle"; case .inProgress: "circle.lefthalf.filled"; case .done: "checkmark.circle.fill" }
    }
}

struct StatusBadge: View {
    let status: TodoStatus
    var body: some View {
        Label(localized(status.titleKey), systemImage: status.symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(status.color)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(status.color.opacity(0.10), in: Capsule())
    }
}

struct ErrorNotice: View {
    let message: String
    var body: some View {
        Label(localized(message), systemImage: "exclamationmark.circle.fill")
            .font(.subheadline)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.red.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityIdentifier("errorNotice")
    }
}

struct PrimaryButton: View {
    let title: String
    var busy = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if busy { ProgressView().tint(.white) }
                Text(localized(title)).fontWeight(.semibold)
            }.frame(maxWidth: .infinity).padding(.vertical, 9)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .disabled(busy)
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
