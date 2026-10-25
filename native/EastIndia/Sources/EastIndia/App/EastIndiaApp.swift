import SwiftUI

@main
struct EastIndiaApp: App {
    var body: some Scene {
        WindowGroup {
            ExamContainerView()
                .frame(minWidth: 980, minHeight: 660)
        }
        .windowToolbarStyle(.unifiedCompact)
    }
}
