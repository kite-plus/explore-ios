import SwiftUI

@main
struct ExploreApp: App {
    @State private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .tint(.kite)
        }
    }
}
