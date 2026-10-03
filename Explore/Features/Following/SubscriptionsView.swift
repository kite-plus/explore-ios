import SwiftUI

/// The blogs the reader follows, with unfollow and OPML export.
struct SubscriptionsView: View {
    @Environment(AppModel.self) private var app
    @State private var blogs: [Blog] = []
    @State private var phase: FeedModel.Phase = .idle

    var body: some View {
        List {
            switch phase {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            case let .failed(message):
                LoadFailedView(message: message) { await load() }
                    .listRowBackground(Color.clear)
            case .loaded:
                if blogs.isEmpty {
                    ContentUnavailableView {
                        Label("Not Following Any Blogs", systemImage: "heart.text.square")
                    } description: {
                        Text("Follow blogs from the directory and their new posts gather here.")
                    } actions: {
                        Button("Browse Blogs") { app.tab = .blogs }
                            .buttonStyle(.glassProminent)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(blogs) { blog in
                            NavigationLink(value: Route.blog(blog.ref)) {
                                HStack(spacing: 12) {
                                    BlogAvatar(host: blog.host, name: blog.name, size: 36)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(blog.name)
                                            .font(.headline)
                                            .lineLimit(1)
                                        Text(Formatting.displayHost(blog.host))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    unfollow(blog)
                                } label: {
                                    Label("Unfollow", systemImage: "heart.slash")
                                }
                            }
                        }
                    } footer: {
                        Text("Export the list as OPML to take these blogs to any feed reader.")
                    }
                }
            }
        }
        .navigationTitle("Following")
        .toolbar {
            if !blogs.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(
                        item: OPMLDocument(title: String(localized: "Blogs I follow on Explore"), blogs: blogs),
                        preview: SharePreview(Text(verbatim: "Explore.opml"), image: Image(systemName: "doc.text"))
                    ) {
                        Label("Export OPML", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .refreshable { await load() }
        .task(id: app.generation) { await load() }
    }

    private func load() async {
        guard app.isSignedIn else {
            blogs = []
            phase = .loaded
            return
        }
        if blogs.isEmpty { phase = .loading }
        do {
            let list = try await app.client.subscriptions()
            blogs = list.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            app.setFollowedHosts(Set(list.map(\.host)))
            phase = .loaded
        } catch {
            guard !error.isCancellation else { return }
            app.handleAuthError(error)
            phase = blogs.isEmpty ? .failed(error.readableMessage) : .loaded
        }
    }

    private func unfollow(_ blog: Blog) {
        withAnimation { blogs.removeAll { $0.host == blog.host } }
        Task { await app.toggleFollow(blog.ref) }
    }
}

/// Blogs the reader has proved they own.
struct OwnedBlogsView: View {
    @Environment(AppModel.self) private var app
    @State private var blogs: [Blog] = []
    @State private var phase: FeedModel.Phase = .idle

    var body: some View {
        List {
            switch phase {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            case let .failed(message):
                LoadFailedView(message: message) { await load() }
                    .listRowBackground(Color.clear)
            case .loaded:
                if blogs.isEmpty {
                    ContentUnavailableView {
                        Label("No Claimed Blogs", systemImage: "checkmark.seal")
                    } description: {
                        Text("Run a blog listed on Explore? Open its page, tap the ··· button and choose Claim This Blog. You prove it with a DNS record.")
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(blogs) { blog in
                        NavigationLink(value: Route.blog(blog.ref)) {
                            HStack(spacing: 12) {
                                BlogAvatar(host: blog.host, name: blog.name, size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(blog.name)
                                        .font(.headline)
                                    Text(Formatting.displayHost(blog.host))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.teal)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("My Blogs")
        .refreshable { await load() }
        .task(id: app.generation) { await load() }
    }

    private func load() async {
        guard app.isSignedIn else {
            phase = .loaded
            return
        }
        if blogs.isEmpty { phase = .loading }
        do {
            blogs = try await app.client.ownedBlogs()
            phase = .loaded
        } catch {
            guard !error.isCancellation else { return }
            app.handleAuthError(error)
            phase = blogs.isEmpty ? .failed(error.readableMessage) : .loaded
        }
    }
}
