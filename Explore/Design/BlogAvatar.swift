import SwiftUI

/// A blog's icon: its first letter on its color, covered by the site's
/// favicon once Explore has fetched it. Explore answers a 1x1 transparent
/// image when a blog has no icon, which leaves the letter showing.
struct BlogAvatar: View {
    let host: String
    let name: String
    var size: CGFloat = 20

    @Environment(AppModel.self) private var app
    @Environment(\.displayScale) private var displayScale
    @State private var favicon: UIImage?

    var body: some View {
        ZStack {
            Circle()
                .fill(Palette.color(for: host).gradient)
            Text(Palette.initial(of: name))
                .font(.system(size: size * 0.46, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
            if let favicon, !isLarge {
                Image(uiImage: favicon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .padding(size * 0.12)
                    .frame(width: size, height: size)
                    .background(.white)
                    .transition(.opacity)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .overlay(alignment: .bottomTrailing) {
            // Favicons are small; on a large avatar they sit in a badge
            // rather than being blown up.
            if let favicon, isLarge {
                Image(uiImage: favicon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .padding(5)
                    .frame(width: size * 0.36, height: size * 0.36)
                    .background(.white, in: .circle)
                    .overlay(Circle().strokeBorder(.black.opacity(0.06)))
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                    .offset(x: 2, y: 2)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .accessibilityHidden(true)
        .task(id: "\(app.server.absoluteString)|\(host)") {
            let url = app.client.faviconURL(host: host)
            let pixels = (isLarge ? size * 0.36 : size) * displayScale
            if let cached = ImageCache.shared.cached(url, pixels: pixels) {
                favicon = Self.usable(cached)
                return
            }
            let image = await ImageCache.shared.load(url, pixels: pixels)
            withAnimation(.smooth(duration: 0.25)) { favicon = Self.usable(image) }
        }
    }

    private var isLarge: Bool { size >= 64 }

    private static func usable(_ image: UIImage?) -> UIImage? {
        guard let image, let cg = image.cgImage, cg.width > 1 else { return nil }
        return image
    }
}

/// A post's thumbnail. It removes itself when the image cannot be loaded,
/// so the post reads like one without a cover instead of a broken image.
struct EntryThumbnail: View {
    let url: URL
    var size = CGSize(width: 84, height: 84)
    var cornerRadius: CGFloat = 14

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var failed = false

    init(url: URL, size: CGSize = CGSize(width: 84, height: 84), cornerRadius: CGFloat = 14) {
        self.url = url
        self.size = size
        self.cornerRadius = cornerRadius
        let pixels = max(size.width, size.height) * 3
        _image = State(initialValue: ImageCache.shared.cached(url, pixels: pixels))
        _failed = State(initialValue: ImageCache.shared.hasFailed(url))
    }

    var body: some View {
        if !failed {
            ZStack {
                Rectangle().fill(.fill.tertiary)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.primary.opacity(0.06))
            }
            .accessibilityHidden(true)
            .task(id: url) {
                guard image == nil else { return }
                let loaded = await ImageCache.shared.load(url, pixels: max(size.width, size.height) * 3)
                withAnimation(.smooth(duration: 0.3)) {
                    if let loaded { image = loaded } else { failed = true }
                }
            }
        }
    }
}

/// A wide cover for previews and headers; shows nothing when it fails.
struct CoverImage: View {
    let url: URL
    var height: CGFloat = 180

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: height)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .transition(.opacity)
            }
        }
        .task(id: url) {
            let loaded = await ImageCache.shared.load(url, pixels: 1200)
            withAnimation(.smooth) { image = loaded }
        }
    }
}
