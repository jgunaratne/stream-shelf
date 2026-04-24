import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var config: PlexConfig
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
