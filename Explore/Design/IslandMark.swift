import SwiftUI
import UIKit

/// The Explore mark, drawn where the Dynamic Island or the notch covers the
/// screen. Nobody sees it in use, but screenshots and screen recordings
/// leave the cutout out, so they show the mark between the time and the
/// battery. Screens with no cutout, and iPhones held sideways, get nothing.
struct IslandMark: View {
    var body: some View {
        // Inside the safe area, where the reader can see the top inset; the
        // mark is placed above it, measured from the screen's edge.
        GeometryReader { proxy in
            let top = proxy.safeAreaInsets.top
            if let center = Self.cutoutCenter(safeTop: top) {
                mark
                    .position(x: proxy.size.width / 2, y: center - top)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Small enough to stay inside the smallest cutout, about 125 by 37
    /// points, with room for the guess at where it sits. A fixed size keeps
    /// larger text settings from pushing it out.
    private var mark: some View {
        HStack(spacing: 5) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(height: 13)
            Text(verbatim: "Kite")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .fixedSize()
        // A halo in the opposite shade keeps it legible over pages that do
        // not follow the app's appearance, such as Safari's view.
        .shadow(color: Color(.systemBackground), radius: 1)
        .shadow(color: Color(.systemBackground).opacity(0.8), radius: 2.5)
    }

    /// The middle of the cutout, from the top inset it causes. The Dynamic
    /// Island floats below the edge and its inset is about twice its middle;
    /// a notch hangs from the edge and is about 30 points deep.
    static func cutoutCenter(safeTop: CGFloat) -> CGFloat? {
        switch safeTop {
        case 54...: safeTop / 2
        case 40..<54: 15
        default: nil
        }
    }

    /// Puts the mark in a window of its own above the app's, so it also
    /// covers sheets and Safari's view, and never takes a touch.
    static func install() {
        guard UIDevice.current.userInterfaceIdiom == .phone, window == nil,
            let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }
        let window = UIWindow(windowScene: scene)
        let host = UIHostingController(rootView: IslandMark())
        host.view.backgroundColor = .clear
        window.rootViewController = host
        window.windowLevel = .statusBar
        window.backgroundColor = .clear
        window.isUserInteractionEnabled = false
        window.isHidden = false
        Self.window = window
    }

    /// Hides the mark while the app is not in front, so the app switcher's
    /// picture of the app does not show it.
    static func setVisible(_ visible: Bool) {
        window?.isHidden = !visible
    }

    private static var window: UIWindow?
}
