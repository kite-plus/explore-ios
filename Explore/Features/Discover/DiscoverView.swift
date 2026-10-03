import SwiftUI

/// The latest posts from every listed blog, newest first.
struct DiscoverView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("discover.language") private var language: LanguageFilter = .all
    @State private var tag: String?
    @State private var feed = FeedModel(source: .latest)

    var body: some View {
        ExploreStack(tab: .discover) {
            EntryList(feed: feed) {
                if !app.notice.isEmpty {
                    NoticeBanner(text: app.notice)
                }
            } pinned: {
                FeedFilterBar(language: $language, tag: $tag)
            } empty: {
                ContentUnavailableView {
                    Label("No Posts Yet", systemImage: "binoculars")
                } description: {
                    Text(tag == nil ? "Posts from listed blogs show up here." : "No posts under this topic yet.")
                }
                .padding(.vertical, 40)
            }
            .navigationTitle("Discover")
            .navigationSubtitle("New posts from independent blogs")
            .refreshable {
                await feed.load(using: app.client, fresh: true)
            }
            .task(id: "\(language.rawValue)|\(tag ?? "")|\(app.server.absoluteString)") {
                feed.language = language
                feed.tag = tag
                await feed.refreshIfNeeded(using: app.client)
            }
        }
    }
}

/// The site notice maintainers set in the admin console.
struct NoticeBanner: View {
    let text: String

    @AppStorage("notice.dismissed") private var dismissed = ""

    var body: some View {
        if dismissed != text {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "megaphone.fill")
                    .foregroundStyle(Color.kite)
                    .font(.headline)
                Text(text)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    withAnimation(.snappy) { dismissed = text }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Dismiss"))
            }
            .padding(14)
            .background(Color.kite.opacity(0.1), in: .rect(cornerRadius: 20, style: .continuous))
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }
}
