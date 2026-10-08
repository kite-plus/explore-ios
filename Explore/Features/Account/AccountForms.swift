import SwiftUI

struct EditNameView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var working = false
    @State private var error: String?

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textContentType(.nickname)
                        .submitLabel(.done)
                        .onSubmit(save)
                } footer: {
                    Text("Shown on your account. Up to 80 characters.")
                }
                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Change Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm, action: save)
                        .disabled(trimmed.isEmpty || trimmed.count > 80 || working)
                }
            }
            .onAppear { name = app.user?.displayName ?? "" }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        guard !trimmed.isEmpty, trimmed.count <= 80, !working else { return }
        working = true
        Task {
            defer { working = false }
            do {
                try await app.updateName(trimmed)
                app.showToast(String(localized: "Name updated"))
                dismiss()
            } catch {
                app.handleAuthError(error)
                self.error = error.readableMessage
            }
        }
    }
}

struct ChangePasswordView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    /// Right after signing in with a password an admin reset, that password,
    /// so the reader only chooses the new one.
    private let signedInWith: String?
    @State private var current: String
    @State private var new = ""
    @State private var confirmation = ""
    @State private var working = false
    @State private var error: String?

    init(signedInWith: String? = nil) {
        self.signedInWith = signedInWith
        _current = State(initialValue: signedInWith ?? "")
    }

    private var isTemporary: Bool { app.user?.temporaryPassword == true }

    var body: some View {
        NavigationStack {
            Form {
                if isTemporary {
                    Section {
                        Label {
                            Text("An admin reset your password. Choose a new one only you know.")
                        } icon: {
                            Image(systemName: "exclamationmark.lock.fill")
                                .foregroundStyle(.orange)
                        }
                        .font(.subheadline)
                    }
                }
                if signedInWith == nil {
                    Section {
                        SecureField(isTemporary ? "Temporary password" : "Current password", text: $current)
                            .textContentType(.password)
                    }
                }
                Section {
                    SecureField("New password", text: $new)
                        .textContentType(.newPassword)
                    SecureField("Confirm new password", text: $confirmation)
                        .textContentType(.newPassword)
                } footer: {
                    Text("Use 12 to 72 characters. Your other devices will be signed out; this one stays signed in.")
                }
                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm, action: save)
                        .disabled(current.isEmpty || new.isEmpty || working)
                }
            }
        }
    }

    private func save() {
        let bytes = new.utf8.count
        if bytes < 12 {
            error = String(localized: "Use at least 12 characters for the password.")
            return
        }
        if bytes > 72 {
            error = String(localized: "The password is too long.")
            return
        }
        if new != confirmation {
            error = String(localized: "The passwords don't match.")
            return
        }
        working = true
        error = nil
        Task {
            defer { working = false }
            do {
                try await app.changePassword(current: current, new: new)
                app.showToast(String(localized: "Password changed"), systemImage: "key.fill")
                dismiss()
            } catch {
                app.handleAuthError(error)
                if (error as? APIError)?.code == "wrong_password" {
                    self.error = String(localized: "The current password is incorrect.")
                } else {
                    self.error = error.readableMessage
                }
            }
        }
    }
}

struct DeleteAccountView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var typedEmail = ""
    @State private var working = false
    @State private var error: String?

    private var email: String { app.user?.email ?? "" }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "person.crop.circle.badge.xmark")
                            .font(.system(size: 40))
                            .foregroundStyle(.red)
                            .symbolRenderingMode(.hierarchical)
                        Text("Your account, its sign-ins, the blogs you follow and the blogs you claimed are deleted right away. Reports you filed stay, no longer linked to you.")
                            .font(.subheadline)
                    }
                    .padding(.vertical, 6)
                }
                Section {
                    TextField(email, text: $typedEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Type your email to confirm")
                }
                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
                Section {
                    Button(role: .destructive, action: delete) {
                        HStack {
                            if working { ProgressView() }
                            Text("Delete Account")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(typedEmail.trimmingCharacters(in: .whitespaces).lowercased() != email.lowercased() || working)
                }
            }
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
    }

    private func delete() {
        working = true
        error = nil
        Task {
            defer { working = false }
            do {
                try await app.deleteAccount()
                app.showToast(String(localized: "Account deleted"), systemImage: "trash.fill")
                dismiss()
            } catch {
                app.handleAuthError(error)
                self.error = error.readableMessage
            }
        }
    }
}
