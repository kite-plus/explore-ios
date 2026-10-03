import SwiftUI

/// One post: title, excerpt and thumbnail open the post on the author's
/// site; the byline leads to the blog. Titles and excerpts keep the blog's
/// own language and are never translated.
struct EntryCard: View {
    let entry: Entry
    var showsBlog = true
    /// The blog the list belongs to, for posts that do not carry one.
    var contextBlog: BlogRef?

    @Environment(AppModel.self) private var app
    @Environment(\.navigate) private var navigate

    private var blog: BlogRef? { entry.blog ?? contextBlog }

    private var contentLanguage: Locale.Language? {
        guard let code = blog?.language, !code.isEmpty else { return nil }
        return Locale.Language(identifier: code)
    }

    private var tags: [(slug: String, name: String)] {
        entry.tags.prefix(3).compactMap { slug in
            app.topicName(slug).map { (slug, $0) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: open) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(3)
                        if let excerpt = entry.excerpt, !excerpt.isEmpty {
                            Text(excerpt)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .typesettingLanguage(contentLanguage ?? Locale.Language(identifier: "en"), isEnabled: contentLanguage != nil)

                    if let path = entry.imagePath {
                        // A new address, such as after a server switch,
                        // gets a fresh thumbnail rather than the old image.
                        let url = app.client.imageURL(path)
                        EntryThumbnail(url: url)
                            .id(url)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(PressableStyle())
            .accessibilityHint(Text("Opens the post on the author's site"))

            if !tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tags, id: \.slug) { tag in
                        Button {
                            navigate(.topic(tag.slug))
                        } label: {
                            Pill(text: tag.name, systemImage: TopicStyle.of(tag.slug).symbol, tint: TopicStyle.of(tag.slug).color)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            footer
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 24, style: .continuous))
        .contentShape(.contextMenuPreview, .rect(cornerRadius: 24, style: .continuous))
        .contextMenu {
            EntryActions(entry: entry, blog: blog)
        } preview: {
            EntryPreview(
                entry: entry, blog: blog,
                imageURL: entry.imagePath.map(app.client.imageURL)
            )
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            if showsBlog, let blog {
                Button {
                    navigate(.blog(blog))
                } label: {
                    HStack(spacing: 6) {
                        BlogAvatar(host: blog.host, name: blog.name, size: 20)
                        Text(blog.name)
                            .lineLimit(1)
                            .typesettingLanguage(contentLanguage ?? Locale.Language(identifier: "en"), isEnabled: contentLanguage != nil)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Blog: \(blog.name)"))
                Text(verbatim: "·")
                    .accessibilityHidden(true)
            }
            Text(entry.publishedAt.map { Formatting.relative($0) } ?? String(localized: "Date unknown"))
                .lineLimit(1)
                .layoutPriority(1)
            Spacer(minLength: 4)
            LinkStatusBadge(entry: entry)
            Menu {
                EntryActions(entry: entry, blog: blog)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 32, height: 28)
                    .contentShape(.rect)
            }
            .menuIndicator(.hidden)
            .accessibilityLabel(Text("More"))
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private func open() {
        guard let url = URL(string: entry.url) else { return }
        LinkOpener.open(url, source: app.sourceTag)
    }
}

/// Actions for a post, shared by its menu and its context menu.
struct EntryActions: View {
    let entry: Entry
    let blog: BlogRef?

    @Environment(AppModel.self) private var app
    @Environment(\.navigate) private var navigate

    var body: some View {
        if let url = URL(string: entry.url) {
            Button {
                LinkOpener.open(url, source: app.sourceTag)
            } label: {
                Label("Read on the Author's Site", systemImage: "safari")
            }
            Button {
                UIApplication.shared.open(SourceTag.tagged(url, source: app.sourceTag))
            } label: {
                Label("Open in Safari", systemImage: "arrow.up.forward.app")
            }
            ShareLink(item: url, subject: Text(entry.title)) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button {
                UIPasteboard.general.url = url
                app.showToast(String(localized: "Link copied"), systemImage: "link")
            } label: {
                Label("Copy Link", systemImage: "link")
            }
        }
        if let blog {
            Section {
                Button {
                    navigate(.blog(blog))
                } label: {
                    Label("Go to Blog", systemImage: "books.vertical")
                }
                Button {
                    Task { await app.toggleFollow(blog) }
                } label: {
                    if app.isFollowing(blog.host) {
                        Label("Unfollow", systemImage: "heart.slash")
                    } else {
                        Label("Follow", systemImage: "heart")
                    }
                }
            }
        }
        Section {
            if app.linkStatus(of: entry).status == .unknown {
                Button {
                    Task { await app.checkLink(entry) }
                } label: {
                    Label("Check Link", systemImage: "checkmark.shield")
                }
            }
            if let blog {
                Button(role: .destructive) {
                    let target = ReportTarget(blogHost: blog.host, blogName: blog.name, entryID: entry.id, entryTitle: entry.title)
                    app.sheet = app.isSignedIn ? .report(target) : .signIn(.signIn)
                } label: {
                    Label("Report a Problem", systemImage: "flag")
                }
            }
        }
    }
}

/// The large preview shown above a post's context menu. It takes plain
/// values, since previews render outside the card's environment.
struct EntryPreview: View {
    let entry: Entry
    let blog: BlogRef?
    let imageURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let imageURL {
                CoverImage(url: imageURL, height: 190)
            }
            VStack(alignment: .leading, spacing: 10) {
                if let blog {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Palette.color(for: blog.host).gradient)
                            .frame(width: 22, height: 22)
                            .overlay {
                                Text(Palette.initial(of: blog.name))
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                        Text(blog.name)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if let date = entry.publishedAt {
                            Text(Formatting.relative(date))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Text(entry.title)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if let excerpt = entry.excerpt, !excerpt.isEmpty {
                    Text(excerpt)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let host = URL(string: entry.url)?.host() {
                    Label(host, systemImage: "link")
                        .font(.footnote)
                        .foregroundStyle(.tint)
                }
            }
            .padding(18)
        }
        .frame(width: 340)
        .background(Color(.systemBackground))
    }
}
