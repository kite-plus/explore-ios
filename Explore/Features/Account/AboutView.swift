import SwiftUI

/// What Explore is and the promises it keeps, in the app's own words.
struct AboutView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 14) {
                    GlassMark(size: 92)
                    Text("Explore")
                        .font(.largeTitle.bold())
                    Text("Discover what people publish.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)

                AboutPoint(symbol: "binoculars.fill", title: "One stream of independent blogs") {
                    Text("Explore gathers the public feeds of independent blogs and shows their latest posts, newest first. Any blog with RSS, Atom or JSON Feed can join.")
                }
                AboutPoint(symbol: "arrow.up.forward.square.fill", title: "Always read on the author's site") {
                    Text("A post opens at its original address, with no page in between. Explore adds only utm_source, so the author can tell the visit came from Explore; nothing in it identifies you.")
                }
                AboutPoint(symbol: "tray.fill", title: "No post content kept") {
                    Text("Explore keeps neither post content nor images. What you see is a cache of what each feed says right now; when an author edits or deletes a post, Explore follows.")
                }
                AboutPoint(symbol: "hand.raised.fill", title: "Private by design") {
                    Text("Reading needs no account and this app has no analytics. Thumbnails and icons come from Explore's own server, never from third parties. With an account, Explore keeps your email, your name, a hash of your password and the blogs you follow, and never what you read.")
                }
                AboutPoint(symbol: "checkmark.seal.fill", title: "How blogs are listed") {
                    Text("Authors submit their blog and its feed is checked on the spot. A maintainer reviews blogs that pass: personal and independent blogs, updated within the last 12 months.")
                }
                AboutPoint(symbol: "door.left.hand.open", title: "Leaving is easy") {
                    Text("Authors can leave at any time: answer Explore's crawler with 410 Gone, disallow KiteExplore in robots.txt, or open an issue.")
                }

                VStack(spacing: 0) {
                    LinkRow(title: "Explore on the Web", symbol: "globe", url: app.server)
                    Divider().padding(.leading, 52)
                    LinkRow(title: "Source Code", symbol: "chevron.left.forwardslash.chevron.right", url: URL(string: "https://github.com/kite-plus/explore")!)
                    Divider().padding(.leading, 52)
                    LinkRow(title: "About the Crawler", symbol: "ant.fill", url: app.client.botURL)
                }
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 24, style: .continuous))
                .padding(.top, 8)

                Text("Explore is the discovery side of Kite Plus.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AboutPoint<Content: View>: View {
    let symbol: String
    let title: LocalizedStringKey
    @ViewBuilder var text: Content

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.primary)
                .frame(width: 38, height: 38)
                .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                text
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 24, style: .continuous))
    }
}

private struct LinkRow: View {
    let title: LocalizedStringKey
    let symbol: String
    let url: URL

    var body: some View {
        Button {
            LinkOpener.open(url)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 24)
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
