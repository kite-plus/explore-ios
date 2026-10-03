import SwiftUI

/// Sign in with an Explore account, or create one. Explore asks for
/// nothing beyond an email, a name and a password.
struct SignInView: View {
    @State var mode: SignInMode

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var name = ""
    @State private var working = false
    @State private var error: String?
    @State private var showsPassword = false
    @FocusState private var focus: Field?

    private enum Field: Hashable {
        case name, email, password, confirmation
    }

    private var registering: Bool { mode == .register }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 14) {
                        GlassMark(size: 84)
                        Text(registering ? "Create Your Account" : "Welcome Back")
                            .font(.title.bold())
                            .contentTransition(.opacity)
                        Text("Follow blogs and read their new posts in one stream.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    if app.registrationEnabled {
                        Picker("Mode", selection: $mode.animation(.snappy)) {
                            Text("Sign In").tag(SignInMode.signIn)
                            Text("Create Account").tag(SignInMode.register)
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(spacing: 12) {
                        if registering {
                            field(icon: "person") {
                                TextField("Your name or nickname", text: $name)
                                    .textContentType(.nickname)
                                    .focused($focus, equals: .name)
                                    .submitLabel(.next)
                                    .onSubmit { focus = .email }
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        field(icon: "envelope") {
                            TextField("Email", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focus, equals: .email)
                                .submitLabel(.next)
                                .onSubmit { focus = .password }
                        }
                        field(icon: "lock") {
                            HStack {
                                Group {
                                    if showsPassword {
                                        TextField("Password", text: $password)
                                    } else {
                                        SecureField("Password", text: $password)
                                    }
                                }
                                .textContentType(registering ? .newPassword : .password)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focus, equals: .password)
                                .submitLabel(registering ? .next : .go)
                                .onSubmit {
                                    if registering { focus = .confirmation } else { submit() }
                                }
                                Button {
                                    showsPassword.toggle()
                                } label: {
                                    Image(systemName: showsPassword ? "eye.slash" : "eye")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(showsPassword ? Text("Hide Password") : Text("Show Password"))
                            }
                        }
                        if registering {
                            field(icon: "lock.rotation") {
                                SecureField("Confirm password", text: $confirmation)
                                    .textContentType(.newPassword)
                                    .focused($focus, equals: .confirmation)
                                    .submitLabel(.go)
                                    .onSubmit(submit)
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                            Text("Use 12 to 72 characters.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }
                    }

                    if let error {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity)
                    }

                    Button(action: submit) {
                        HStack(spacing: 8) {
                            if working {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(registering ? "Create Account" : "Sign In")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.extraLarge)
                    .disabled(working)

                    Text("Explore keeps your email, your name and a hash of your password, plus the blogs you follow. It never records what you read.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity)
                .animation(.snappy, value: mode)
                .animation(.snappy, value: error)
            }
            .scrollDismissesKeyboard(.interactively)
            .background {
                MeshBackdrop(colors: [.kite, Color(hex: 0x8B5CF6), Color(hex: 0x14B8A6)])
                    .opacity(0.35)
                    .ignoresSafeArea()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
            .onChange(of: mode) { error = nil }
        }
    }

    private func field<Content: View>(icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            content()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .background(Color(.secondarySystemGroupedBackground).opacity(0.9), in: .rect(cornerRadius: 16, style: .continuous))
    }

    private func submit() {
        guard !working else { return }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let problem = validate(email: trimmedEmail, name: trimmedName) {
            withAnimation { error = problem }
            return
        }
        focus = nil
        working = true
        error = nil
        Task {
            defer { working = false }
            do {
                if registering {
                    try await app.register(email: trimmedEmail, password: password, displayName: trimmedName)
                    app.showToast(String(localized: "Welcome to Explore, \(trimmedName)"), systemImage: "party.popper.fill")
                } else {
                    try await app.signIn(email: trimmedEmail, password: password)
                    app.showToast(String(localized: "Signed in"), systemImage: "person.crop.circle.badge.checkmark")
                }
                dismiss()
            } catch {
                withAnimation { self.error = message(for: error) }
            }
        }
    }

    private func validate(email: String, name: String) -> String? {
        if registering, name.isEmpty || name.count > 80 {
            return String(localized: "Enter a name of up to 80 characters.")
        }
        if email.isEmpty || !email.contains("@") || !email.contains(".") {
            return String(localized: "Enter a valid email address.")
        }
        if password.isEmpty {
            return String(localized: "Enter your password.")
        }
        if registering {
            let bytes = password.utf8.count
            if bytes < 12 { return String(localized: "Use at least 12 characters for the password.") }
            if bytes > 72 { return String(localized: "The password is too long.") }
            if password != confirmation { return String(localized: "The passwords don't match.") }
        }
        return nil
    }

    private func message(for error: Error) -> String {
        switch (error as? APIError)?.code {
        case "conflict": String(localized: "An account with this email already exists. Sign in instead.")
        case "feature_disabled": String(localized: "Registration is closed on this server right now.")
        case "invalid_request" where registering: String(localized: "Check the name, email and password, then try again.")
        default: error.readableMessage
        }
    }
}
