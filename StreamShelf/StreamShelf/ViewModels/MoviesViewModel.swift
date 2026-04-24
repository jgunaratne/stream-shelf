import Foundation
import Combine

enum MusicLibraryBrowseMode: String, CaseIterable, Identifiable {
    case albums
    case artists
    case tracks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .albums: return "Albums"
        case .artists: return "Artists"
        case .tracks: return "Tracks"
        }
    }

    var plexType: String {
        switch self {
        case .artists: return "8"
        case .albums: return "9"
        case .tracks: return "10"
        }
    }
}

@MainActor
final class MoviesViewModel: ObservableObject {
    @Published var movies: [PlexMovie] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var musicBrowseMode: MusicLibraryBrowseMode = .albums

    let sectionKey: String
    let sectionTitle: String
    let sectionType: String
    let genreKey: String?
    let genreTitle: String?

    private let api: PlexAPIClient

    init(
        sectionKey: String,
        sectionTitle: String,
        sectionType: String,
        genreKey: String? = nil,
        genreTitle: String? = nil,
        api: PlexAPIClient = .shared
    ) {
        self.sectionKey = sectionKey
        self.sectionTitle = sectionTitle
        self.sectionType = sectionType
        self.genreKey = genreKey
        self.genreTitle = genreTitle
        self.api = api
    }

    var isMusicLibrary: Bool {
        sectionType == "artist" || sectionType == "music"
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            movies = try await api.fetchLibraryItems(
                sectionKey: sectionKey,
                sectionType: sectionType,
                musicBrowseMode: musicBrowseMode,
                genreKey: genreKey
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
