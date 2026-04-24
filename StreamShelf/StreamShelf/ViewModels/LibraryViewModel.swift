import Foundation
import Combine

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var sections: [PlexLibrarySection] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: PlexAPIClient
    private let config: PlexConfig

    init(api: PlexAPIClient = .shared, config: PlexConfig = .shared) {
        self.api = api
        self.config = config
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            sections = try await api.fetchLibrarySections()
                .filter(\.isVideoSection)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
