import AppIntents
import SwiftUI
import WidgetKit

nonisolated enum WidgetLanguage: String, AppEnum {
    case all, zh, en

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Blog Language"
    static let caseDisplayRepresentations: [WidgetLanguage: DisplayRepresentation] = [
        .all: "All",
        .zh: "Chinese",
        .en: "English",
    ]
}

struct LatestPostsIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Latest Posts"
    static let description = IntentDescription("New posts from independent blogs on Explore.")

    @Parameter(title: "Blog Language", default: .all)
    var language: WidgetLanguage
}

nonisolated struct LatestPosts: TimelineEntry {
    let date: Date
    let posts: [Entry]
    let failed: Bool

    /// The widget always reads explore.kite.plus; the app's server choice
    /// stays inside the app.
    static let server = URL(string: "https://explore.kite.plus")!

    static func load(language: WidgetLanguage) async -> LatestPosts {
        var components = URLComponents(url: server.appending(path: "api/v1/entries"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "limit", value: "8")]
        if language != .all {
            components.queryItems?.append(URLQueryItem(name: "lang", value: language.rawValue))
        }
        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                return LatestPosts(date: .now, posts: [], failed: true)
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = RFC3339.decoding
            let page = try decoder.decode(Page<Entry>.self, from: data)
            return LatestPosts(date: .now, posts: page.data, failed: false)
        } catch {
            return LatestPosts(date: .now, posts: [], failed: true)
        }
    }

    static let sample = LatestPosts(date: .now, posts: [
        Entry(
            id: "1", title: "Notes from a year of writing in public", url: "https://blog.example.com/a",
            excerpt: nil, imagePath: nil, publishedAt: .now.addingTimeInterval(-3_600), tags: [],
            linkStatus: .available, linkCheckedAt: nil,
            blog: BlogRef(host: "blog.example.com", name: "Example Blog", siteURL: "https://blog.example.com/", language: "en")
        ),
        Entry(
            id: "2", title: "Self-hosting a feed reader on a tiny server", url: "https://notes.example.org/b",
            excerpt: nil, imagePath: nil, publishedAt: .now.addingTimeInterval(-7_200), tags: [],
            linkStatus: .available, linkCheckedAt: nil,
            blog: BlogRef(host: "notes.example.org", name: "Field Notes", siteURL: "https://notes.example.org/", language: "en")
        ),
        Entry(
            id: "3", title: "What I learned rebuilding my blog", url: "https://example.net/c",
            excerpt: nil, imagePath: nil, publishedAt: .now.addingTimeInterval(-86_400), tags: [],
            linkStatus: .available, linkCheckedAt: nil,
            blog: BlogRef(host: "example.net", name: "Weekly Journal", siteURL: "https://example.net/", language: "en")
        ),
    ], failed: false)
}

nonisolated struct LatestPostsProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LatestPosts {
        .sample
    }

    func snapshot(for configuration: LatestPostsIntent, in context: Context) async -> LatestPosts {
        if context.isPreview { return .sample }
        return await LatestPosts.load(language: configuration.language)
    }

    func timeline(for configuration: LatestPostsIntent, in context: Context) async -> Timeline<LatestPosts> {
        let posts = await LatestPosts.load(language: configuration.language)
        let next = Date.now.addingTimeInterval(posts.failed ? 15 * 60 : 45 * 60)
        return Timeline(entries: [posts], policy: .after(next))
    }
}

struct LatestPostsWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "LatestPosts", intent: LatestPostsIntent.self, provider: LatestPostsProvider()) { posts in
            LatestPostsView(posts: posts)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color("WidgetBackground"), Color("WidgetBackground").opacity(0.85)],
                        startPoint: .top, endPoint: .bottom
                    )
                }
        }
        .configurationDisplayName("Latest Posts")
        .description("New posts from independent blogs on Explore.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
    }
}

/// Opens a post through the app, which shows it on the author's site.
private func link(for post: Entry) -> URL {
    var components = URLComponents()
    components.scheme = "explore"
    components.host = "open"
    components.queryItems = [URLQueryItem(name: "url", value: post.url)]
    return components.url ?? URL(string: "explore://discover")!
}

private func relative(_ date: Date?) -> String {
    guard let date else { return "" }
    return date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
}

struct LatestPostsView: View {
    let posts: LatestPosts

    @Environment(\.widgetFamily) private var family

    var body: some View {
        LatestPostsLayout(posts: posts, family: family)
    }
}

struct LatestPostsLayout: View {
    let posts: LatestPosts
    let family: WidgetFamily

    var body: some View {
        if posts.posts.isEmpty {
            empty
        } else {
            switch family {
            case .systemSmall:
                small(posts.posts[0])
            case .accessoryRectangular:
                rectangular(posts.posts[0])
            case .accessoryInline:
                Text(posts.posts[0].title)
                    .widgetURL(link(for: posts.posts[0]))
            default:
                list(limit: family == .systemLarge ? 6 : 3)
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Image(systemName: posts.failed ? "wifi.exclamationmark" : "safari")
                .font(.title3)
                .widgetAccentable()
            Text(posts.failed ? "Couldn't load posts" : "No posts yet")
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .widgetURL(URL(string: "explore://discover"))
    }

    private func small(_ post: Entry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let blog = post.blog {
                HStack(spacing: 6) {
                    InitialAvatar(blog: blog, size: 18)
                    Text(blog.name)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Text(post.title)
                .font(.headline)
                .lineLimit(4)
                .typesettingLanguage(language(of: post), isEnabled: post.blog?.language.isEmpty == false)
            Spacer(minLength: 0)
            Text(relative(post.publishedAt))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(link(for: post))
    }

    private func rectangular(_ post: Entry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(post.blog?.name ?? "Explore")
                .font(.caption2.weight(.semibold))
                .widgetAccentable()
                .lineLimit(1)
            Text(post.title)
                .font(.caption)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(link(for: post))
    }

    private func list(limit: Int) -> some View {
        VStack(alignment: .leading, spacing: family == .systemLarge ? 12 : 9) {
            HStack(spacing: 6) {
                Image(systemName: "safari.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tint)
                    .widgetAccentable()
                Text(verbatim: "Explore")
                    .font(.caption.weight(.bold))
                Spacer()
                Text("Latest")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            ForEach(posts.posts.prefix(limit)) { post in
                Link(destination: link(for: post)) {
                    HStack(alignment: .top, spacing: 10) {
                        if let blog = post.blog {
                            InitialAvatar(blog: blog, size: 22)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.primary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(family == .systemLarge ? 2 : 1)
                                .typesettingLanguage(language(of: post), isEnabled: post.blog?.language.isEmpty == false)
                            Text(verbatim: [post.blog?.name, relative(post.publishedAt)].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.caption2)
                                .foregroundStyle(Color.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func language(of post: Entry) -> Locale.Language {
        Locale.Language(identifier: post.blog?.language ?? "en")
    }
}

private struct InitialAvatar: View {
    let blog: BlogRef
    let size: CGFloat

    var body: some View {
        Text(Palette.initial(of: blog.name))
            .font(.system(size: size * 0.48, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Palette.color(for: blog.host).gradient, in: .circle)
            .widgetAccentable()
    }
}

#Preview(as: .systemMedium) {
    LatestPostsWidget()
} timeline: {
    LatestPosts.sample
}
