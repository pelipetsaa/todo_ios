#if os(iOS)
import SwiftUI
import TodoDomain
import TodoApplication

struct AuthView: View {
    @State private var model: AuthViewModel
    @FocusState private var focused: Field?
    private enum Field { case email, password, confirmation }
    private let useCases: AuthUseCases
    private let googleButton: GoogleButtonBuilder

    init(useCases: AuthUseCases, registration: Bool = false, googleButton: @escaping GoogleButtonBuilder) {
        self.useCases = useCases
        self.googleButton = googleButton
        _model = State(initialValue: AuthViewModel(useCases: useCases, registration: registration))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.registration ? localized("Registration") : localized("Login"))
                        .font(.title)
                    Text(model.registration
                         ? localized("Use your email and a password with at least 8 characters.")
                         : localized("Welcome back! Sign in to see your todos."))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                InputField(title: "Email", error: model.emailError) {
                    TextField("Email", text: $model.email, prompt: Text(""))
                        .textContentType(.emailAddress).keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .focused($focused, equals: .email).submitLabel(.next)
                        .onSubmit { focused = .password }
                        .accessibilityIdentifier("emailField")
                }
                InputField(title: "Password", error: model.passwordError) {
                    SecureField("Password", text: $model.password, prompt: Text(""))
                        .textContentType(model.registration ? .newPassword : .password)
                        .focused($focused, equals: .password)
                        .submitLabel(model.registration ? .next : .go)
                        .onSubmit { if model.registration { focused = .confirmation } else { submit() } }
                        .accessibilityIdentifier("passwordField")
                        .id(Field.password)

                }
                if model.registration {
                    InputField(title: "Confirm password", error: model.confirmationError) {
                        SecureField("Confirm password", text: $model.confirmation, prompt: Text(""))
                            .textContentType(.newPassword).focused($focused, equals: .confirmation)
                            .submitLabel(.go).onSubmit(submit)
                            .accessibilityIdentifier("confirmationField")
                            .id(Field.confirmation)

                    }
                }
                if let error = model.error { ErrorNotice(message: error) }
                PrimaryButton(title: model.registration ? "Create account" : "Sign in",
                              busy: model.isBusy && !model.isGoogleBusy, action: submit)
                    .accessibilityIdentifier("submitAuth")
                if !model.registration {
                    HStack(spacing: 12) {
                        Rectangle().frame(height: 1).foregroundStyle(.quaternary)
                        Text("or").font(.caption).foregroundStyle(.secondary)
                        Rectangle().frame(height: 1).foregroundStyle(.quaternary)
                    }
                    if model.isGoogleBusy {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 52)
                    } else {
                        googleButton {
                            focused = nil
                            Task { await model.google() }
                        }
                    }
                    NavigationLink {
                        AuthView(useCases: useCases, registration: true, googleButton: googleButton)
                    } label: {
                        Text("No account yet? Create one").frame(maxWidth: .infinity, minHeight: 44)
                    }.accessibilityIdentifier("registerLink")
                }
            }
            .disabled(model.isBusy)
            .frame(maxWidth: 432)
            .padding(.horizontal, 24).padding(.vertical, 32)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemBackground))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(model.registration ? .visible : .hidden, for: .navigationBar)
        .scrollDismissesKeyboard(.interactively)
    }

    private func submit() { focused = nil; Task { await model.submit() } }
}
#endif
