import SwiftUI

struct SearchView: View {
    @StateObject private var vm = SearchViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView(
                        "Search Plex",
                        systemImage: "magnifyingglass",
                        description: Text("Look up movies, shows, and music across your Plex libraries.")
                    )
                } else if vm.isLoading && vm.results.isEmpty {
                    ProgressView("Searching…")
                        .tint(StreamShelfTheme.Colors.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = vm.errorMessage, vm.results.isEmpty {
                    ErrorView(message: error) {
                        Task { await vm.retry() }
                    }
                } else if vm.results.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "film",
                        description: Text("Try a different title or keyword.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: StreamShelfTheme.Spacing.sm) {
                            ForEach(vm.results) { movie in
                                NavigationLink(destination: MovieDetailView(movie: movie)) {
                                    MovieListRow(movie: movie)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(StreamShelfTheme.Spacing.lg)
                    }
                    .background(StreamShelfTheme.Colors.appBackground)
                    .overlay(alignment: .topTrailing) {
                        if vm.isLoading {
                            ProgressView()
                                .padding()
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .background(StreamShelfTheme.Colors.appBackground.ignoresSafeArea())
            .toolbarBackground(StreamShelfTheme.Colors.appBackground, for: .navigationBar)
            .searchable(text: Binding(
                get: { vm.query },
                set: { vm.updateQuery($0) }
            ), prompt: "Search titles")
        }
    }
}

#Preview {
    SearchView()
        .environmentObject(PlexConfig.shared)
}
