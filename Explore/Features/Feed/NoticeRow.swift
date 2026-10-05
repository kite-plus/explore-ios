import SwiftUI

/// A notice or ad between the posts, laid out as a post is, with a mark
/// where a post gives its time: a warm capsule for a notice, an outlined one
/// for an ad, and a pin when it leads the stream.
struct NoticeRow: View {
    let notice: Notice

    @Environment(AppModel.self) private var app
    @Environment(\.navigate) private var navigate

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 6) {
                byline
                VStack(alignment: .leading, spacing: 4) {
                    Text(notice.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                    if !notice.summary.isEmpty {
                        Text(notice.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(PressableStyle())
        .padding(.vertical, 14)
        .accessibilityHint(notice.url.isEmpty ? Text("Shows the notice") : Text("Opens the link"))
    }

    private var byline: some View {
        HStack(spacing: 6) {
            avatar
            Text(notice.sourceName)
                .fontWeight(.medium)
                .foregroundStyle(.primary.opacity(0.8))
                .lineLimit(1)
            Text(verbatim: "·")
                .accessibilityHidden(true)
            NoticeMark(notice: notice)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var avatar: some View {
        if notice.isNotice {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 11, height: 11)
                .frame(width: 18, height: 18)
                .background(.white, in: .circle)
                .overlay(Circle().strokeBorder(.quaternary))
                .accessibilityHidden(true)
        } else {
            BlogAvatarFace(host: notice.sourceName, name: notice.sourceName, size: 18, favicon: nil)
                .accessibilityHidden(true)
        }
    }

    /// A link opens as posts do; an ad's carries utm_source, as the website
    /// adds it. One without a link is Explore's own text, shown in the app.
    private func open() {
        if !notice.url.isEmpty, let url = URL(string: notice.url) {
            LinkOpener.open(url, source: notice.isNotice ? nil : app.sourceTag)
        } else {
            navigate(.notice(notice.id, preview: notice))
        }
    }
}

/// "Notice" on a warm capsule or "Ad" on an outlined one, pinned or not.
struct NoticeMark: View {
    let notice: Notice

    var body: some View {
        HStack(spacing: 2) {
            if notice.isPinned {
                Image(systemName: "pin.fill")
                    .imageScale(.small)
            }
            Text(notice.isNotice ? "Notice" : "Ad")
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 6)
        .padding(.vertical, 1.5)
        .foregroundStyle(notice.isNotice ? Color.orange : Color.secondary)
        .background {
            if notice.isNotice {
                Capsule().fill(Color.orange.opacity(0.14))
            } else {
                Capsule().strokeBorder(.tertiary, lineWidth: 1)
            }
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private var label: Text {
        switch (notice.isNotice, notice.isPinned) {
        case (true, true): Text("Pinned notice")
        case (true, false): Text("Notice")
        case (false, true): Text("Pinned ad")
        case (false, false): Text("Ad")
        }
    }
}
