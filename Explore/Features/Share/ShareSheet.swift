import Photos
import SwiftUI

/// A card to share a post or a blog: a preview of the image, and ways to
/// save it, send it on, or copy the plain link instead.
struct ShareSheet: View {
    let subject: ShareSubject

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var card: UIImage?
    @State private var saved = false
    @State private var copied = false
    @State private var saveFailed = false

    private var title: String {
        switch subject {
        case let .post(entry, _): entry.title
        case let .blog(blog): blog.name
        }
    }

    /// Where the card's code leads, and what Copy Link copies: the post
    /// through the website's transition page, or the blog's page on Explore.
    private var link: URL {
        switch subject {
        case let .post(entry, blog): app.client.webURL(post: entry, blog: blog, source: app.sourceTag)
        case let .blog(blog): app.client.webURL(blog: blog.host)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if let card {
                        Image(uiImage: card)
                            .resizable()
                            .scaledToFit()
                            .clipShape(.rect(cornerRadius: 20, style: .continuous))
                            .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
                            .accessibilityLabel(Text(title))
                            .transition(.opacity)
                    } else {
                        ProgressView()
                            .frame(height: 360)
                    }
                }
                .frame(maxWidth: 360)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                actions
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
            .alert("Couldn't Save the Image", isPresented: $saveFailed) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Done", role: .cancel) {}
            } message: {
                Text("Allow Explore to add photos in Settings, then try again.")
            }
        }
        .task {
            await makeCard()
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                Task { await save() }
            } label: {
                ActionLabel(
                    title: saved ? "Saved" : "Save Image",
                    systemImage: saved ? "checkmark" : "square.and.arrow.down"
                )
            }
            .disabled(card == nil)

            if let card {
                ShareLink(item: Image(uiImage: card), preview: SharePreview(title, image: Image(uiImage: card))) {
                    ActionLabel(title: "Share Image", systemImage: "square.and.arrow.up")
                }
            } else {
                Button {} label: {
                    ActionLabel(title: "Share Image", systemImage: "square.and.arrow.up")
                }
                .disabled(true)
            }

            Button {
                UIPasteboard.general.url = link
                flash(copied: true)
            } label: {
                ActionLabel(title: copied ? "Copied" : "Copy Link", systemImage: copied ? "checkmark" : "link")
            }
        }
        .buttonStyle(.glass)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private func makeCard() async {
        let site = app.sourceTag
        switch subject {
        case let .post(entry, blog):
            var favicon: UIImage?
            if let blog {
                favicon = await BlogAvatar.favicon(host: blog.host, size: 24, scale: 3, client: app.client)
            }
            let code = QRCode.image(for: link)
            render(PostShareCard(entry: entry, blog: blog, favicon: favicon, code: code, site: site))
        case let .blog(ref):
            let page = try? await app.client.blog(host: ref.host, cursor: nil)
            let favicon = await BlogAvatar.favicon(host: ref.host, size: 64, scale: 3, client: app.client)
            let code = QRCode.image(for: link)
            render(
                BlogShareCard(
                    blog: page?.blog.ref ?? ref, about: page?.blog.about ?? "", recent: page?.entries ?? [],
                    favicon: favicon, code: code, site: site
                )
            )
        }
    }

    /// Draws the card at three times its size, sharp on any screen and in
    /// any chat it is sent to.
    private func render(_ view: some View) {
        let renderer = ImageRenderer(content: view.environment(\.displayScale, 3))
        renderer.scale = 3
        guard let image = renderer.uiImage else { return }
        withAnimation(.smooth(duration: 0.25)) { card = Self.opaque(image) }
    }

    /// The card on solid white. Its height rarely ends on a whole pixel, and
    /// the half-clear last row turns into a dark line once saved as a JPEG
    /// or sent through a chat.
    private static func opaque(_ image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: image.size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: image.size))
            image.draw(at: .zero)
        }
    }

    private func save() async {
        guard let card else { return }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            saveFailed = true
            return
        }
        do {
            try await Self.addToPhotos(card)
            flash(saved: true)
        } catch {
            saveFailed = true
        }
    }

    /// Photos runs the change on its own queue; written here, the block
    /// would take the sheet's main actor isolation and trap there.
    nonisolated private static func addToPhotos(_ image: UIImage) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }

    /// Shows a button's done state for a moment, as a toast would outside
    /// the sheet.
    private func flash(saved: Bool = false, copied: Bool = false) {
        withAnimation(.snappy) {
            if saved { self.saved = true }
            if copied { self.copied = true }
        }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.snappy) {
                if saved { self.saved = false }
                if copied { self.copied = false }
            }
        }
    }
}

/// An action under the card: its symbol over a short name.
private struct ActionLabel: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title3)
                .contentTransition(.symbolEffect(.replace))
            Text(title)
                .font(.footnote.weight(.medium))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}
