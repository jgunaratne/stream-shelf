import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var onDeckItems: [PlexMovie] = []
    @Published var recentlyAdded: [PlexMovie] = []
    @Published var recommended: [PlexMovie] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = PlexAPIClient.shared

    var hasContent: Bool {
        !onDeckItems.isEmpty || !recentlyAdded.isEmpty || !recommended.isEmpty
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        async let onDeckResult = loadOnDeckItems()
        async let recentlyAddedResult = loadRecentlyAddedItems()

        let (onDeck, recent) = await (onDeckResult, recentlyAddedResult)
        onDeckItems = onDeck.items
        recentlyAdded = recent.items
        buildRecommendations()

        let messages = [onDeck.errorMessage, recent.errorMessage].compactMap { $0 }
        if !hasContent {
            errorMessage = messages.first
        }
    }

    private func loadOnDeckItems() async -> LoadResult {
        do {
            return LoadResult(items: try await api.fetchOnDeck())
        } catch {
            return LoadResult(items: [], errorMessage: userFacingMessage(for: error))
        }
    }

    private func loadRecentlyAddedItems() async -> LoadResult {
        do {
            return LoadResult(items: try await api.fetchRecentlyAdded())
        } catch {
            return LoadResult(items: [], errorMessage: userFacingMessage(for: error))
        }
    }

    private func buildRecommendations() {
        let ranked = (onDeckItems + recentlyAdded)
            .sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }

        var seen = Set<String>()
        recommended = ranked.filter { movie in
            seen.insert(movie.id).inserted && !movie.hasProgress
        }
        .prefix(12)
        .map { $0 }
    }

    private func userFacingMessage(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private struct LoadResult {
        let items: [PlexMovie]
        let errorMessage: String?

        init(items: [PlexMovie], errorMessage: String? = nil) {
            self.items = items
            self.errorMessage = errorMessage
        }
    }
}
