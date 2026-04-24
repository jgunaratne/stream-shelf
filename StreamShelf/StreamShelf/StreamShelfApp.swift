import SwiftUI

@main
struct StreamShelfApp: App {
    @StateObject private var config = PlexConfig.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(config)
                .preferredColorScheme(.dark)
        }
    }
}
