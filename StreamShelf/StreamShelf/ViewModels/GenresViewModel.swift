import Foundation
import Combine

struct GenreLibraryGroup: Identifiable {
    let section: PlexLibrarySection
    let genres: [PlexGenre]

    var id: String { section.id }
}

@MainActor
final class GenresViewModel: ObservableObject {
    @Published var groups: [GenreLibraryGroup] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: PlexAPIClient

    init(api: PlexAPIClient = .shared) {
        self.api = api
    }

    var hasGenres: Bool {
        groups.contains { !$0.genres.isEmpty }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let sections = try await api.fetchLibrarySections()
                .filter { section in
                    section.type == "movie" || section.type == "show" || section.isMusicSection
                }

            var loadedGroups: [GenreLibraryGroup] = []
            for section in sections {
                let genres: [PlexGenre]
                do {
                    genres = try await api.fetchLibraryGenres(
                        sectionKey: section.key,
                        sectionType: section.type
                    )
                    .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                } catch {
                    continue
                }

                if !genres.isEmpty {
                    loadedGroups.append(GenreLibraryGroup(section: section, genres: genres))
                }
            }

            groups = loadedGroups
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            groups = []
        }
    }
}
