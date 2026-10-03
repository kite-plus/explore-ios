import SwiftUI

/// Points the app at another Explore server. Explore is open source and
/// anyone can run one; sign-ins are kept per server.
struct ServerView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var checking = false
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                TextField(text: $address, prompt: Text(verbatim: "https://explore.example.com")) { Text("Server Address") }
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit(connect)
            } header: {
                Text("Server Address")
            } footer: {
                Text("The app reads from explore.kite.plus unless you choose another Explore server here.")
            }

            Section {
                Button(action: connect) {
                    HStack {
                        if checking { ProgressView() }
                        Text("Connect")
                    }
                }
                .disabled(checking || address.trimmingCharacters(in: .whitespaces).isEmpty)
                if !app.isDefaultServer {
                    Button("Use explore.kite.plus") {
                        address = AppModel.defaultServer.absoluteString
                        connect()
                    }
                    .disabled(checking)
                }
            }

            if let error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Server")
        .onAppear { address = app.server.absoluteString }
    }

    private func connect() {
        let normalized = Formatting.normalizedAddress(address)
        guard var components = URLComponents(string: normalized),
              let scheme = components.scheme?.lowercased(), scheme == "https" || scheme == "http",
              components.host?.isEmpty == false
        else {
            error = String(localized: "Enter a valid http or https address.")
            return
        }
        components.query = nil
        components.fragment = nil
        while components.path.hasSuffix("/") { components.path.removeLast() }
        guard let url = components.url else { return }
        guard url != app.server else {
            dismiss()
            return
        }
        checking = true
        error = nil
        Task {
            defer { checking = false }
            do {
                _ = try await APIClient(server: url).siteConfig()
                await app.switchServer(to: url)
                app.showToast(String(localized: "Connected to \(url.host() ?? url.absoluteString)"), systemImage: "server.rack")
                dismiss()
            } catch {
                self.error = String(localized: "This address doesn't answer like an Explore server.")
            }
        }
    }
}
