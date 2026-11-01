#if os(iOS)
import SwiftUI

/// A platform-branded control is supplied by the composition root. No Google SDK dependency enters Presentation.
public typealias GoogleButtonBuilder = @MainActor (@escaping @MainActor () -> Void) -> AnyView

public struct TodoRootView: View {
    @Bindable private var session: SessionViewModel
    private let googleButton: GoogleButtonBuilder

    public init(session: SessionViewModel, googleButton: @escaping GoogleButtonBuilder) {
        self.session = session
        self.googleButton = googleButton
    }
    public var body: some View {
        Group {
            switch session.phase {
            case .restoring: ProgressView()
            case .signedOut: NavigationStack { AuthView(useCases: session.auth, googleButton: googleButton) }
            case .signedIn: NavigationStack { TodoListView(session: session) }
            }
        }
        .task { await session.observe() }
        .alert("Something went wrong", isPresented: Binding(get: { session.error != nil }, set: { if !$0 { session.error = nil } })) {
            Button("OK") { session.error = nil }
        } message: { Text(localized(session.error ?? "")) }
    }
}
#endif
