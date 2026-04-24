import SwiftUI

struct LibrarySectionsView: View {
    @StateObject private var vm = LibraryViewModel()
    @State private var showSettings = false

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView("Loading libraries…")
                    .tint(StreamShelfTheme.Colors.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = vm.errorMessage {
                ErrorView(message: err) {
                    Task { await vm.load() }
                }
            } else if vm.sections.isEmpty {
                ContentUnavailableView(
                    "No Libraries",
                    systemImage: "film.stack",
                    description: Text("Configure your Plex server in Settings to get started.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: StreamShelfTheme.Spacing.sm) {
                        ForEach(vm.sections) { section in
                            NavigationLink(destination: MoviesView(sectionKey: section.key, sectionTitle: section.title, sectionType: section.type)) {
                                SectionRow(section: section)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(StreamShelfTheme.Spacing.lg)
                }
                .background(StreamShelfTheme.Colors.appBackground)
            }
        }
        .navigationTitle("Libraries")
        .background(StreamShelfTheme.Colors.appBackground.ignoresSafeArea())
        .toolbarBackground(StreamShelfTheme.Colors.appBackground, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }
}

private struct SectionRow: View {
    let section: PlexLibrarySection

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(StreamShelfTheme.Colors.accent)
                .frame(width: 40, height: 40)
                .background(StreamShelfTheme.Colors.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .font(.headline)
                    .foregroundStyle(StreamShelfTheme.Colors.primaryText)
                Text(section.isMusicSection ? "Music" : section.type.capitalized)
                    .font(.caption)
                    .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
            }
            Spacer()
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

    private var iconName: String {
        switch section.type {
        case "movie": return "film"
        case "show":  return "tv"
        case "artist", "music": return "music.note"
        default:      return "folder"
        }
    }
}

#Preview {
    NavigationStack {
        LibrarySectionsView()
    }
}
