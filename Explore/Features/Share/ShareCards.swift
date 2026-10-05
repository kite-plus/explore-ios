import SwiftUI

/// What the share sheet makes a card for.
enum ShareSubject: Hashable {
    case post(Entry, BlogRef?)
    case blog(BlogRef)

    var id: String {
        switch self {
        case let .post(entry, _): "post-\(entry.id)"
        case let .blog(blog): "blog-\(blog.host)"
        }
    }
}

/// A post as a card to share: the blog and the day it came out, the title
/// and the excerpt, and a code that opens it through Explore.
struct PostShareCard: View {
    let entry: Entry
    let blog: BlogRef?
    let favicon: UIImage?
    let code: UIImage?
    let site: String

    var body: some View {
        ShareCardFrame(code: code, caption: "Scan to read the post", site: site) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    if let blog {
                        BlogAvatarFace(host: blog.host, name: blog.name, size: 24, favicon: favicon)
                        Text(blog.name)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                    }
                    if let date = entry.publishedAt {
                        if blog != nil {
                            Text(verbatim: "\u{00B7}")
                                .foregroundStyle(.tertiary)
                        }
                        Text(Formatting.day(date))
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(entry.title)
                    .font(.system(size: 22, weight: .bold))
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
                if let excerpt = entry.excerpt?.trimmingCharacters(in: .whitespacesAndNewlines), !excerpt.isEmpty {
                    Text(excerpt)
                        .font(.system(size: 15))
                        .lineSpacing(3)
                        .foregroundStyle(.secondary)
                        .lineLimit(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// A blog as a card to share: who it is, what it writes about, its latest
/// posts, and a code for its page on Explore.
struct BlogShareCard: View {
    let blog: BlogRef
    let about: String
    let recent: [Entry]
    let favicon: UIImage?
    let code: UIImage?
    let site: String

    var body: some View {
        ShareCardFrame(code: code, caption: "Scan to see the blog", site: site) {
            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    BlogAvatarFace(host: blog.host, name: blog.name, size: 64, favicon: favicon)
                        .padding(.bottom, 4)
                    Text(blog.name)
                        .font(.system(size: 22, weight: .bold))
                        .lineLimit(2)
                    Text(verbatim: blog.host)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    if !about.isEmpty {
                        Text(about)
                            .font(.system(size: 15))
                            .lineSpacing(3)
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

                if !recent.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recent Posts")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                        ForEach(recent.prefix(3)) { entry in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Circle()
                                    .fill(Color.kite)
                                    .frame(width: 5, height: 5)
                                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] }
                                Text(entry.title)
                                    .font(.system(size: 15))
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.035), in: .rect(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }
}

/// The parts every share card has: the Explore mark on top, then the card's
/// own content, then a dashed line over the code and where it leads. The
/// card keeps one look whatever the app's appearance and text size, as an
/// image passed around should.
private struct ShareCardFrame<Content: View>: View {
    let code: UIImage?
    let caption: LocalizedStringKey
    let site: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 20)
                Text(verbatim: "Explore")
                    .font(.system(size: 17, weight: .semibold))
            }
            .padding(.bottom, 20)

            content

            DashedLine()
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(.quaternary)
                .frame(height: 1)
                .padding(.top, 24)
                .padding(.bottom, 18)

            HStack(spacing: 14) {
                if let code {
                    Image(uiImage: code)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 88, height: 88)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(caption)
                        .font(.system(size: 15, weight: .semibold))
                    Text(verbatim: site)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
        .frame(width: 360, alignment: .leading)
        .background(Color.white)
        .foregroundStyle(.primary)
        .environment(\.colorScheme, .light)
        .dynamicTypeSize(.large)
    }
}

nonisolated private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}
