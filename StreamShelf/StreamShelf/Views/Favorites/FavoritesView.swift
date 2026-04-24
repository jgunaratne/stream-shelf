import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var config: PlexConfig
    @StateObject private var vm = FavoritesViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if !config.isConfigured {
                    ContentUnavailableView(
                        "Server Not Configured",
                        systemImage: "gearshape",
                        description: Text("Connect to Plex first, then your saved media will load here.")
                    )
                } else if config.favoriteMovieIDs.isEmpty {
                    ContentUnavailableView(
                        "No Favorites Yet",
                        systemImage: "heart",
                        description: Text("Save media from the detail page and it will appear here.")
                    )
                } else if vm.isLoading && vm.movies.isEmpty {
                    ProgressView("Loading favorites…")
                        .tint(StreamShelfTheme.Colors.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = vm.errorMessage, vm.movies.isEmpty {
                    ErrorView(message: error) {
                        Task { await vm.load(ids: config.favoriteMovieIDs) }
                    }
                } else {
                    List(vm.movies) { movie in
                        NavigationLink(destination: MovieDetailView(movie: movie)) {
                            MovieListRow(movie: movie)
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .listRowBackground(StreamShelfTheme.Colors.appBackground)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(StreamShelfTheme.Colors.appBackground)
                    .overlay(alignment: .topTrailing) {
                        if vm.isLoading {
                            ProgressView()
                                .padding()
                        }
                    }
                }
            }
            .navigationTitle("Favorites")
            .background(StreamShelfTheme.Colors.appBackground.ignoresSafeArea())
            .task { await vm.load(ids: config.favoriteMovieIDs) }
            .onChange(of: config.favoriteMovieIDs) { _, ids in
                Task { await vm.load(ids: ids) }
            }
        }
    }
}

@MainActor
private final class FavoritesViewModel: ObservableObject {
    @Published var movies: [PlexMovie] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = PlexAPIClient.shared

    func load(ids: Set<String>) async {
        let sortedIDs = ids.sorted()
        guard !sortedIDs.isEmpty else {
            movies = []
            errorMessage = nil
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var loaded: [PlexMovie] = []
        var lastError: String?

        for id in sortedIDs {
            guard !Task.isCancelled else { return }
            do {
                if let movie = try await api.fetchMovieDetail(ratingKey: id) {
                    loaded.append(movie)
                }
            } catch {
                lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }

        movies = loaded.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        if movies.isEmpty {
            errorMessage = lastError ?? "Your saved items are no longer available on this server."
        }
    }
}

#Preview {
    FavoritesView()
        .environmentObject(PlexConfig.shared)
}
