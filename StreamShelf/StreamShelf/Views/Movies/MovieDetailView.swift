import SwiftUI

struct MovieDetailView: View {
    @StateObject private var vm: MovieDetailViewModel
    @State private var playbackSelection: PlaybackSelection?
    @EnvironmentObject private var config: PlexConfig
    @EnvironmentObject private var audioPlayer: AudioPlaybackManager

    init(movie: PlexMovie) {
        _vm = StateObject(wrappedValue: MovieDetailViewModel(movie: movie))
    }

    var body: some View {
        GeometryReader { proxy in
            let layoutWidth = min(max(proxy.size.width - (StreamShelfTheme.Spacing.lg * 2), 280), 760)
            let posterWidth = min(max(layoutWidth * 0.30, 112), 168)

            ScrollView {
                VStack(spacing: StreamShelfTheme.Spacing.xl) {
                    heroCard(width: layoutWidth)
                    headerSection(posterWidth: posterWidth)

                    if !metaChips.isEmpty {
                        metaSection
                    }

                    if vm.primaryPlaybackItem != nil || config.isFavorite(movieID: vm.movie.id) {
                        actionSection
                    }

                    if let error = vm.errorMessage {
                        DetailSectionCard {
                            Label(error, systemImage: "wifi.exclamationmark")
                                .font(.subheadline)
                                .foregroundStyle(StreamShelfTheme.Colors.warning)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if let summary = vm.movie.summary, !summary.isEmpty {
                        DetailSectionCard(title: "Overview") {
                            Text(summary)
                                .font(.body)
                                .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
                                .lineSpacing(3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if vm.movie.isShow {
                        episodesSection
                    }

                    if vm.movie.isArtist {
                        artistAlbumsSection
                    }

                    if vm.movie.isAlbum {
                        albumTracksSection
                    }

                    if hasDetails {
                        detailsSection
                    }
                }
                .frame(maxWidth: layoutWidth)
                .padding(.horizontal, StreamShelfTheme.Spacing.lg)
                .padding(.top, StreamShelfTheme.Spacing.lg)
                .padding(.bottom, StreamShelfTheme.Spacing.xxl)
                .frame(maxWidth: .infinity)
            }
            .background(StreamShelfTheme.Colors.appBackground)
        }
        .background(StreamShelfTheme.Colors.appBackground.ignoresSafeArea())
        .navigationTitle(vm.movie.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(StreamShelfTheme.Colors.appBackground, for: .navigationBar)
        .task { await vm.loadDetail() }
        .fullScreenCover(item: $playbackSelection) { selection in
            playbackScreen(for: selection)
        }
        .overlay {
            if vm.isLoading {
                ZStack {
                    Color.black.opacity(0.28).ignoresSafeArea()
                    ProgressView()
                        .padding(StreamShelfTheme.Spacing.lg)
                        .background(StreamShelfTheme.Colors.surface, in: RoundedRectangle(cornerRadius: StreamShelfTheme.Dimensions.cardCornerRadius))
                }
            }
        }
    }

    private var metaChips: [MetaChipRow.ChipItem] {
        var chips: [MetaChipRow.ChipItem] = []

        if let subtitle = vm.movie.browseSubtitle {
            chips.append(.init(text: subtitle))
        }
        if let year = vm.movie.year {
            chips.append(.init(text: String(year)))
        }
        if let releaseDate = vm.releaseDateLabel {
            chips.append(.init(text: releaseDate, icon: "calendar"))
        }
        if !vm.durationString.isEmpty {
            chips.append(.init(text: vm.durationString, icon: "clock"))
        }
        if let contentRating = vm.movie.contentRating {
            chips.append(.init(text: contentRating))
        }
        if let rating = vm.movie.rating {
            chips.append(.init(text: String(format: "%.1f", rating), icon: "star.fill"))
        }

        return chips
    }

    private var hasDetails: Bool {
        vm.movie.studio != nil || !vm.directorsLabel.isEmpty || !vm.writersLabel.isEmpty || !vm.castLabel.isEmpty
    }

    private func heroCard(width: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: vm.backdropURL(width: 1000)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    StreamShelfTheme.Colors.surfaceElevated
                        .overlay(
                            Image(systemName: heroSymbol)
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundStyle(StreamShelfTheme.Colors.tertiaryText)
                        )
                }
            }
            .frame(height: min(max(width * 0.50, 180), 280))
            .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.18), .black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: StreamShelfTheme.Spacing.xs) {
                Label(heroLabel, systemImage: heroSymbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))

                Text(heroTitle)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(3)

                if vm.movie.hasProgress {
                    ProgressView(value: vm.progressFraction)
                        .tint(StreamShelfTheme.Colors.accent)
                        .frame(maxWidth: 180)
                }
            }
            .padding(StreamShelfTheme.Spacing.lg)
        }
        .clipShape(RoundedRectangle(cornerRadius: StreamShelfTheme.Dimensions.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: StreamShelfTheme.Dimensions.cardCornerRadius)
                .stroke(StreamShelfTheme.Colors.separator)
        )
    }

    private func headerSection(posterWidth: CGFloat) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: StreamShelfTheme.Spacing.lg) {
                posterBlock(width: posterWidth)
                headerText
                favoriteButton
            }

            VStack(alignment: .leading, spacing: StreamShelfTheme.Spacing.lg) {
                HStack(alignment: .top, spacing: StreamShelfTheme.Spacing.md) {
                    posterBlock(width: posterWidth)
                    Spacer(minLength: 0)
                    favoriteButton
                }
                headerText
            }
        }
    }

    private func posterBlock(width: CGFloat) -> some View {
        PosterView(
            url: vm.posterURL(width: Int(width * 2)),
            width: width,
            height: vm.movie.isMusicItem ? width : width * 1.5,
            cornerRadius: StreamShelfTheme.Dimensions.posterCornerRadius
        )
        .overlay(
            RoundedRectangle(cornerRadius: StreamShelfTheme.Dimensions.posterCornerRadius)
                .stroke(StreamShelfTheme.Colors.separator)
        )
        .shadow(color: .black.opacity(0.18), radius: 20, y: 8)
    }

    private var headerText: some View {
        VStack(alignment: .leading, spacing: StreamShelfTheme.Spacing.sm) {
            Text(vm.movie.title)
                .font(StreamShelfTheme.Typography.heroTitle)
                .foregroundStyle(StreamShelfTheme.Colors.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let tagline = vm.movie.tagline, !tagline.isEmpty {
                Text(tagline)
                    .font(.subheadline)
                    .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !vm.genreString.isEmpty {
                Text(vm.genreString)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(StreamShelfTheme.Colors.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var favoriteButton: some View {
        Button {
            config.toggleFavorite(movieID: vm.movie.id)
        } label: {
            Image(systemName: config.isFavorite(movieID: vm.movie.id) ? "heart.fill" : "heart")
                .font(.title3.weight(.semibold))
                .foregroundStyle(config.isFavorite(movieID: vm.movie.id) ? Color.pink : StreamShelfTheme.Colors.secondaryText)
                .frame(width: 44, height: 44)
                .background(StreamShelfTheme.Colors.surfaceElevated, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(config.isFavorite(movieID: vm.movie.id) ? "Remove favorite" : "Add favorite")
    }

    private var metaSection: some View {
        DetailSectionCard {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 110), alignment: .leading)],
                alignment: .leading,
                spacing: StreamShelfTheme.Spacing.sm
            ) {
                ForEach(metaChips) { chip in
                    MetaChip(text: chip.text, icon: chip.icon)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: StreamShelfTheme.Spacing.sm) {
            Button {
                if let item = vm.primaryPlaybackItem {
                    play(item)
                }
            } label: {
                HStack(spacing: StreamShelfTheme.Spacing.sm) {
                    Image(systemName: vm.primaryPlaybackItem?.hasProgress == true ? "play.fill" : "play.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text(vm.primaryActionTitle)
                        .font(.system(size: 17, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    if vm.primaryPlaybackItem != nil {
                        StreamShelfTheme.Colors.accentGradient
                    } else {
                        StreamShelfTheme.Colors.surface
                    }
                }
                .foregroundStyle(vm.primaryPlaybackItem != nil ? Color.white : StreamShelfTheme.Colors.tertiaryText)
                .clipShape(RoundedRectangle(cornerRadius: StreamShelfTheme.Dimensions.cardCornerRadius))
            }
            .disabled(vm.primaryPlaybackItem == nil)

            if config.isFavorite(movieID: vm.movie.id) {
                Label("Saved to Favorites", systemImage: "heart.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.pink)
            }
        }
    }

    private var episodesSection: some View {
        DetailSectionCard(title: "Episodes") {
            if vm.episodes.isEmpty, !vm.isLoading {
                Text("No episodes were returned for this show.")
                    .font(.subheadline)
                    .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: StreamShelfTheme.Spacing.sm) {
                    ForEach(vm.episodes) { episode in
                        Button {
                            playbackSelection = .video(episode)
                        } label: {
                            EpisodeRow(episode: episode)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var artistAlbumsSection: some View {
        DetailSectionCard(title: "Albums") {
            if vm.albums.isEmpty, !vm.isLoading {
                Text("No albums were returned for this artist.")
                    .font(.subheadline)
                    .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: StreamShelfTheme.Spacing.sm) {
                    ForEach(vm.albums) { album in
                        NavigationLink(destination: MovieDetailView(movie: album)) {
                            MusicItemRow(item: album, accessorySystemImage: "chevron.right")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var albumTracksSection: some View {
        DetailSectionCard(title: "Tracks") {
            if vm.tracks.isEmpty, !vm.isLoading {
                Text("No tracks were returned for this album.")
                    .font(.subheadline)
                    .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: StreamShelfTheme.Spacing.sm) {
                    ForEach(vm.tracks) { track in
                        Button {
                            play(track)
                        } label: {
                            MusicItemRow(item: track, accessorySystemImage: track.hasProgress ? "play.fill" : "play.circle")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var detailsSection: some View {
        DetailSectionCard(title: "Details") {
            VStack(alignment: .leading, spacing: StreamShelfTheme.Spacing.md) {
                if let studio = vm.movie.studio {
                    DetailInfoRow(title: "Studio", value: studio, systemImage: "building.2")
                }
                if !vm.directorsLabel.isEmpty {
                    DetailInfoRow(title: "Director", value: vm.directorsLabel, systemImage: "video")
                }
                if !vm.writersLabel.isEmpty {
                    DetailInfoRow(title: "Writers", value: vm.writersLabel, systemImage: "pencil")
                }
                if !vm.castLabel.isEmpty {
                    DetailInfoRow(title: "Cast", value: vm.castLabel, systemImage: "person.3")
                }
            }
        }
    }

    @ViewBuilder
    private func playbackScreen(for selection: PlaybackSelection) -> some View {
        switch selection.kind {
        case .video(let item):
            VideoPlayerView(item: item, title: item.playbackTitle)
        }
    }

    private func play(_ item: PlexMovie) {
        if item.isTrack {
            audioPlayer.play(item: item, queue: audioQueue(containing: item))
        } else {
            playbackSelection = .video(item)
        }
    }

    private func audioQueue(containing item: PlexMovie) -> [PlexMovie] {
        guard !vm.tracks.isEmpty else { return [item] }
        if vm.tracks.contains(where: { $0.id == item.id }) {
            return vm.tracks
        }
        return [item] + vm.tracks
    }

    private var heroTitle: String {
        vm.movie.playbackTitle
    }

    private var heroLabel: String {
        if vm.movie.isArtist {
            return "Artist"
        }
        if vm.movie.isAlbum {
            return "Album"
        }
        if vm.movie.isTrack {
            return "Track"
        }
        if vm.movie.isEpisode {
            return "Episode"
        }
        if vm.movie.isShow {
            return "TV Show"
        }
        return "Movie"
    }

    private var heroSymbol: String {
        if vm.movie.isMusicItem {
            return "music.note"
        }
        if vm.movie.isEpisode || vm.movie.isShow {
            return "tv"
        }
        return "film"
    }
}

private struct PlaybackSelection: Identifiable {
    enum Kind {
        case video(PlexMovie)
    }

    let id = UUID()
    let kind: Kind

    static func video(_ item: PlexMovie) -> PlaybackSelection {
        PlaybackSelection(kind: .video(item))
    }
}

private struct DetailSectionCard<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StreamShelfTheme.Spacing.md) {
            if let title {
                Text(title)
                    .font(StreamShelfTheme.Typography.sectionHeader)
                    .foregroundStyle(StreamShelfTheme.Colors.primaryText)
            }

            content
        }
        .padding(StreamShelfTheme.Spacing.lg)
        .background(StreamShelfTheme.Colors.surface, in: RoundedRectangle(cornerRadius: StreamShelfTheme.Dimensions.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: StreamShelfTheme.Dimensions.cardCornerRadius)
                .stroke(StreamShelfTheme.Colors.separator)
        )
    }
}

private struct DetailInfoRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(StreamShelfTheme.Colors.tertiaryText)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EpisodeRow: View {
    let episode: PlexMovie

    var body: some View {
        HStack(spacing: StreamShelfTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(episode.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(StreamShelfTheme.Colors.primaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle = episode.browseSubtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
                }
            }

            Spacer(minLength: StreamShelfTheme.Spacing.sm)

            Image(systemName: episode.hasProgress ? "play.fill" : "play.circle")
                .foregroundStyle(StreamShelfTheme.Colors.accent)
                .font(.headline)
        }
        .padding(StreamShelfTheme.Spacing.md)
        .background(StreamShelfTheme.Colors.surfaceElevated, in: RoundedRectangle(cornerRadius: StreamShelfTheme.Dimensions.cardCornerRadius))
    }
}

private struct MusicItemRow: View {
    let item: PlexMovie
    let accessorySystemImage: String
    private let config = PlexConfig.shared

    var body: some View {
        HStack(spacing: StreamShelfTheme.Spacing.md) {
            PosterView(
                url: config.imageURL(for: item.artworkPath, width: 100, height: 100),
                width: 46,
                height: 46,
                cornerRadius: 6
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(StreamShelfTheme.Colors.primaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle = item.browseSubtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: StreamShelfTheme.Spacing.sm)

            Image(systemName: accessorySystemImage)
                .foregroundStyle(StreamShelfTheme.Colors.accent)
                .font(.headline)
        }
        .padding(StreamShelfTheme.Spacing.md)
        .background(StreamShelfTheme.Colors.surfaceElevated, in: RoundedRectangle(cornerRadius: StreamShelfTheme.Dimensions.cardCornerRadius))
    }
}

#Preview {
    NavigationStack {
        MovieDetailView(movie: .preview)
            .environmentObject(PlexConfig.shared)
    }
}
