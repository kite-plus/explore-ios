import SwiftUI

/// New posts from the blogs the reader follows. Following needs an account;
/// everything else in the app works without one.
struct FollowingView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("following.language") private var language: LanguageFilter = .all
    @State private var tag: String?
    @State private var feed = FeedModel(source: .following)

    var body: some View {
        ExploreStack(tab: .following) {
            Group {
                if app.isSignedIn {
                    stream
                } else if app.isRestoringSession {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGroupedBackground))
                } else {
                    FollowingWelcome()
                }
            }
            .navigationTitle("Following")
            .navigationSubtitle(app.isSignedIn ? Text("Posts from the blogs you follow") : Text(verbatim: ""))
        }
    }

    private var stream: some View {
        EntryList(feed: feed, endText: "That's everything from the blogs you follow") {
            EmptyView()
        } pinned: {
            FeedFilterBar(language: $language, tag: $tag)
        } empty: {
            if app.followedHosts.isEmpty {
                ContentUnavailableView {
                    Label("Not Following Any Blogs", systemImage: "heart.text.square")
                } description: {
                    Text("Follow blogs from the directory and their new posts gather here.")
                } actions: {
                    Button {
                        app.tab = .blogs
                    } label: {
                        Text("Browse Blogs")
                    }
                    .buttonStyle(.primaryAction)
                }
                .padding(.vertical, 40)
            } else {
                ContentUnavailableView {
                    Label("No Posts", systemImage: "tray")
                } description: {
                    Text("The blogs you follow have no posts that match.")
                }
                .padding(.vertical, 40)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Route.subscriptions) {
                    Label("Manage", systemImage: "list.bullet")
                }
            }
        }
        .refreshable {
            await app.loadFollows()
            await feed.load(using: app.client, fresh: true)
        }
        .task(id: "\(language.rawValue)|\(tag ?? "")|\(app.generation)") {
            feed.language = language
            feed.tag = tag
            feed.version = app.generation
            await feed.refreshIfNeeded(using: app.client)
            if let error = feed.lastError {
                app.handleAuthError(error)
            }
        }
    }
}

/// The Following tab before signing in, kept plain: grays, an uncolored
/// glass disc and a black or white button, whatever the appearance.
private struct FollowingWelcome: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 104, height: 104)
                    .glassEffect(.regular, in: .circle)

                VStack(spacing: 10) {
                    Text("Follow the Blogs You Love")
                        .font(.title2.bold())
                    Text("Sign in to follow blogs and read their new posts in one stream. Reading everything else needs no account.")
                        .font(.body)
                        .foregroundStyle(Color.secondary)
                }
                .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    Button {
                        app.sheet = .signIn(.signIn)
                    } label: {
                        Text("Sign In")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primaryAction)
                    .controlSize(.extraLarge)

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
                        .controlSize(.large)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 56)
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color(.systemGroupedBackground))
    }
}
