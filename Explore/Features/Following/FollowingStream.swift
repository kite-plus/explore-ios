import SwiftUI

/// New posts from the blogs the reader follows, Discover's third stream.
/// Following needs an account; everything else in the app works without
/// one, so before signing in the stream invites the reader to.
struct FollowingStream: View {
    let feed: FeedModel
    let language: LanguageFilter
    let tag: String?
    var topRequest = 0

    @Environment(AppModel.self) private var app

    var body: some View {
        if app.isSignedIn {
            list
        } else if app.isRestoringSession {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
        } else {
            FollowingWelcome()
        }
    }

    private var list: some View {
        EntryList(feed: feed, endText: "That's everything from the blogs you follow", topRequest: topRequest) {
            if !app.followedHosts.isEmpty {
                FollowingHeader(count: app.followedHosts.count)
            }
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

/// How many blogs the reader follows, with the way to manage them.
private struct FollowingHeader: View {
    let count: Int

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Text("Blogs You Follow")
                Text(count, format: .number)
                    .monospacedDigit()
            }
            .foregroundStyle(.secondary)
            Spacer()
            NavigationLink(value: Route.subscriptions) {
                Text("Manage")
                    .fontWeight(.medium)
            }
        }
        .font(.subheadline)
        .padding(.top, 12)
    }
}

/// The Following stream before signing in, kept plain: grays, an
/// uncolored glass disc and a black or white button, whatever the
/// appearance.
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
        .background(Color(.systemBackground))
    }
}
