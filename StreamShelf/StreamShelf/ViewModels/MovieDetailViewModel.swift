import Foundation
import Combine

@MainActor
final class MovieDetailViewModel: ObservableObject {
    @Published var movie: PlexMovie
    @Published var episodes: [PlexMovie] = []
    @Published var albums: [PlexMovie] = []
    @Published var tracks: [PlexMovie] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: PlexAPIClient
    private let config: PlexConfig
    private var hasLoadedDetail = false

    init(movie: PlexMovie, api: PlexAPIClient = .shared, config: PlexConfig = .shared) {
        self.movie = movie
        self.api = api
        self.config = config
    }

    func loadDetail(force: Bool = false) async {
        if hasLoadedDetail && !force { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if let detail = try await api.fetchMovieDetail(ratingKey: movie.ratingKey) {
                movie = detail
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        if movie.isShow {
            do {
                episodes = try await api.fetchShowEpisodes(showRatingKey: movie.ratingKey)
            } catch {
                episodes = []
                if errorMessage == nil {
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }
        } else {
            episodes = []
        }

        if movie.isArtist || movie.isAlbum {
            do {
                let children = try await api.fetchMetadataChildren(ratingKey: movie.ratingKey)
                albums = children.filter(\.isAlbum)
                tracks = children.filter(\.isTrack)
            } catch {
                albums = []
                tracks = []
                if errorMessage == nil {
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }
        } else {
            albums = []
            tracks = []
        }

        hasLoadedDetail = true
    }

    func posterURL(width: Int = 300) -> URL? {
        config.imageURL(for: movie.artworkPath, width: width, height: movie.isMusicItem ? width : nil)
    }

    func backdropURL(width: Int = 800) -> URL? {
        config.imageURL(for: movie.art, width: width)
    }

    var durationString: String {
        guard let ms = movie.duration, ms > 0 else { return "" }
        let total = ms / 1000
        let h = total / 3600
        let m = (total % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    var genreString: String {
        movie.genre?.prefix(3).map(\.tag).joined(separator: ", ") ?? ""
    }

    var directorsLabel: String {
        movie.director?.prefix(3).map(\.tag).joined(separator: ", ") ?? ""
    }

    var writersLabel: String {
        movie.writer?.prefix(3).map(\.tag).joined(separator: ", ") ?? ""
    }

    var castLabel: String {
        movie.role?.prefix(5).map(\.tag).joined(separator: ", ") ?? ""
    }

    var primaryPlaybackItem: PlexMovie? {
        if movie.isTrack {
            return movie
        }

        if movie.isAlbum {
            return tracks.first(where: \.hasProgress) ?? tracks.first
        }

        if movie.isShow {
            return episodes.first(where: \.hasProgress) ?? episodes.first
        }

        return movie.isSupportedVideoType ? movie : nil
    }

    var primaryPlaybackTitle: String {
        primaryPlaybackItem?.playbackTitle ?? movie.playbackTitle
    }

    var primaryActionTitle: String {
        guard let primaryPlaybackItem else { return "Play" }

        if primaryPlaybackItem.hasProgress {
            if movie.isShow {
                return "Resume Show"
            }
            if movie.isAlbum {
                return "Resume Album"
            }
            return movie.isTrack ? "Resume Track" : "Resume"
        }

        if movie.isShow {
            return "Play Show"
        }
        if movie.isAlbum {
            return "Play Album"
        }
        return movie.isTrack ? "Play Track" : "Play"
    }

    var releaseDateLabel: String? {
        guard let raw = movie.originallyAvailableAt, !raw.isEmpty else { return nil }
        return raw
    }

    var progressFraction: Double {
        guard let duration = movie.duration, duration > 0, let viewOffset = movie.viewOffset else { return 0 }
        return min(max(Double(viewOffset) / Double(duration), 0), 1)
    }
}
