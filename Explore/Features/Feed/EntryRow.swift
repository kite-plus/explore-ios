import SwiftUI

/// One post, laid out as on the website: its blog and time first, then the
/// title and two lines of excerpt beside the thumbnail, then its tags. The
/// title, excerpt and thumbnail open the post on the author's site; the
/// blog's name leads to its page. Titles and excerpts keep the blog's own
/// language and are never translated.
struct EntryRow: View {
    let entry: Entry
    var showsBlog = true
    /// The blog the list belongs to, for posts that do not carry one.
    var contextBlog: BlogRef?
    /// Under a heading that names an earlier day, the time of day rather
    /// than how long ago.
    var clockTime = false

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

    private var time: String {
        guard let date = entry.publishedAt else { return String(localized: "Date unknown") }
        return clockTime ? date.formatted(date: .omitted, time: .shortened) : Formatting.relative(date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    byline
                    Button(action: open) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .lineLimit(3)
                            if let excerpt = entry.excerpt, !excerpt.isEmpty {
                                Text(excerpt)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .typesettingLanguage(contentLanguage ?? Locale.Language(identifier: "en"), isEnabled: contentLanguage != nil)
                        .contentShape(.rect)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityHint(Text("Opens the post on the author's site"))
                }

                if let path = entry.imagePath {
                    // A new address, such as after a server switch, gets a
                    // fresh thumbnail rather than the old image.
                    let url = app.client.imageURL(path)
                    // The menu takes the room under the thumbnail, so the
                    // byline beside it keeps the blog's name whole.
                    VStack(alignment: .trailing, spacing: 6) {
                        Button(action: open) {
                            EntryThumbnail(url: url, size: CGSize(width: 96, height: 64), cornerRadius: 10)
                                .id(url)
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityHidden(true)
                        moreMenu
                    }
                    .padding(.top, 2)
                }
            }

            if !tags.isEmpty {
                FlowLayout(spacing: 14, lineSpacing: 6) {
                    ForEach(tags, id: \.slug) { tag in
                        Button {
                            navigate(.topic(tag.slug))
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: TopicStyle.symbol(for: tag.slug))
                                    .imageScale(.small)
                                Text(tag.name)
                                    .lineLimit(1)
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 14)
        .contentShape(.contextMenuPreview, .rect(cornerRadius: 12, style: .continuous))
        .contextMenu {
            EntryActions(entry: entry, blog: blog)
        } preview: {
            EntryPreview(
                entry: entry, blog: blog,
                imageURL: entry.imagePath.map(app.client.imageURL)
            )
        }
    }

    private var byline: some View {
        HStack(spacing: 6) {
            if showsBlog, let blog {
                Button {
                    navigate(.blog(blog))
                } label: {
                    HStack(spacing: 6) {
                        BlogAvatar(host: blog.host, name: blog.name, size: 18)
                        Text(blog.name)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary.opacity(0.8))
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
            Text(time)
                .lineLimit(1)
                .layoutPriority(1)
            Text(verbatim: "·")
                .accessibilityHidden(true)
            LinkStatusBadge(entry: entry)
            if entry.imagePath == nil {
                Spacer(minLength: 4)
                moreMenu
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private var moreMenu: some View {
        Menu {
            EntryActions(entry: entry, blog: blog)
        } label: {
            Image(systemName: "ellipsis")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 22)
                .contentShape(.rect)
        }
        .menuIndicator(.hidden)
        .accessibilityLabel(Text("More"))
    }

    private func open() {
        app.openPost(entry, blog: blog)
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
                app.openPost(entry, blog: blog)
            } label: {
                Label("Read on the Author's Site", systemImage: "safari")
            }
            Button {
                LinkOpener.openInSafari(url, source: app.sourceTag)
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
