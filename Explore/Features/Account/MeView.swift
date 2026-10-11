import AuthenticationServices
import SwiftUI

/// The reader's corner: account, contributions, reading preferences and
/// what Explore offers to take away.
struct MeView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @AppStorage(Preferences.openInSafari) private var openInSafari = false
    @AppStorage(Preferences.readerMode) private var readerMode = false
    @AppStorage(Preferences.handoff) private var showsHandoff = true
    @AppStorage(Preferences.dimsRead) private var dimsRead = true
    @State private var editingName = false
    @State private var changingPassword = false
    @State private var deletingAccount = false
    @State private var confirmingSignOut = false
    @State private var switchingAccount = false

    var body: some View {
        ExploreStack(tab: .me) {
            List {
                Section {
                    ProfileHeader()
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                if app.user?.temporaryPassword == true {
                    Section {
                        Button {
                            changingPassword = true
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Change Your Temporary Password")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.primary)
                                    Text("An admin reset your password. Choose a new one only you know.")
                                        .font(.footnote)
                                        .foregroundStyle(Color.secondary)
                                }
                            } icon: {
                                Image(systemName: "exclamationmark.lock.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }

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
                        // An account that signs in with Kite Plus has no password here.
                        if app.user?.passwordLogin != false {
                            Button {
                                changingPassword = true
                            } label: {
                                SettingsLabel("Change Password", symbol: "key.fill")
                            }
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
                    Toggle(isOn: $showsHandoff) {
                        SettingsLabel("Show Transition Page", symbol: "arrow.up.forward")
                    }
                    Toggle(isOn: $dimsRead) {
                        SettingsLabel("Dim Posts You've Read", symbol: "text.badge.checkmark")
                    }
                    .onChange(of: dimsRead) { _, on in
                        if !on { app.forgetReadPosts() }
                    }
                } header: {
                    Text("Reading")
                } footer: {
                    Text("Posts always open on the author's own site. Explore adds only utm_source, so authors can tell the visit came from Explore. Which posts you've read is kept only on this device; turning dimming off forgets them.")
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
                        if app.kitePlus != nil {
                            Button(action: switchAccount) {
                                HStack {
                                    Text("Use Another Account")
                                    if switchingAccount {
                                        Spacer()
                                        ProgressView()
                                    }
                                }
                            }
                            .disabled(switchingAccount)
                        }
                        Button("Sign Out", role: .destructive) {
                            confirmingSignOut = true
                        }
                    }
                    Section {
                        Button("Delete Account", role: .destructive) {
                            deletingAccount = true
                        }
                        if let accountURL = kitePlusAccountURL {
                            Button("Delete Kite Plus Account", role: .destructive) {
                                LinkOpener.open(accountURL)
                            }
                        }
                    } footer: {
                        if kitePlusAccountURL != nil {
                            Text("Delete Account deletes your account on Explore. Your Kite Plus account works across Kite Plus services; delete it on its account page and your Explore account goes with it.")
                        }
                    }
                }

                Section {
                    VStack(spacing: 6) {
                        Text(verbatim: "Kite \(Bundle.main.marketingVersion)")
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
            } message: {
                // Signing out leaves Kite Plus signed in, as on the website.
                if app.kitePlus != nil, app.user?.isLinkedToKitePlus == true {
                    Text("You stay signed in to Kite Plus, so signing in again brings back this account. Use Another Account picks a different one.")
                }
            }
        }
    }

    /// Where a reader signed in with Kite Plus deletes that account, which
    /// then deletes the one on Explore.
    private var kitePlusAccountURL: URL? {
        guard let kitePlus = app.kitePlus, app.user?.isLinkedToKitePlus == true else { return nil }
        return URL(string: kitePlus.accountURL)
    }

    private func switchAccount() {
        guard !switchingAccount else { return }
        switchingAccount = true
        Task {
            defer { switchingAccount = false }
            do {
                try await app.signInWithKitePlus(switchAccount: true, using: webAuthenticationSession)
                if let name = app.user?.displayName {
                    app.showToast(String(localized: "Signed in as \(name)"), systemImage: "person.crop.circle.badge.checkmark")
                }
            } catch {
                app.showError(error)
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
                if user.isAdmin || user.isLinkedToKitePlus {
                    HStack(spacing: 8) {
                        if user.isLinkedToKitePlus {
                            Pill(text: String(localized: "Kite Plus Account"), systemImage: "person.badge.key.fill")
                        }
                        if user.isAdmin {
                            Pill(text: String(localized: "Admin"), systemImage: "shield.lefthalf.filled")
                        }
                    }
                }
            } else {
                MarkTile(size: 76)
                VStack(spacing: 6) {
                    Text(verbatim: "Kite")
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
                        if app.canRegister {
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
