import SwiftUI

/// The latest posts Explore filed under one topic.
struct TopicView: View {
    let slug: String

    @Environment(AppModel.self) private var app
    @AppStorage("topic.language") private var language: LanguageFilter = .all
    @State private var feed: FeedModel

    init(slug: String) {
        self.slug = slug
        _feed = State(initialValue: FeedModel(source: .latest, tag: slug))
    }

    private var name: String { app.topicName(slug) ?? slug }

    var body: some View {
        EntryList(feed: feed) {
            TopicBanner(slug: slug, name: name)
        } empty: {
            ContentUnavailableView {
                Label("No Posts Yet", systemImage: TopicStyle.symbol(for: slug))
            } description: {
                Text("No posts under this topic yet.")
            }
            .padding(.vertical, 30)
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker(selection: $language) {
                        ForEach(LanguageFilter.allCases) { option in
                            Label(option.title, systemImage: option.symbol).tag(option)
                        }
                    } label: {
                        Text("Blog language")
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("Blog language", systemImage: "globe")
                }
            }
        }
        .refreshable {
            await feed.load(using: app.client, fresh: true)
        }
        .task(id: "\(language.rawValue)|\(app.server.absoluteString)") {
            feed.language = language
            await feed.refreshIfNeeded(using: app.client)
        }
    }
}

private struct TopicBanner: View {
    let slug: String
    let name: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color(.secondarySystemGroupedBackground)
            Image(systemName: TopicStyle.symbol(for: slug))
                .font(.system(size: 120, weight: .semibold))
                .foregroundStyle(Color(.quaternaryLabel))
                .rotationEffect(.degrees(-12))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 24, y: -10)
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.primary)
                Text("Posts Explore filed under this topic, newest first.")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
            .padding(20)
        }
        .frame(height: 170)
        .clipShape(.rect(cornerRadius: 28, style: .continuous))
        .padding(.bottom, 6)
        .accessibilityElement(children: .combine)
    }
}
