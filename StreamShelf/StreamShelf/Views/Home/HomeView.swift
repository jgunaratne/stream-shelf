import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: StreamShelfTheme.Spacing.xl) {
                    if vm.isLoading {
                        loadingView
                    } else {
                        if let error = vm.errorMessage, !vm.hasContent {
                            ErrorView(message: error) {
                                Task { await vm.load() }
                            }
                            .padding(.horizontal, StreamShelfTheme.Spacing.lg)
                        }
                        if let featuredItem {
                            NavigationLink(destination: MovieDetailView(movie: featuredItem)) {
                                FeaturedMovieCard(movie: featuredItem)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, StreamShelfTheme.Spacing.lg)
                        }
                        if !vm.onDeckItems.isEmpty {
                            movieShelf(title: "Continue Watching", icon: "play.circle.fill", movies: vm.onDeckItems)
                        }
                        if !vm.recommended.isEmpty {
                            movieShelf(title: "Top Picks", icon: "sparkles", movies: vm.recommended)
                        }
                        if !vm.recentlyAdded.isEmpty {
                            movieShelf(title: "Recently Added", icon: "clock.fill", movies: vm.recentlyAdded)
                        }
                        if !vm.hasContent && vm.errorMessage == nil {
                            emptyStateView
                        }
                        librariesSection
                    }
                }
                .padding(.vertical, StreamShelfTheme.Spacing.lg)
            }
            .background(StreamShelfTheme.Colors.appBackground.ignoresSafeArea())
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(StreamShelfTheme.Colors.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(StreamShelfTheme.Colors.accent)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .task { await vm.load() }
            .refreshable { await vm.load() }
        }
    }

    private var featuredItem: PlexMovie? {
        vm.onDeckItems.first ?? vm.recentlyAdded.first ?? vm.recommended.first
    }

    private var loadingView: some View {
        VStack(spacing: StreamShelfTheme.Spacing.lg) {
            ProgressView()
                .tint(StreamShelfTheme.Colors.accent)
            Text("Loading your library…")
                .font(StreamShelfTheme.Typography.cardSubtitle)
                .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var emptyStateView: some View {
        VStack(spacing: StreamShelfTheme.Spacing.md) {
            Image(systemName: "film.stack")
                .font(.system(size: 40))
                .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
            Text("No content available yet")
                .font(.subheadline)
                .foregroundStyle(StreamShelfTheme.Colors.primaryText)
            Text("Browse your libraries below.")
                .font(.caption)
                .foregroundStyle(StreamShelfTheme.Colors.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, StreamShelfTheme.Spacing.xl)
    }

    private func movieShelf(title: String, icon: String, movies: [PlexMovie]) -> some View {
        VStack(alignment: .leading, spacing: StreamShelfTheme.Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(StreamShelfTheme.Colors.accent)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(StreamShelfTheme.Typography.sectionHeader)
            }
            .padding(.horizontal, StreamShelfTheme.Spacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: StreamShelfTheme.Spacing.md) {
                    ForEach(movies) { movie in
                        NavigationLink(destination: MovieDetailView(movie: movie)) {
                            ShelfMovieCard(movie: movie)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, StreamShelfTheme.Spacing.lg)
                .padding(.vertical, StreamShelfTheme.Spacing.xs)
            }
        }
    }

    private var librariesSection: some View {
        VStack(alignment: .leading, spacing: StreamShelfTheme.Spacing.sm) {
            Text("Libraries")
                .font(StreamShelfTheme.Typography.sectionHeader)
                .padding(.horizontal, StreamShelfTheme.Spacing.lg)

            NavigationLink(destination: LibrarySectionsView()) {
                HStack(spacing: StreamShelfTheme.Spacing.md) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 18))
                        .foregroundStyle(StreamShelfTheme.Colors.accent)
                        .frame(width: 36, height: 36)
                        .background(StreamShelfTheme.Colors.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Browse All Libraries")
                            .font(.body)
                            .foregroundStyle(StreamShelfTheme.Colors.primaryText)
                        Text("Drill into the video and music libraries on your server")
                            .font(.caption)
                            .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(StreamShelfTheme.Colors.tertiaryText)
                }
                .padding(StreamShelfTheme.Spacing.md)
                .streamShelfCardStyle()
            }
            .padding(.horizontal, StreamShelfTheme.Spacing.lg)
        }
    }
}

private struct ShelfMovieCard: View {
    let movie: PlexMovie
    @EnvironmentObject private var config: PlexConfig

    var body: some View {
        VStack(alignment: .leading, spacing: StreamShelfTheme.Spacing.xs) {
            ZStack(alignment: .bottomLeading) {
                PosterView(
                    url: config.imageURL(for: movie.thumb, width: 200, height: 300),
                    width: StreamShelfTheme.Dimensions.shelfPosterWidth,
                    height: StreamShelfTheme.Dimensions.shelfPosterHeight
                )

                if movie.hasProgress {
                    ProgressCapsule(progress: movie.progressFraction)
                        .padding(8)
                }
            }

            Text(movie.title)
                .font(StreamShelfTheme.Typography.cardTitle)
                .foregroundStyle(StreamShelfTheme.Colors.primaryText)
                .lineLimit(2)
                .frame(width: StreamShelfTheme.Dimensions.shelfPosterWidth, alignment: .leading)

            if let year = movie.year {
                Text(String(year))
                    .font(StreamShelfTheme.Typography.cardSubtitle)
                    .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
            }
        }
        .frame(width: StreamShelfTheme.Dimensions.shelfPosterWidth)
    }
}

private struct FeaturedMovieCard: View {
    let movie: PlexMovie
    @EnvironmentObject private var config: PlexConfig

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: config.imageURL(for: movie.art ?? movie.thumb, width: 900, height: 500)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    StreamShelfTheme.Colors.surfaceElevated
                        .overlay(
                            Image(systemName: movie.isShow ? "tv" : "film")
                                .font(.system(size: 42, weight: .semibold))
                                .foregroundStyle(StreamShelfTheme.Colors.tertiaryText)
                        )
                }
            }
            .frame(height: 220)
            .clipped()

            LinearGradient(
                colors: [.black.opacity(0.08), .black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: StreamShelfTheme.Spacing.sm) {
                Text(movie.hasProgress ? "Continue Watching" : "Featured")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(StreamShelfTheme.Colors.accent)
                Text(movie.playbackTitle)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                if let subtitle = movie.browseSubtitle {
                    Text(subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.74))
                }
                Label(movie.hasProgress ? "Resume" : "View Details", systemImage: movie.hasProgress ? "play.fill" : "info.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(StreamShelfTheme.Colors.accentGradient, in: Capsule())
                    .padding(.top, StreamShelfTheme.Spacing.xs)
            }
            .padding(StreamShelfTheme.Spacing.lg)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: StreamShelfTheme.Dimensions.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: StreamShelfTheme.Dimensions.cardCornerRadius)
                .stroke(StreamShelfTheme.Colors.separator)
        )
    }
}

private struct ProgressCapsule: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.28))
                Capsule()
                    .fill(StreamShelfTheme.Colors.accent)
                    .frame(width: max(proxy.size.width * progress, 10))
            }
        }
        .frame(height: 5)
    }
}

private extension PlexMovie {
    var progressFraction: Double {
        guard let duration, duration > 0, let viewOffset else { return 0 }
        return min(max(Double(viewOffset) / Double(duration), 0), 1)
    }
}

#Preview {
    HomeView()
        .environmentObject(PlexConfig.shared)
}
