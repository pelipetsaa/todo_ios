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
            VStack(alignment: .leading, spacing: 28) {
                header
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Email").font(.subheadline.weight(.medium))
                        TextField("you@example.com", text: $model.email)
                            .textContentType(.emailAddress).keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .focused($focused, equals: .email).submitLabel(.next)
                            .onSubmit { focused = .password }
                            .accessibilityIdentifier("emailField")
                            .authField()
                        FieldError(message: model.emailError)
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Password").font(.subheadline.weight(.medium))
                        SecureField("Password", text: $model.password)
                            .textContentType(model.registration ? .newPassword : .password)
                            .focused($focused, equals: .password)
                            .submitLabel(model.registration ? .next : .go)
                            .onSubmit { if model.registration { focused = .confirmation } else { submit() } }
                            .accessibilityIdentifier("passwordField")
                            .authField()
                        FieldError(message: model.passwordError)
                    }
                    if model.registration {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Confirm password").font(.subheadline.weight(.medium))
                            SecureField("Confirm password", text: $model.confirmation)
                                .textContentType(.newPassword).focused($focused, equals: .confirmation)
                                .submitLabel(.go).onSubmit(submit)
                                .accessibilityIdentifier("confirmationField")
                                .authField()
                            FieldError(message: model.confirmationError)
                        }
                    }
                    if let error = model.error { ErrorNotice(message: error) }
                    PrimaryButton(title: model.registration ? "Create account" : "Sign in", busy: model.isBusy && !model.isGoogleBusy, action: submit)
                        .accessibilityIdentifier("submitAuth")
                    if !model.registration {
                        HStack(spacing: 12) {
                            Rectangle().frame(height: 1).foregroundStyle(.quaternary)
                            Text("or").font(.caption).foregroundStyle(.secondary)
                            Rectangle().frame(height: 1).foregroundStyle(.quaternary)
                        }
                        if model.isGoogleBusy { ProgressView().frame(height: 44) }
                        else {
                            googleButton {
                                focused = nil
                                Task { await model.google() }
                            }.frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                }.disabled(model.isBusy)
                if !model.registration {
                    NavigationLink {
                        AuthView(useCases: useCases, registration: true, googleButton: googleButton)
                    } label: {
                        Text("New here? Create an account").font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }.disabled(model.isBusy).accessibilityIdentifier("registerLink")
                }
            }
            .padding(28)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(model.registration ? localized("Create account") : "")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "checklist")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 20))
                .accessibilityHidden(true)
                .padding(.bottom, 10)
            Text(model.registration ? "Make room for what matters." : "Your day,\na little clearer.")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
            Text(model.registration ? "Create an account to keep your tasks together. Use a password with at least 8 characters." : "Sign in to plan your time and keep things moving.")
                .font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(.top, 26)
    }

    private func submit() { focused = nil; Task { await model.submit() } }
}

private extension View {
    func authField() -> some View {
        padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.primary.opacity(0.06)))
    }
}

#endif
