import SwiftUI

/// Shows the app's toasts above Safari's view, which covers the toasts in
/// the app's own window while a post is open. It never takes a touch.
enum ToastWindow {
    private static var window: UIWindow?

    static func show(for app: AppModel) {
        if window == nil {
            guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
            let window = UIWindow(windowScene: scene)
            let host = UIHostingController(rootView: ToastLayer().environment(app))
            host.view.backgroundColor = .clear
            window.rootViewController = host
            window.windowLevel = .normal + 1
            window.backgroundColor = .clear
            window.isUserInteractionEnabled = false
            Self.window = window
        }
        window?.isHidden = false
    }

    static func hide() {
        window?.isHidden = true
    }
}

private struct ToastLayer: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        Color.clear
            .overlay(alignment: .top) {
                if let toast = app.toast {
                    ToastView(toast: toast)
                        .padding(.top, 6)
                        .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
                        .id(toast.id)
                }
            }
            .accessibilityHidden(true)
    }
}
