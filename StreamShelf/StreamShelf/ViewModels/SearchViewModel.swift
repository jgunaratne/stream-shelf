import Foundation
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [PlexMovie] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: PlexAPIClient
    private var searchTask: Task<Void, Never>?

    init(api: PlexAPIClient = .shared) {
        self.api = api
    }

    func updateQuery(_ value: String) {
        query = value
        searchTask?.cancel()

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            errorMessage = nil
            isLoading = false
            return
        }

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await self?.performSearch(query: trimmed)
        }
    }

    func retry() async {
        await performSearch(query: query.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func performSearch(query: String) async {
        guard !query.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            results = try await api.fetchSearchResults(query: query)
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }
}
