import SwiftUI

/// A slowly drifting mesh of color for headers and sign-in screens: the
/// kind of backdrop Liquid Glass reads well over. Still when Reduce Motion
/// is on.
struct MeshBackdrop: View {
    var colors: [Color]
    var animated = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !animated || reduceMotion)) { context in
            let time = animated && !reduceMotion ? context.date.timeIntervalSinceReferenceDate : 0
            MeshGradient(width: 3, height: 3, points: points(at: time), colors: meshColors)
        }
    }

    private var meshColors: [Color] {
        let base = colors.isEmpty ? [Color.kite] : colors
        let a = base[0]
        let b = base[1 % base.count]
        let c = base[2 % base.count]
        let paper: Color = colorScheme == .dark ? Color(white: 0.08) : Color(white: 0.98)
        return [
            a, b.mix(with: paper, by: 0.15), c,
            b.mix(with: paper, by: 0.3), a.mix(with: c, by: 0.5), b,
            c.mix(with: paper, by: 0.35), a.mix(with: paper, by: 0.25), b.mix(with: paper, by: 0.4),
        ]
    }

    private func points(at time: TimeInterval) -> [SIMD2<Float>] {
        let t = Float(time * 0.35)
        let wobble: Float = 0.08
        return [
            [0, 0], [0.5 + wobble * sin(t), 0], [1, 0],
            [0, 0.5 + wobble * cos(t * 0.9)], [0.5 + wobble * cos(t * 1.1), 0.5 + wobble * sin(t * 0.8)], [1, 0.5 + wobble * sin(t * 1.2)],
            [0, 1], [0.5 + wobble * cos(t * 0.7), 1], [1, 1],
        ]
    }
}

/// The colors a blog's header is painted with, from its avatar color.
enum BlogColors {
    static func of(_ host: String) -> [Color] {
        let base = Palette.color(for: host)
        return [base, base.mix(with: .kite, by: 0.45), base.mix(with: .white, by: 0.35)]
    }
}

#Preview {
    MeshBackdrop(colors: [.kite, .purple, .teal])
        .ignoresSafeArea()
}
