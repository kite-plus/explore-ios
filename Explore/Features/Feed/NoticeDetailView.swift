import SwiftUI

/// A notice or ad's own page, drawn by the app: who it is from, its mark,
/// its title and its plain text, which splits into paragraphs at blank
/// lines as on the website. A link it carries opens below the text.
struct NoticeDetailView: View {
    let id: String
    /// What the list already knows, shown while the text loads.
    var preview: Notice?

    @Environment(AppModel.self) private var app
    @State private var notice: Notice?
    @State private var failure: String?
    /// Taken down or ended since the list loaded.
    @State private var gone = false

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
        .task(id: id) { await load() }
    }

    private func content(_ notice: Notice) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Text(notice.sourceName)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary.opacity(0.8))
                    .lineLimit(1)
                Text(verbatim: "·")
                    .accessibilityHidden(true)
                NoticeMark(notice: notice)
                if let date = notice.publishedAt {
                    Text(verbatim: "·")
                        .accessibilityHidden(true)
                    Text(Formatting.day(date))
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            Text(notice.title)
                .font(.title2.bold())
                .fixedSize(horizontal: false, vertical: true)

            if !notice.summary.isEmpty {
                Text(notice.summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            if let body = self.notice?.body {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(Self.paragraphs(of: body).enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph)
                            .font(.body)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .textSelection(.enabled)
                .padding(.top, 6)
            } else if let failure {
                LoadFailedView(message: failure) { await load() }
            } else if notice.url.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
            }

            if !notice.url.isEmpty, let url = URL(string: notice.url) {
                Button {
                    LinkOpener.open(url, source: notice.isNotice ? nil : app.sourceTag)
                } label: {
                    Text("Open the Link")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primaryAction)
                .padding(.top, 12)
            }

            if !notice.isNotice {
                Text("This is an ad, written by the advertiser.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: 720, alignment: .leading)
        .frame(maxWidth: .infinity)
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

    /// The text's paragraphs: split at blank lines, with single line breaks
    /// kept inside a paragraph, as the website shows them.
    nonisolated static func paragraphs(of text: String) -> [String] {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .split { $0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
