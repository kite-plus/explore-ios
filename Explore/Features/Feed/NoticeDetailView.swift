import SwiftUI

/// A notice or ad's own page, drawn by the app and laid out as an article,
/// as on the website: who it is from with its date and mark, the title and
/// lead, the plain text in paragraphs with its addresses linked, a card on
/// who published it, and the latest posts to go on to.
struct NoticeDetailView: View {
    let id: String
    /// What the list already knows, shown while the text loads.
    var preview: Notice?

    @Environment(AppModel.self) private var app
    @Environment(\.navigate) private var navigate
    @Environment(\.dismiss) private var dismiss
    @State private var notice: Notice?
    @State private var failure: String?
    /// Taken down or ended since the list loaded.
    @State private var gone = false
    @State private var latest: [Entry] = []

    private var shown: Notice? { gone ? nil : notice ?? preview }

    var body: some View {
        ScrollView {
            if let shown {
                content(shown)
            } else if let failure {
                LoadFailedView(message: failure) { await load() }
                    .padding(.top, 80)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 120)
            }
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: app.client.webURL(notice: id)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
        // Links in the text open as other links do, in Safari's view.
        .environment(\.openURL, OpenURLAction { url in
            LinkOpener.open(url)
            return .handled
        })
        .task(id: id) {
            async let latestPosts = loadLatest()
            await load()
            latest = await latestPosts
        }
    }

    private func content(_ notice: Notice) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            byline(notice)

            Text(notice.title)
                .font(.title.bold())
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 22)

            if !notice.summary.isEmpty {
                Text(notice.summary)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
            }

            text(notice)

            if !notice.url.isEmpty, notice.isNotice, let url = URL(string: notice.url) {
                Button {
                    LinkOpener.open(url)
                } label: {
                    Text("Open the Link")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primaryAction)
                .padding(.top, 24)
            }

            sourceCard(notice)
                .padding(.top, 36)

            if !latest.isEmpty {
                keepExploring
                    .padding(.top, 36)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 32)
        .frame(maxWidth: 720, alignment: .leading)
        .frame(maxWidth: .infinity)
    }

    private func byline(_ notice: Notice) -> some View {
        HStack(spacing: 12) {
            NoticeAvatar(notice: notice, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(notice.sourceName)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let date = notice.publishedAt {
                        Text(Formatting.day(date))
                        Text(verbatim: "·")
                            .accessibilityHidden(true)
                    }
                    NoticeMark(notice: notice)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func text(_ notice: Notice) -> some View {
        if let body = self.notice?.body {
            let paragraphs = Self.paragraphs(of: body)
            if !paragraphs.isEmpty {
                VStack(alignment: .leading, spacing: 18) {
                    Divider()
                        .padding(.bottom, 6)
                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        Text(Self.linked(paragraph))
                            .font(.body)
                            .lineSpacing(6)
                            .tint(.accentColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .textSelection(.enabled)
                .padding(.top, 24)
            }
        } else if let failure {
            LoadFailedView(message: failure) { await load() }
        } else if notice.url.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 32)
        }
    }

    /// Kite Plus for a notice; the advertiser, marked as such, for an ad.
    private func sourceCard(_ notice: Notice) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                NoticeAvatar(notice: notice, size: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: notice.isNotice ? "Kite Plus" : notice.sourceName)
                        .font(.headline)
                    Group {
                        if notice.isNotice {
                            Text("Kite, a blog engine, and Explore, for finding independent blogs, are both part of Kite Plus.")
                        } else {
                            Text("This is an ad, written by the advertiser.")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            if notice.isNotice {
                HStack(spacing: 10) {
                    Button {
                        app.sheet = .submit
                    } label: {
                        Text("Submit a Blog")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primaryAction)
                    Button {
                        navigate(.about)
                    } label: {
                        Text("About Explore")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.glass)
                }
            } else if !notice.url.isEmpty, let url = URL(string: notice.url) {
                Button {
                    LinkOpener.open(url, source: app.sourceTag)
                } label: {
                    Text("Open the Link")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primaryAction)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 20, style: .continuous))
    }

    private var keepExploring: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Keep Exploring")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            Divider()
            ForEach(latest) { entry in
                EntryRow(entry: entry)
                Divider()
            }
            Button {
                app.stream = .latest
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Text("See All the Latest Posts")
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
        }
    }

    private func load() async {
        failure = nil
        do {
            notice = try await app.client.notice(id: id)
        } catch {
            guard !error.isCancellation else { return }
            gone = (error as? APIError)?.status == 404
            failure = gone ? String(localized: "This notice is no longer showing.") : error.readableMessage
        }
    }

    /// A few of the latest posts; they are extra, so a failure shows none.
    private func loadLatest() async -> [Entry] {
        let page = try? await app.client.entries(cursor: nil, language: nil, tag: nil)
        return Array((page?.data ?? []).prefix(3))
    }

    /// The text's paragraphs: split at blank lines, with single line breaks
    /// kept inside a paragraph, as the website shows them.
    nonisolated static func paragraphs(of text: String) -> [String] {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .split { $0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// A paragraph with its web addresses as links, www. ones included.
    nonisolated static func linked(_ paragraph: String) -> AttributedString {
        var text = AttributedString(paragraph)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return text }
        let whole = NSRange(paragraph.startIndex..., in: paragraph)
        for match in detector.matches(in: paragraph, range: whole) {
            guard let url = match.url, ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                  let range = Range(match.range, in: paragraph),
                  let lower = AttributedString.Index(range.lowerBound, within: text),
                  let upper = AttributedString.Index(range.upperBound, within: text)
            else { continue }
            text[lower..<upper].link = url
            text[lower..<upper].underlineStyle = .single
        }
        return text
    }
}

/// The Kite Plus mark for a notice, or the advertiser's initial for an ad.
struct NoticeAvatar: View {
    let notice: Notice
    var size: CGFloat = 18

    var body: some View {
        Group {
            if notice.isNotice {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.56, height: size * 0.56)
                    .frame(width: size, height: size)
                    .background(.white, in: .rect(cornerRadius: size * 0.28, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).strokeBorder(.quaternary))
            } else {
                BlogAvatarFace(host: notice.sourceName, name: notice.sourceName, size: size, favicon: nil)
            }
        }
        .accessibilityHidden(true)
    }
}
