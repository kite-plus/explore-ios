import SwiftUI

/// Reports a blog or a post to Explore's maintainers.
struct ReportView: View {
    let target: ReportTarget

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""
    @State private var working = false
    @State private var error: String?

    private var trimmed: String { reason.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        if let title = target.entryTitle {
                            Text(title)
                                .font(.headline)
                        }
                        Text(target.blogName)
                            .font(target.entryTitle == nil ? .headline : .subheadline)
                            .foregroundStyle(target.entryTitle == nil ? .primary : .secondary)
                        Text(target.blogHost)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(target.entryID == nil ? "Blog" : "Post")
                }

                Section {
                    TextField("Explain why this needs review", text: $reason, axis: .vertical)
                        .lineLimit(4...10)
                } header: {
                    Text("What happened?")
                } footer: {
                    Text("Maintainers review every report. It is kept with your account so they can follow up.")
                }

                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Report a Problem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm, action: send)
                        .disabled(trimmed.count < 5 || trimmed.count > 1000 || working)
                }
            }
        }
    }

    private func send() {
        working = true
        error = nil
        Task {
            defer { working = false }
            do {
                try await app.client.report(blogHost: target.blogHost, entryID: target.entryID, reason: trimmed)
                app.showToast(String(localized: "Report sent for review"), systemImage: "flag.fill")
                dismiss()
            } catch {
                app.handleAuthError(error)
                self.error = error.readableMessage
            }
        }
    }
}
