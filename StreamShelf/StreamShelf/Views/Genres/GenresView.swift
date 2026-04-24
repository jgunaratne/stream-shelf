import SwiftUI

struct GenresView: View {
    @StateObject private var vm = GenresViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    loadingView
                } else if let error = vm.errorMessage {
                    ErrorView(message: error) {
                        Task { await vm.load() }
                    }
                } else if !vm.hasGenres {
                    ContentUnavailableView(
                        "No Genres",
                        systemImage: "tag",
                        description: Text("No genres were returned by your Plex libraries.")
                    )
                } else {
                    genreList
                }
            }
            .navigationTitle("Genres")
            .background(StreamShelfTheme.Colors.appBackground.ignoresSafeArea())
            .toolbarBackground(StreamShelfTheme.Colors.appBackground, for: .navigationBar)
            .task { await vm.load() }
            .refreshable { await vm.load() }
        }
    }

    private var loadingView: some View {
        VStack(spacing: StreamShelfTheme.Spacing.lg) {
            ProgressView()
                .tint(StreamShelfTheme.Colors.accent)
            Text("Loading genres...")
                .font(.subheadline)
                .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(StreamShelfTheme.Colors.appBackground)
    }

    private var genreList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: StreamShelfTheme.Spacing.xl) {
                ForEach(vm.groups) { group in
                    genreGroup(group)
                }
            }
            .padding(StreamShelfTheme.Spacing.lg)
        }
        .background(StreamShelfTheme.Colors.appBackground)
    }

    private func genreGroup(_ group: GenreLibraryGroup) -> some View {
        VStack(alignment: .leading, spacing: StreamShelfTheme.Spacing.sm) {
            Label(group.section.title, systemImage: iconName(for: group.section))
                .font(StreamShelfTheme.Typography.sectionHeader)
                .foregroundStyle(StreamShelfTheme.Colors.primaryText)

            LazyVStack(spacing: StreamShelfTheme.Spacing.sm) {
                ForEach(group.genres) { genre in
                    NavigationLink(
                        destination: MoviesView(
                            sectionKey: group.section.key,
                            sectionTitle: group.section.title,
                            sectionType: group.section.type,
                            genreKey: genre.key,
                            genreTitle: genre.title
                        )
                    ) {
                        GenreRow(genre: genre, section: group.section)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func iconName(for section: PlexLibrarySection) -> String {
        switch section.type {
        case "movie":
            return "film"
        case "show":
            return "tv"
        case "artist", "music":
            return "music.note"
        default:
            return "folder"
        }
    }
}

private struct GenreRow: View {
    let genre: PlexGenre
    let section: PlexLibrarySection

    var body: some View {
        HStack(spacing: StreamShelfTheme.Spacing.md) {
            Image(systemName: "tag.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(StreamShelfTheme.Colors.accent)
                .frame(width: 36, height: 36)
                .background(StreamShelfTheme.Colors.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(genre.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(StreamShelfTheme.Colors.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(section.isMusicSection ? "Music" : section.type.capitalized)
                    .font(.caption)
                    .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(StreamShelfTheme.Colors.tertiaryText)
        }
        .padding(StreamShelfTheme.Spacing.md)
        .background(StreamShelfTheme.Colors.surface, in: RoundedRectangle(cornerRadius: StreamShelfTheme.Dimensions.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: StreamShelfTheme.Dimensions.cardCornerRadius)
                .stroke(StreamShelfTheme.Colors.separator)
        )
    }
}

#Preview {
    GenresView()
        .environmentObject(PlexConfig.shared)
}
