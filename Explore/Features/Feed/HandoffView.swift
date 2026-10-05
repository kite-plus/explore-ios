import SwiftUI

/// A post on its way to the author's site.
struct Handoff: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let title: String
    let blog: BlogRef?
    let entry: Entry
}

/// What the app shows for a moment before a post opens, as the website's
/// transition page does: where the reader is going, the blog and the post,
/// and a bar that fills until the page opens. It comes before Safari's
/// view, which must never be covered.
struct HandoffView: View {
    let handoff: Handoff

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress = 0.0

    private var host: String { handoff.url.host() ?? handoff.url.absoluteString }

    var body: some View {
        VStack(spacing: 0) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(height: 28)
                .accessibilityHidden(true)
            Text("Taking you to the author's site")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 32)
            HStack(spacing: 12) {
                if let blog = handoff.blog {
                    BlogAvatar(host: blog.host, name: blog.name, size: 40)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(handoff.blog?.name ?? host)
                        .font(.headline)
                        .lineLimit(1)
                    Text(host)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.top, 16)
            Text(handoff.title)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.top, 20)
            Capsule()
                .fill(.quaternary)
                .frame(width: 160, height: 4)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Color.kite)
                        .frame(width: 160 * progress)
                }
                .padding(.top, 24)
                .accessibilityHidden(true)
        }
        .padding(32)
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .accessibilityElement(children: .combine)
        // After the page appears, so the fade it appears with does not
        // take over the bar's fill.
        .task {
            AccessibilityNotification.Announcement(String(localized: "Taking you to the author's site")).post()
            if reduceMotion {
                progress = 1
            } else {
                withAnimation(.easeOut(duration: HandoffView.duration)) { progress = 1 }
            }
        }
    }

    /// How long the page shows before the post opens, as on the website.
    static let duration = 0.7
}
