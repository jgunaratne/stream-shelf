import SwiftUI

struct MoviesView: View {
    let sectionKey: String
    let sectionTitle: String
    let sectionType: String
    let genreKey: String?
    let genreTitle: String?

    @StateObject private var vm: MoviesViewModel
    @State private var searchText = ""
    @State private var layout: Layout = .grid

    enum Layout { case grid, list }

    private let columns = [GridItem(.adaptive(minimum: 110, maximum: 150), spacing: 12)]

    init(
        sectionKey: String,
        sectionTitle: String,
        sectionType: String,
        genreKey: String? = nil,
        genreTitle: String? = nil
    ) {
        self.sectionKey = sectionKey
        self.sectionTitle = sectionTitle
        self.sectionType = sectionType
        self.genreKey = genreKey
        self.genreTitle = genreTitle
        _vm = StateObject(
            wrappedValue: MoviesViewModel(
                sectionKey: sectionKey,
                sectionTitle: sectionTitle,
                sectionType: sectionType,
                genreKey: genreKey,
                genreTitle: genreTitle
            )
        )
    }

    private var filtered: [PlexMovie] {
        guard !searchText.isEmpty else { return vm.movies }
        return vm.movies.filter { item in
            item.title.localizedCaseInsensitiveContains(searchText)
            || (item.browseSubtitle?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        Group {
            if vm.isLoading {
                VStack(spacing: StreamShelfTheme.Spacing.lg) {
                    ProgressView()
                        .tint(StreamShelfTheme.Colors.accent)
                    Text("Loading titles…")
                        .font(.subheadline)
                        .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(StreamShelfTheme.Colors.appBackground)
            } else if let err = vm.errorMessage {
                ErrorView(message: err) {
                    Task { await vm.load() }
                }
            } else if vm.movies.isEmpty {
                VStack(spacing: StreamShelfTheme.Spacing.lg) {
                    if vm.isMusicLibrary && genreKey == nil {
                        musicBrowsePicker
                            .padding(.horizontal, StreamShelfTheme.Spacing.lg)
                    }

                    ContentUnavailableView(
                        emptyTitle,
                        systemImage: emptySystemImage,
                        description: Text("This library appears to be empty.")
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    if vm.isMusicLibrary && genreKey == nil {
                        musicBrowsePicker
                            .padding(.horizontal, StreamShelfTheme.Spacing.lg)
                            .padding(.top, StreamShelfTheme.Spacing.md)
                            .padding(.bottom, StreamShelfTheme.Spacing.xs)
                    }

                    ScrollView {
                        if layout == .grid {
                            LazyVGrid(columns: columns, spacing: StreamShelfTheme.Spacing.lg) {
                                ForEach(filtered) { movie in
                                    NavigationLink(destination: MovieDetailView(movie: movie)) {
                                        MovieGridCell(movie: movie)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding()
                        } else {
                            LazyVStack(spacing: StreamShelfTheme.Spacing.sm) {
                                ForEach(filtered) { movie in
                                    NavigationLink(destination: MovieDetailView(movie: movie)) {
                                        MovieListRow(movie: movie)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(StreamShelfTheme.Spacing.lg)
                        }
                    }
                    .background(StreamShelfTheme.Colors.appBackground)
                }
            }
        }
        .navigationTitle(genreTitle ?? sectionTitle)
        .searchable(text: $searchText, prompt: "Search titles")
        .background(StreamShelfTheme.Colors.appBackground.ignoresSafeArea())
        .toolbarBackground(StreamShelfTheme.Colors.appBackground, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        layout = layout == .grid ? .list : .grid
                    }
                } label: {
                    Image(systemName: layout == .grid ? "list.bullet" : "square.grid.2x2")
                }
            }
        }
        .task { await vm.load() }
        .onChange(of: vm.musicBrowseMode) { _, _ in
            searchText = ""
            Task { await vm.load() }
        }
        .refreshable { await vm.load() }
    }

    private var musicBrowsePicker: some View {
        Picker("Browse Music By", selection: $vm.musicBrowseMode) {
            ForEach(MusicLibraryBrowseMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var emptyTitle: String {
        switch sectionType {
        case "show": return "No Shows"
        case "artist", "music": return "No \(vm.musicBrowseMode.title)"
        default: return "No Titles"
        }
    }

    private var emptySystemImage: String {
        switch sectionType {
        case "show": return "tv"
        case "artist", "music": return "music.note"
        default: return "film"
        }
    }
}

// MARK: - Grid Cell

struct MovieGridCell: View {
    let movie: PlexMovie
    private let config = PlexConfig.shared

    var body: some View {
        VStack(alignment: .leading, spacing: StreamShelfTheme.Spacing.xs) {
            posterStack
            titleArea
        }
        .frame(width: StreamShelfTheme.Dimensions.posterWidth)
    }

    private var posterStack: some View {
        ZStack(alignment: .bottom) {
            PosterView(
                url: config.imageURL(for: movie.artworkPath, width: 200, height: movie.isMusicItem ? 200 : 300),
                width: StreamShelfTheme.Dimensions.posterWidth,
                height: movie.isMusicItem ? StreamShelfTheme.Dimensions.posterWidth : StreamShelfTheme.Dimensions.posterHeight
            )

            if let rating = movie.rating, !movie.isMusicItem {
                ratingBadge(rating)
            }
        }
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
    }

    private func ratingBadge(_ rating: Double) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "star.fill")
                .font(.system(size: 9))
                .foregroundStyle(.yellow)
            Text(String(format: "%.1f", rating))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.black.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var titleArea: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(movie.title)
                .font(StreamShelfTheme.Typography.cardTitle)
                .lineLimit(2)
                .foregroundStyle(StreamShelfTheme.Colors.primaryText)

            if let subtitle = movie.browseSubtitle {
                Text(subtitle)
                    .font(StreamShelfTheme.Typography.cardSubtitle)
                    .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
            }
        }
    }
}

// MARK: - List Row

struct MovieListRow: View {
    let movie: PlexMovie
    private let config = PlexConfig.shared

    var body: some View {
        HStack(spacing: StreamShelfTheme.Spacing.md) {
            PosterView(
                url: config.imageURL(for: movie.artworkPath, width: 100, height: movie.isMusicItem ? 100 : 150),
                width: 46,
                height: movie.isMusicItem ? 46 : 68,
                cornerRadius: 6
            )

            VStack(alignment: .leading, spacing: StreamShelfTheme.Spacing.xs) {
                Text(movie.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundStyle(StreamShelfTheme.Colors.primaryText)

                HStack(spacing: StreamShelfTheme.Spacing.sm) {
                    if let subtitle = movie.browseSubtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
                    }
                    if let rating = movie.rating, !movie.isMusicItem {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", rating))
                        }
                        .font(.caption2)
                        .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
                    }
                    if let cr = movie.contentRating {
                        Text(cr)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(StreamShelfTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(StreamShelfTheme.Colors.tertiaryText)
                .font(.caption)
        }
        .padding(StreamShelfTheme.Spacing.md)
        .background(StreamShelfTheme.Colors.surface, in: RoundedRectangle(cornerRadius: StreamShelfTheme.Dimensions.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: StreamShelfTheme.Dimensions.cardCornerRadius)
                .stroke(StreamShelfTheme.Colors.separator)
        )
    }
}
