import SwiftUI

/// A transient message in a Liquid Glass capsule.
struct ToastView: View {
    let toast: Toast

    var body: some View {
        Label {
            Text(toast.message)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        } icon: {
            Image(systemName: toast.systemImage)
                .foregroundStyle(toast.isError ? Color.orange : Color.kite)
                .symbolEffect(.bounce, value: toast.id)
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
    }
}

struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 24, style: .continuous))
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

struct Pill: View {
    let text: String
    var systemImage: String?
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
            }
            Text(text)
                .lineLimit(1)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(tint)
        .background(tint.opacity(0.12), in: .capsule)
    }
}

/// The Kite Plus mark, drawn from the same paths as the website's logo.
nonisolated struct KiteMark: Shape {
    func path(in rect: CGRect) -> Path {
        // The paths live in a 44 x 36 box starting at (10, 14).
        let scale = min(rect.width / 44, rect.height / 36)
        let dx = rect.midX - 32 * scale
        let dy = rect.midY - 32 * scale
        var path = Path()
        // Corners of the three panels before rounding.
        let panels: [[CGPoint]] = [
            [CGPoint(x: 11.91, y: 14.671), CGPoint(x: 29.95, y: 21.569), CGPoint(x: 29.95, y: 33.339), CGPoint(x: 11.91, y: 26.441)],
            [CGPoint(x: 11.91, y: 29.021), CGPoint(x: 29.95, y: 35.919), CGPoint(x: 29.95, y: 48.919), CGPoint(x: 11.91, y: 42.021)],
            [CGPoint(x: 34.05, y: 21.569), CGPoint(x: 52.09, y: 14.671), CGPoint(x: 52.09, y: 42.021), CGPoint(x: 34.05, y: 48.919)],
        ]
        for panel in panels {
            let points = panel.map { CGPoint(x: dx + $0.x * scale, y: dy + $0.y * scale) }
            path.addPath(Self.rounded(points, radius: 2.6 * scale))
        }
        return path
    }

    private static func rounded(_ points: [CGPoint], radius: CGFloat) -> Path {
        var path = Path()
        let count = points.count
        for index in 0..<count {
            let previous = points[(index + count - 1) % count]
            let current = points[index]
            let next = points[(index + 1) % count]
            let start = current.moved(toward: previous, by: radius)
            let end = current.moved(toward: next, by: radius)
            if index == 0 { path.move(to: start) } else { path.addLine(to: start) }
            path.addQuadCurve(to: end, control: current)
        }
        path.closeSubpath()
        return path
    }
}

private extension CGPoint {
    nonisolated func moved(toward other: CGPoint, by distance: CGFloat) -> CGPoint {
        let dx = other.x - x
        let dy = other.y - y
        let length = max(sqrt(dx * dx + dy * dy), 0.0001)
        let step = min(distance, length / 2)
        return CGPoint(x: x + dx / length * step, y: y + dy / length * step)
    }
}

/// The app mark floating in Liquid Glass, for sign-in and about screens.
struct GlassMark: View {
    var size: CGFloat = 88

    var body: some View {
        KiteMark()
            .fill(.white.gradient)
            .frame(width: size * 0.56, height: size * 0.56)
            .frame(width: size, height: size)
            .background(Color.kite.gradient, in: .rect(cornerRadius: size * 0.26, style: .continuous))
            .glassEffect(.regular, in: .rect(cornerRadius: size * 0.26, style: .continuous))
            .shadow(color: Color.kite.opacity(0.35), radius: 18, y: 8)
            .accessibilityHidden(true)
    }
}

#Preview("Glass") {
    ZStack {
        MeshBackdrop(colors: [.kite, .purple, .teal]).ignoresSafeArea()
        VStack(spacing: 24) {
            GlassMark()
            ToastView(toast: Toast(message: "Following Example Blog", systemImage: "heart.fill", isError: false))
            HStack {
                Pill(text: "中文", systemImage: "character.bubble")
                Pill(text: "WordPress", tint: .kite)
            }
        }
    }
}
