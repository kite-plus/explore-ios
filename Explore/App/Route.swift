import Foundation

/// Screens pushed onto a tab's navigation stack.
nonisolated enum Route: Hashable, Sendable {
    /// A blog's page. zoomID names the view it zooms out of, if any.
    case blog(BlogRef, zoomID: String? = nil)
    case topic(String, zoomID: String? = nil)
    case search
    case submission(String)
    case submissions
    case subscriptions
    case ownedBlogs
    case server
    case about
}
