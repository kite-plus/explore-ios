import SwiftUI
import UniformTypeIdentifiers

/// The blogs the reader follows, with unfollow, OPML import and OPML export.
struct SubscriptionsView: View {
    @Environment(AppModel.self) private var app
    @State private var blogs: [Blog] = []
    @State private var phase: FeedModel.Phase = .idle
    @State private var choosingFile = false
    @State private var importing = false
    @State private var imported: OPMLImport?

    /// Explore reads OPML files up to 2 MiB.
    private static let maxOPMLBytes = 2 << 20

    var body: some View {
        List {
            if let imported {
                importSummary(imported)
            }
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
                            .buttonStyle(.primaryAction)
                        if app.isSignedIn {
                            Button("Import OPML") { choosingFile = true }
                                .disabled(importing)
                        }
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
                        Text("Import an OPML file from another reader to follow the blogs Explore lists, or export this list to take these blogs anywhere.")
                    }
                }
            }
        }
        .navigationTitle("Following")
        .toolbar {
            if app.isSignedIn {
                ToolbarItem(placement: .topBarTrailing) {
                    if importing {
                        ProgressView()
                    } else {
                        Menu {
                            Button {
                                choosingFile = true
                            } label: {
                                Label("Import OPML", systemImage: "square.and.arrow.down")
                            }
                            if !blogs.isEmpty {
                                ShareLink(
                                    item: OPMLDocument(title: String(localized: "Blogs I follow on Explore"), blogs: blogs),
                                    preview: SharePreview(Text(verbatim: "Explore.opml"), image: Image(systemName: "doc.text"))
                                ) {
                                    Label("Export OPML", systemImage: "square.and.arrow.up")
                                }
                            }
                        } label: {
                            Label("OPML", systemImage: "ellipsis")
                        }
                    }
                }
            }
        }
        .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.opml, .xml]) { result in
            switch result {
            case let .success(url):
                importFile(at: url)
            case let .failure(error):
                app.showError(error)
            }
        }
        .refreshable { await load() }
        .task(id: app.generation) { await load() }
    }

    private func importSummary(_ result: OPMLImport) -> some View {
        Group {
            Section {
                LabeledContent("Read from the file", value: result.outlines.formatted())
                LabeledContent("Newly followed", value: result.added.formatted())
                LabeledContent("Already followed", value: result.alreadyFollowing.formatted())
                if result.ignored > 0 {
                    LabeledContent("Past the limit of 1,000, not read", value: result.ignored.formatted())
                }
            } header: {
                Text("Import")
            }
            if !result.notListed.isEmpty {
                Section {
                    ForEach(Array(result.notListed.enumerated()), id: \.offset) { _, outline in
                        let site = Self.siteAddress(of: outline)
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(outline.title.isEmpty ? site : outline.title)
                                    .lineLimit(1)
                                if let host = URL(string: site)?.host(), !outline.title.isEmpty {
                                    Text(Formatting.displayHost(host))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer(minLength: 8)
                            Button("Submit") {
                                app.sheet = .submitPrefilled(site: site, feed: outline.feedURL)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                } header: {
                    Text("Not on Explore Yet")
                } footer: {
                    Text("Explore follows only blogs it lists. Submit these, and you can follow them once a maintainer approves them.")
                }
            }
        }
    }

    /// The blog's address for the submit form; a feed with no site address
    /// stands for the site at its origin, as on the website.
    private static func siteAddress(of outline: OPMLImport.Outline) -> String {
        if !outline.siteURL.isEmpty { return outline.siteURL }
        guard let feed = URL(string: outline.feedURL), let scheme = feed.scheme, let host = feed.host() else {
            return outline.feedURL
        }
        let port = feed.port.map { ":\($0)" } ?? ""
        return "\(scheme)://\(host)\(port)/"
    }

    private func importFile(at url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            app.showError(error)
            return
        }
        guard data.count <= Self.maxOPMLBytes else {
            app.showToast(
                String(localized: "The file is over 2 MB, too large to import."),
                systemImage: "exclamationmark.triangle.fill", isError: true
            )
            return
        }
        importing = true
        Task {
            defer { importing = false }
            do {
                let result = try await app.client.importSubscriptions(opml: data)
                withAnimation { imported = result }
                app.showToast(String(localized: "Import finished"), systemImage: "square.and.arrow.down.fill")
                await load()
            } catch {
                app.handleAuthError(error)
                app.showError(error)
            }
        }
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
