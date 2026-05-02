import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var config: PlexConfig
    @EnvironmentObject private var audioPlayer: AudioPlaybackManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSettings = false

    var body: some View {
        if config.isConfigured {
            TabView {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }

                SearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }

                GenresView()
                    .tabItem {
                        Label("Genres", systemImage: "tag.fill")
                    }

                FavoritesView()
                    .tabItem {
                        Label("Favorites", systemImage: "heart.fill")
                    }
            }
            .tint(StreamShelfTheme.Colors.accent)
            .background(StreamShelfTheme.Colors.appBackground)
            .safeAreaInset(edge: .bottom) {
                MiniPlayerView()
            }
            .fullScreenCover(isPresented: $audioPlayer.isFullPlayerPresented) {
                if let item = audioPlayer.currentItem {
                    AudioPlayerView(item: item, queue: audioPlayer.queue)
                }
            }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                audioPlayer.updatePlaybackPosition()
            }
            .onChange(of: scenePhase) { _, newPhase in
                audioPlayer.handleScenePhaseChange(newPhase)
            }
        } else {
            setupScreen
        }
    }

    private var setupScreen: some View {
        VStack(spacing: StreamShelfTheme.Spacing.xl) {
            Spacer()

            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(StreamShelfTheme.Colors.accentGradient)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: StreamShelfTheme.Spacing.sm) {
                Text("StreamShelf")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(StreamShelfTheme.Colors.primaryText)
                Text("Connect to your media server to browse, resume, and stream your library.")
                    .font(.subheadline)
                    .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, StreamShelfTheme.Spacing.xxl)
            }

            Button {
                showSettings = true
            } label: {
                Label("Configure Server", systemImage: "gearshape")
                    .font(.headline)
                    .frame(maxWidth: 240)
            }
            .buttonStyle(.borderedProminent)
            .tint(StreamShelfTheme.Colors.accent)
            .controlSize(.large)

            Spacer()
        }
        .padding(StreamShelfTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(StreamShelfTheme.Colors.appBackground.ignoresSafeArea())
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
        .environmentObject(PlexConfig.shared)
}
