import SwiftUI

/// Pushes a route onto the current tab's stack; for menus and other places
/// where a NavigationLink does not fit.
nonisolated struct NavigateAction: Sendable {
    let action: @MainActor @Sendable (Route) -> Void

    @MainActor
    func callAsFunction(_ route: Route) {
        action(route)
    }
}

extension EnvironmentValues {
    @Entry var navigate = NavigateAction { _ in }
    @Entry var zoomNamespace: Namespace.ID?
}

extension View {
    /// The destinations every tab can push.
    func exploreDestinations() -> some View {
        navigationDestination(for: Route.self) { route in
            RouteDestination(route: route)
        }
    }

    /// Zooms out of the source with the same id, when there is one.
    @ViewBuilder
    func zoomTransition(from id: String?, in namespace: Namespace.ID?) -> some View {
        if let id, let namespace {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }

    /// Marks a view as the place a zoom transition starts from.
    @ViewBuilder
    func zoomSource(_ id: String?, in namespace: Namespace.ID?) -> some View {
        if let id, let namespace {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }
}

private struct RouteDestination: View {
    let route: Route

    @Environment(\.zoomNamespace) private var zoomNamespace

    var body: some View {
        switch route {
        case let .blog(ref, zoomID):
            BlogDetailView(ref: ref)
                .zoomTransition(from: zoomID, in: zoomNamespace)
        case let .topic(slug, zoomID):
            TopicView(slug: slug)
                .zoomTransition(from: zoomID, in: zoomNamespace)
        case .search:
            SearchScreen()
        case let .notice(id, preview):
            NoticeDetailView(id: id, preview: preview)
        case let .submission(id):
            SubmissionView(id: id)
        case .submissions:
            SubmissionsView()
        case .subscriptions:
            SubscriptionsView()
        case .ownedBlogs:
            OwnedBlogsView()
        case .server:
            ServerView()
        case .about:
            AboutView()
        }
    }
}

/// A navigation stack with the app's destinations and a navigate action
/// bound to its path.
struct ExploreStack<Root: View>: View {
    let tab: AppTab
    @ViewBuilder var root: Root

    @Environment(AppModel.self) private var app
    @State private var path = NavigationPath()
    @Namespace private var zoom

    var body: some View {
        NavigationStack(path: $path) {
            root.exploreDestinations()
        }
        .environment(\.navigate, NavigateAction { route in path.append(route) })
        .environment(\.zoomNamespace, zoom)
        .onChange(of: app.pendingRoute?.route, initial: true) {
            if let route = app.takePendingRoute(for: tab) {
                path.append(route)
            }
        }
    }
}
