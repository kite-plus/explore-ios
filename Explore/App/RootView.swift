import SwiftUI

/// The tab bar: Discover, Blogs and Me. Discover holds the latest,
/// recommended and following streams, as the website does. The bar stays
/// fully open, and search lives at the top of Discover and Blogs.
struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var app = app
        TabView(selection: $app.tab) {
            Tab("Discover", systemImage: "binoculars", value: AppTab.discover) {
                DiscoverView()
            }
            Tab("Blogs", systemImage: "books.vertical", value: AppTab.blogs) {
                BlogsView()
            }
            Tab("Me", systemImage: "person.crop.circle", value: AppTab.me) {
                MeView()
            }
        }
        .tabBarMinimizeBehavior(.never)
        .tabViewStyle(.sidebarAdaptable)
        .overlay(alignment: .top) {
            if let toast = app.toast {
                ToastView(toast: toast)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
                    .onTapGesture { app.dismissToast() }
                    .onAppear {
                        AccessibilityNotification.Announcement(toast.message).post()
                    }
                    .id(toast.id)
            }
        }
        .overlay {
            if let handoff = app.handoff {
                HandoffView(handoff: handoff)
                    .transition(.opacity)
                    .task(id: handoff.id) {
                        guard (try? await Task.sleep(for: .seconds(HandoffView.duration))) != nil else { return }
                        // The page goes once Safari's view covers it. Not on a
                        // timer here: a covered view loses its tasks and would
                        // start this one again when Safari's view closes.
                        let id = handoff.id
                        LinkOpener.open(handoff.url, source: app.sourceTag) { app.endHandoff(id) }
                    }
            }
        }
        .animation(.smooth(duration: 0.2), value: app.handoff)
        .sheet(item: $app.sheet) { sheet in
            switch sheet {
            case let .signIn(mode):
                SignInView(mode: mode)
            case .submit:
                SubmitView()
            case let .report(target):
                ReportView(target: target)
            case let .claim(blog):
                ClaimBlogView(blog: blog)
            }
        }
        .onOpenURL { url in
            app.open(url)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await app.catchUp() }
            }
        }
        .onChange(of: app.pendingPost) {
            if let post = app.takePendingPost() {
                LinkOpener.open(post, source: app.sourceTag)
            }
        }
        .task {
            #if DEBUG
            // Lets screenshots and manual checks start on any screen:
            // launch with -deeplink explore://blogs/example.com
            if let link = UserDefaults.standard.string(forKey: "deeplink"), let url = URL(string: link) {
                app.open(url)
            }
            #endif
            await app.bootstrap()
        }
    }
}
