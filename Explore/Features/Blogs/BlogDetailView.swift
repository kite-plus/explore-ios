import SwiftUI

/// A blog's page: who it is, how to visit and follow it, and the posts in
/// its feed. The header's mesh takes the blog's color and runs up under
/// the glass navigation bar.
struct BlogDetailView: View {
    let ref: BlogRef

    @Environment(AppModel.self) private var app
    @State private var feed: FeedModel
    @State private var titleVisible = false

    init(ref: BlogRef) {
        self.ref = ref
        _feed = State(initialValue: FeedModel(source: .blog(ref.host)))
    }

    private var name: String { feed.blog?.name ?? ref.name }

    var body: some View {
        EntryList(
            feed: feed, showsBlog: false, contextBlog: feed.blog?.ref ?? ref, endText: nil,
            onScroll: { offset in
                let visible = offset > 260
                if visible != titleVisible {
                    withAnimation(.smooth(duration: 0.2)) { titleVisible = visible }
                }
            }
        ) {
            BlogHeader(ref: ref, blog: feed.blog)
                .padding(.bottom, 8)
            if !feed.entries.isEmpty {
                Text("Recent Posts")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
        } empty: {
            ContentUnavailableView {
                Label("No Posts to Show", systemImage: "doc.text.magnifyingglass")
            } description: {
                Text("The feed has no posts to show right now.")
            }
            .padding(.vertical, 24)
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(name)
                    .font(.headline)
                    .lineLimit(1)
                    .opacity(titleVisible ? 1 : 0)
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: app.client.webURL(blog: ref.host), subject: Text(name)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
        .task(id: app.server.absoluteString) {
            await feed.load(using: app.client)
        }
        .refreshable {
            await feed.load(using: app.client, fresh: true)
        }
    }
}

private struct BlogHeader: View {
    let ref: BlogRef
    let blog: Blog?

    @Environment(AppModel.self) private var app
    @State private var expanded = false

    private var name: String { blog?.name ?? ref.name }

    private var contentLanguage: Locale.Language? {
        let code = blog?.language ?? ref.language
        return code.isEmpty ? nil : Locale.Language(identifier: code)
    }

    var body: some View {
        VStack(spacing: 16) {
            BlogAvatar(host: ref.host, name: name, size: 92)
                .padding(7)
                .glassEffect(.regular, in: .circle)
                .padding(.top, 12)

            VStack(spacing: 6) {
                Text(name)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Button {
                    if let url = URL(string: blog?.siteURL ?? ref.siteURL) {
                        LinkOpener.open(url, source: app.sourceTag)
                    }
                } label: {
                    Label(Formatting.displayHost(ref.host), systemImage: "link")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .typesettingLanguage(contentLanguage ?? Locale.Language(identifier: "en"), isEnabled: contentLanguage != nil)

            if let about = blog?.about, !about.isEmpty {
                Text(about)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(expanded ? nil : 3)
                    .typesettingLanguage(contentLanguage ?? Locale.Language(identifier: "en"), isEnabled: contentLanguage != nil)
                    .onTapGesture {
                        withAnimation(.smooth) { expanded.toggle() }
                    }
                    .accessibilityAddTraits(.isButton)
            }

            actions

            if let blog {
                facts(blog)
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(alignment: .bottom) {
            MeshBackdrop(colors: BlogColors.of(ref.host))
                .frame(height: 1000)
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black.opacity(0.9), location: 0.6),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                }
                .opacity(0.5)
                .padding(.horizontal, -500)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private var actions: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    if let url = URL(string: blog?.siteURL ?? ref.siteURL) {
                        LinkOpener.open(url, source: app.sourceTag)
                    }
                } label: {
                    Label("Visit Blog", systemImage: "safari")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.glassProminent)
                .tint(Palette.color(for: ref.host))
                .controlSize(.large)

                FollowButton(blog: blog?.ref ?? ref, quiet: true)

                Menu {
                    BlogActions(blog: blog?.ref ?? ref, feedURL: blog?.feedURL)
                } label: {
                    Label("More", systemImage: "ellipsis")
                        .labelStyle(.iconOnly)
                        .font(.body.weight(.semibold))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
            }
        }
    }

    private func facts(_ blog: Blog) -> some View {
        HStack(spacing: 8) {
            if let language = Formatting.languageName(blog.language) {
                Pill(text: language, systemImage: "character.bubble")
            }
            if let generator = Formatting.generatorName(blog.generator) {
                Pill(text: generator, systemImage: "shippingbox")
            }
            if let date = blog.lastPublishedAt {
                Pill(text: String(localized: "Updated \(Formatting.relative(date))"), systemImage: "clock")
            }
        }
        .padding(.bottom, 4)
    }
}
