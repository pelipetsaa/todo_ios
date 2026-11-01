import SwiftUI
import Observation
import TodoDomain
import TodoApplication
import TodoData
import TodoPresentation

@MainActor @Observable
private final class Bootstrap {
    var session: SessionViewModel?
    var error: String?

    func load() {
        error = nil
        do {
            #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--demo") || arguments.contains("--demo-auth") {
                let demo = DemoRepository(signedIn: arguments.contains("--demo"))
                session = SessionViewModel(auth: AuthUseCases(repository: demo, identity: GoogleSignInService()), todos: TodoUseCases(repository: demo))
                return
            }
            #endif
            guard let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
                  let url = URL(string: raw) else { throw AppError.configuration }
            #if !DEBUG
            guard url.scheme == "https" else { throw AppError.configuration }
            #endif
            let api = try APIClient(baseURL: url)
            session = SessionViewModel(auth: AuthUseCases(repository: api, identity: GoogleSignInService()), todos: TodoUseCases(repository: api))
        } catch { self.error = (error as? AppError ?? .server).messageKey }
    }
}

@main
struct ToDoApp: App {
    @State private var bootstrap = Bootstrap()
    var body: some Scene {
        WindowGroup {
            Group {
                if let session = bootstrap.session {
                    TodoRootView(session: session) { action in AnyView(PlatformGoogleButton(action: action)) }
                } else if let error = bootstrap.error {
                    ContentUnavailableView {
                        Label("Unable to start", systemImage: "exclamationmark.triangle")
                    } description: { Text(localized(error)) }
                    actions: { Button("Try again") { bootstrap.load() } }
                } else { ProgressView() }
            }
            .tint(.accentColor)
            .task { if bootstrap.session == nil { bootstrap.load() } }
            .onOpenURL { GoogleSignInService.handle($0) }
        }
    }
}

func localized(_ key: String) -> String { String(localized: String.LocalizationValue(key)) }

private struct PlatformGoogleButton: View {
    let action: @MainActor () -> Void
    var body: some View {
        Button(action: action) {
            Text("Continue with Google").frame(maxWidth: .infinity, minHeight: 22)
        }.buttonStyle(.bordered).controlSize(.large)
    }
}
