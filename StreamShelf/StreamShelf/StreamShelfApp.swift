import SwiftUI

@main
struct StreamShelfApp: App {
    @StateObject private var config = PlexConfig.shared
    @StateObject private var audioPlayer = AudioPlaybackManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(config)
                .environmentObject(audioPlayer)
                .preferredColorScheme(.dark)
        }
    }
}
