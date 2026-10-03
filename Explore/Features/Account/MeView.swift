import SwiftUI

/// The reader's corner: account, contributions, reading preferences and
/// what Explore offers to take away.
struct MeView: View {
    @Environment(AppModel.self) private var app
    @AppStorage(Preferences.openInSafari) private var openInSafari = false
    @AppStorage(Preferences.readerMode) private var readerMode = false
    @State private var editingName = false
    @State private var changingPassword = false
    @State private var deletingAccount = false
    @State private var confirmingSignOut = false

    var body: some View {
        ExploreStack(tab: .me) {
            List {
                Section {
                    ProfileHeader()
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                if app.isSignedIn {
                    Section("Account") {
                        NavigationLink(value: Route.subscriptions) {
                            SettingsLabel("Following", symbol: "heart.fill")
                        }
                        .badge(app.followedHosts.count)
                        NavigationLink(value: Route.ownedBlogs) {
                            SettingsLabel("My Blogs", symbol: "checkmark.seal.fill")
                        }
                        Button {
                            editingName = true
                        } label: {
                            SettingsLabel("Change Name", symbol: "person.text.rectangle")
                        }
                        Button {
                            changingPassword = true
                        } label: {
                            SettingsLabel("Change Password", symbol: "key.fill")
                        }
                    }
                }

                Section {
                    Button {
                        app.sheet = .submit
                    } label: {
                        SettingsLabel("Submit a Blog", symbol: "plus.app.fill")
                    }
                    NavigationLink(value: Route.submissions) {
                        SettingsLabel("My Submissions", symbol: "tray.full.fill")
                    }
                    .badge(app.submissionIDs.count)
                } header: {
                    Text("Contribute")
                } footer: {
                    Text("Explore lists personal and independent blogs with a working RSS, Atom or JSON Feed, updated within the last 12 months.")
                }

                Section {
                    Toggle(isOn: $openInSafari) {
                        SettingsLabel("Open Links in Safari", symbol: "safari.fill")
                    }
                    Toggle(isOn: $readerMode) {
                        SettingsLabel("Use Reader When Available", symbol: "doc.plaintext.fill")
                    }
                    .disabled(openInSafari)
                } header: {
                    Text("Reading")
                } footer: {
                    Text("Posts always open on the author's own site. Explore adds only utm_source, so authors can tell the visit came from Explore.")
                }

                Section("Explore") {
                    NavigationLink(value: Route.about) {
                        SettingsLabel("About Explore", symbol: "info.circle.fill")
                    }
                    ShareLink(item: app.client.feedURL) {
                        SettingsLabel("Explore's RSS Feed", symbol: "dot.radiowaves.up.forward")
                    }
                    ShareLink(item: app.client.opmlURL) {
                        SettingsLabel("Export Every Blog as OPML", symbol: "square.and.arrow.up.on.square.fill")
                    }
                    NavigationLink(value: Route.server) {
                        LabeledContent {
                            Text(app.server.host() ?? app.server.absoluteString)
                                .lineLimit(1)
                        } label: {
                            SettingsLabel("Server", symbol: "server.rack")
                        }
                    }
                }

                if app.isSignedIn {
                    Section {
                        Button("Sign Out", role: .destructive) {
                            confirmingSignOut = true
                        }
                        Button("Delete Account", role: .destructive) {
                            deletingAccount = true
                        }
                    }
                }

                Section {
                    VStack(spacing: 6) {
                        Text("Explore \(Bundle.main.marketingVersion)")
                            .font(.footnote.weight(.semibold))
                        Text("Explore keeps no post content and does not track readers.")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Me")
            .sheet(isPresented: $editingName) { EditNameView() }
            .sheet(isPresented: $changingPassword) { ChangePasswordView() }
            .sheet(isPresented: $deletingAccount) { DeleteAccountView() }
            .confirmationDialog("Sign out of Explore?", isPresented: $confirmingSignOut, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    Task { await app.signOut() }
                }
            }
        }
    }
}

/// A settings row label with its icon on a plain gray square.
struct SettingsLabel: View {
    let title: LocalizedStringKey
    let symbol: String

    init(_ title: LocalizedStringKey, symbol: String) {
        self.title = title
        self.symbol = symbol
    }

    var body: some View {
        Label {
            Text(title)
                .foregroundStyle(Color.primary)
        } icon: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.primary)
                .frame(width: 29, height: 29)
                .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 7, style: .continuous))
        }
    }
}

private struct ProfileHeader: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(spacing: 14) {
            if let user = app.user {
                Text(Palette.initial(of: user.displayName))
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 84, height: 84)
                    .glassEffect(.regular, in: .circle)
                VStack(spacing: 4) {
                    Text(user.displayName)
                        .font(.title2.bold())
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if user.isAdmin {
                    Pill(text: String(localized: "Admin"), systemImage: "shield.lefthalf.filled")
                }
            } else {
                GlassMark(size: 76)
                VStack(spacing: 6) {
                    Text("Explore")
                        .font(.title2.bold())
                    Text("Read everything without an account. Sign in to follow blogs and claim your own.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                GlassEffectContainer(spacing: 10) {
                    VStack(spacing: 10) {
                        Button {
                            app.sheet = .signIn(.signIn)
                        } label: {
                            Text("Sign In")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.primaryAction)
                        if app.registrationEnabled {
                            Button {
                                app.sheet = .signIn(.register)
                            } label: {
                                Text("Create Account")
                                    .font(.headline)
                                    .foregroundStyle(Color.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .controlSize(.large)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 30, style: .continuous))
    }
}

extension Bundle {
    var marketingVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }
}
