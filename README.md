# StreamShelf

A SwiftUI iOS app for browsing and playing movies from a user-configured Plex Media Server.

## Requirements

- Xcode 15+
- iOS 17+ deployment target
- A running Plex Media Server with at least one movie library

## Setup

1. Open `StreamShelf/StreamShelf.xcodeproj` in Xcode.
2. Select your development team in **Signing & Capabilities** (target → StreamShelf).
3. Build and run on a device or simulator (iOS 17+).
4. On first launch, tap **Configure Server** and enter:
   - **Base URL** — your Plex server address, e.g. `http://192.168.1.10:32400` on LAN or an HTTPS URL for off-network access
   - **X-Plex-Token** — your Plex authentication token (stored in Keychain)
5. Tap **Test Connection** — a green checkmark confirms success. Pick a default library, then **Save**.

### Getting Your Plex Token

Sign in to Plex Web, open DevTools → Network, look for any API request and find the `X-Plex-Token` query parameter. Alternatively, follow [Plex's official guide](https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/).

## What's New (Iteration 2)

### Home Screen
- **Continue Watching shelf** — populated from `/library/onDeck` (items already in progress on your server)
- **Recently Added shelf** — populated from `/library/recentlyAdded`, horizontal scrolling card layout
- **Libraries shortcut** linking through to the full library browser

### Visual Polish
- `StreamShelfTheme` design system (`Theme/StreamShelfTheme.swift`) with shared colors, typography, spacing, and dimension constants
- Reusable `PosterView` for consistent poster rendering with loading/error states
- `MetaChip` / `MetaChipRow` components for year, duration, content rating, and rating display
- Movie grid cells now show a star-rating badge overlay
- List rows show content rating chip alongside year and rating
- Detail page uses a taller hero backdrop (300 pt), accent-colored genre label, and horizontal chip row

### Playback
- Player now presents as `fullScreenCover` instead of a sheet for a true cinema feel
- Black background with centered loading indicator while buffering
- Floating `×` dismiss button that doesn't require a navigation bar

### Settings
- Connection status indicator (spinner → green checkmark / red ✕) with section count in the footer
- URL and token fields reset the status indicator on change, prompting a re-test before save
- Token hint text pointing to Plex's troubleshooting page

## Architecture

```
StreamShelf/
├── StreamShelfApp.swift              # @main entry, injects PlexConfig env object
├── ContentView.swift             # Root: shows setup screen or HomeView
│
├── Theme/
│   └── StreamShelfTheme.swift           # Colors, typography, spacing, dimensions + view modifiers
│
├── Models/
│   ├── PlexModels.swift           # Decodable structs: PlexMovie (+ type field), PlexLibrarySection…
│   └── PlexMovie+Preview.swift    # Static preview fixtures
│
├── Auth/
│   └── PlexConfig.swift           # ObservableObject; UserDefaults persistence; stream/image URLs
│
├── Networking/
│   └── PlexAPIClient.swift        # async/await API layer:
│                                  #   fetchLibrarySections, fetchMovies, fetchMovieDetail
│                                  #   fetchOnDeck, fetchRecentlyAdded
│
├── ViewModels/
│   ├── HomeViewModel.swift        # Parallel loads onDeck + recentlyAdded
│   ├── SettingsViewModel.swift    # ConnectionStatus enum; live test-connection feedback
│   ├── LibraryViewModel.swift
│   ├── MoviesViewModel.swift
│   └── MovieDetailViewModel.swift
│
└── Views/
    ├── Home/HomeView.swift             # Shelves + libraries shortcut (main landing)
    ├── Settings/SettingsView.swift     # Server config with visual connection status
    ├── Library/LibrarySectionsView.swift
    ├── Movies/MoviesView.swift         # Grid (rating badge) + list (content rating chip)
    ├── Movies/MovieDetailView.swift    # Hero backdrop, MetaChipRow, full-screen play
    ├── Player/VideoPlayerView.swift    # Full-screen AVKit player with overlay dismiss
    └── Shared/
        ├── ErrorView.swift
        ├── PosterView.swift            # Reusable async poster with placeholder
        └── MetaChip.swift             # Chip + ChipRow components
```

### Data flow

```
PlexConfig (UserDefaults) ──► PlexAPIClient ──► ViewModels ──► Views
                                                    │
                                              @StateObject
```

- `PlexConfig.shared` is injected as an environment object from `StreamShelfApp`.
- `PlexAPIClient` is stateless; reads URL/token from `PlexConfig` at call time.
- All ViewModels are `@MainActor`, using `async/await` + `withTaskGroup` for parallel loads.
- Images are lazy `AsyncImage` calls routed through Plex's `/photo/:/transcode` endpoint.

### Stream URL

`PlexConfig.streamURL(for:)` appends `?X-Plex-Token=…` to the part key. The token is a query parameter because `AVPlayer` cannot inject custom HTTP headers for direct streams.

### App Transport Security

`NSAllowsArbitraryLoads = true` in `Info.plist` allows user-configured HTTP servers. For App Store release, use HTTPS for off-network review/testing and include a clear App Review note explaining that users connect to their own media server.

## Next Steps / Out of Scope

- **Plex OAuth** — plex.tv account login instead of raw token entry
- **Transcoding** — quality/bitrate selection before playback
- **Subtitle & audio track switching** — via AVKit media selection API
- **TV shows & music** — the model layer is type-aware (`PlexMovie.type`) but browsing/detail views are movie-only
- **Resume position** — posting playback progress to `/:/progress` and reading `viewOffset` from on-deck metadata
- **Downloads / offline sync**
- **Push notifications**
