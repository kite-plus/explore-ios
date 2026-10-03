import SwiftUI

/// Claims a blog by publishing a DNS TXT record Explore asks for.
struct ClaimBlogView: View {
    let blog: BlogRef

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var challenge: ClaimChallenge?
    @State private var expiresAt: Date?
    @State private var working = false
    @State private var error: String?
    @State private var claimed = false

    var body: some View {
        NavigationStack {
            Group {
                if claimed {
                    success
                } else {
                    form
                }
            }
            .navigationTitle("Claim Blog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
    }

    private var form: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    BlogAvatar(host: blog.host, name: blog.name, size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(blog.name)
                            .font(.headline)
                        Text(blog.host)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("Prove you run this blog by adding a TXT record to its domain. Explore checks the record once, then you can remove it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let challenge {
                Section {
                    LabeledContent("Type", value: "TXT")
                    CopyRow(title: "Name", value: challenge.record)
                    CopyRow(title: "Value", value: challenge.value)
                } header: {
                    Text("Add This DNS Record")
                } footer: {
                    if let expiresAt {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let remaining = max(0, Int(expiresAt.timeIntervalSince(context.date)))
                            if remaining > 0 {
                                Text("The record is valid for \(remaining / 60):\(String(format: "%02d", remaining % 60)). DNS changes can take a few minutes to appear.")
                            } else {
                                Text("This record has expired. Create a new one.")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
                Section {
                    Button(action: verify) {
                        HStack {
                            if working { ProgressView() }
                            Text("Verify Record")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(working)
                    Button("Create a New Record", action: start)
                        .disabled(working)
                }
            } else {
                Section {
                    Button(action: start) {
                        HStack {
                            if working { ProgressView() }
                            Text("Create Verification Record")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(working)
                }
            }

            if let error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var success: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.teal)
                .symbolEffect(.bounce, value: claimed)
            Text("Blog Claimed")
                .font(.title.bold())
            Text("\(blog.name) is now linked to your account. You can remove the DNS record.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Done") { dismiss() }
                .buttonStyle(.primaryAction)
                .controlSize(.large)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func start() {
        working = true
        error = nil
        Task {
            defer { working = false }
            do {
                let challenge = try await app.client.startClaim(host: blog.host)
                withAnimation {
                    self.challenge = challenge
                    expiresAt = .now.addingTimeInterval(TimeInterval(challenge.expiresInSeconds))
                }
            } catch {
                app.handleAuthError(error)
                self.error = message(for: error)
            }
        }
    }

    private func verify() {
        working = true
        error = nil
        Task {
            defer { working = false }
            do {
                try await app.client.verifyClaim(host: blog.host)
                withAnimation(.bouncy) { claimed = true }
            } catch {
                app.handleAuthError(error)
                self.error = message(for: error)
            }
        }
    }

    private func message(for error: Error) -> String {
        switch (error as? APIError)?.code {
        case "verification_failed":
            String(localized: "The record wasn't found yet. DNS changes can take a few minutes; try again shortly.")
        case "conflict":
            String(localized: "Someone has already claimed this blog.")
        case "not_found":
            String(localized: "The verification record expired. Create a new one.")
        default:
            error.readableMessage
        }
    }
}

/// A value with a button that copies it.
struct CopyRow: View {
    let title: LocalizedStringKey
    let value: String

    @Environment(AppModel.self) private var app

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
            Button {
                UIPasteboard.general.string = value
                app.showToast(String(localized: "Copied"), systemImage: "doc.on.doc.fill")
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text("Copy"))
        }
    }
}
