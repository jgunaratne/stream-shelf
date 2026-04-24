import Foundation

enum PlexAPIError: LocalizedError {
    case notConfigured
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .notConfigured:       return "Server not configured. Please set up your Plex server in Settings."
        case .invalidURL:          return "Invalid server URL."
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .decodingError(let e):return "Response parse error: \(e.localizedDescription)"
        case .httpError(let code): return "Server returned HTTP \(code)."
        }
    }
}

struct PlexConnection: Equatable {
    let baseURL: String
    let token: String

    var isValid: Bool {
        !baseURL.isEmpty && !token.isEmpty
    }
}

enum PlexPlaybackState: String {
    case playing
    case paused
    case stopped
    case buffering
}

final class PlexAPIClient {
    static let shared = PlexAPIClient()
    private let session: URLSession
    private let config: PlexConfig

    init(config: PlexConfig = .shared, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func fetchLibrarySections(connection: PlexConnection? = nil) async throws -> [PlexLibrarySection] {
        let url = try buildURL(path: "/library/sections", connection: connection)
        let container: PlexLibrarySectionsResponse = try await fetch(url: url)
        return container.mediaContainer.directory
    }

    func fetchLibraryItems(
        sectionKey: String,
        sectionType: String,
        musicBrowseMode: MusicLibraryBrowseMode = .albums,
        genreKey: String? = nil,
        connection: PlexConnection? = nil
    ) async throws -> [PlexMovie] {
        var queryItems: [URLQueryItem] = []

        if Self.isMusicSectionType(sectionType) {
            queryItems.append(URLQueryItem(name: "type", value: musicBrowseMode.plexType))
        } else if let type = Self.libraryContentType(for: sectionType) {
            queryItems.append(URLQueryItem(name: "type", value: type))
        }

        if let genreKey, !genreKey.isEmpty {
            queryItems.append(URLQueryItem(name: "genre", value: genreKey))
        }

        let url = try buildURL(
            path: "/library/sections/\(sectionKey)/all",
            additionalQueryItems: queryItems,
            connection: connection
        )
        let container: PlexMoviesResponse = try await fetch(url: url)
        let items = container.mediaContainer.metadata ?? []

        switch sectionType {
        case "artist", "music":
            switch musicBrowseMode {
            case .artists:
                return items.filter(\.isArtist)
            case .albums:
                return items.filter(\.isAlbum)
            case .tracks:
                return items.filter(\.isTrack)
            }
        case "show":
            return items.filter(\.isShow)
        case "movie":
            return items.filter(\.isMovie)
        default:
            return items.filter(\.isSupportedVideoType)
        }
    }

    func fetchLibraryGenres(
        sectionKey: String,
        sectionType: String,
        musicBrowseMode: MusicLibraryBrowseMode = .albums,
        connection: PlexConnection? = nil
    ) async throws -> [PlexGenre] {
        var queryItems: [URLQueryItem] = []

        if Self.isMusicSectionType(sectionType) {
            queryItems.append(URLQueryItem(name: "type", value: musicBrowseMode.plexType))
        } else if let type = Self.libraryContentType(for: sectionType) {
            queryItems.append(URLQueryItem(name: "type", value: type))
        }

        let url = try buildURL(
            path: "/library/sections/\(sectionKey)/genre",
            additionalQueryItems: queryItems,
            connection: connection
        )
        let container: PlexGenresResponse = try await fetch(url: url)
        return container.mediaContainer.directory ?? []
    }

    func fetchMovieDetail(ratingKey: String, connection: PlexConnection? = nil) async throws -> PlexMovie? {
        let url = try buildURL(path: "/library/metadata/\(ratingKey)", connection: connection)
        let container: PlexMovieDetailResponse = try await fetch(url: url)
        return container.mediaContainer.metadata?.first
    }

    func fetchShowEpisodes(showRatingKey: String, connection: PlexConnection? = nil) async throws -> [PlexMovie] {
        let url = try buildURL(path: "/library/metadata/\(showRatingKey)/allLeaves", connection: connection)
        let container: PlexMoviesResponse = try await fetch(url: url)
        return (container.mediaContainer.metadata ?? []).filter(\.isEpisode)
    }

    func fetchMetadataChildren(ratingKey: String, connection: PlexConnection? = nil) async throws -> [PlexMovie] {
        let url = try buildURL(path: "/library/metadata/\(ratingKey)/children", connection: connection)
        let container: PlexMoviesResponse = try await fetch(url: url)
        return container.mediaContainer.metadata ?? []
    }

    func fetchOnDeck(connection: PlexConnection? = nil) async throws -> [PlexMovie] {
        let url = try buildURL(path: "/library/onDeck", connection: connection)
        let container: PlexMoviesResponse = try await fetch(url: url)
        return (container.mediaContainer.metadata ?? []).filter(\.isSupportedVideoType)
    }

    func fetchRecentlyAdded(connection: PlexConnection? = nil) async throws -> [PlexMovie] {
        let url = try buildURL(path: "/library/recentlyAdded", connection: connection)
        let container: PlexMoviesResponse = try await fetch(url: url)
        return (container.mediaContainer.metadata ?? []).filter(\.isSupportedVideoType)
    }

    func fetchSearchResults(query: String, connection: PlexConnection? = nil) async throws -> [PlexMovie] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        let url = try buildURL(path: "/search", additionalQueryItems: [
            URLQueryItem(name: "query", value: trimmedQuery)
        ], connection: connection)
        let container: PlexMoviesResponse = try await fetch(url: url)
        return (container.mediaContainer.metadata ?? []).filter(\.isSupportedMediaType)
    }

    func reportTimeline(
        for item: PlexMovie,
        offsetMilliseconds: Int,
        durationMilliseconds: Int? = nil,
        state: PlexPlaybackState,
        sessionIdentifier: String,
        connection: PlexConnection? = nil
    ) async throws {
        var queryItems = [
            URLQueryItem(name: "key", value: item.metadataKey),
            URLQueryItem(name: "ratingKey", value: item.ratingKey),
            URLQueryItem(name: "state", value: state.rawValue),
            URLQueryItem(name: "time", value: String(offsetMilliseconds))
        ]

        if let durationMilliseconds, durationMilliseconds > 0 {
            queryItems.append(URLQueryItem(name: "duration", value: String(durationMilliseconds)))
        }

        if state == .stopped {
            queryItems.append(URLQueryItem(name: "continuing", value: "0"))
        }

        let url = try buildURL(
            path: "/:/timeline",
            additionalQueryItems: queryItems,
            includeContainerLimits: false,
            connection: connection
        )

        let request = configuredRequest(
            url: url,
            method: "POST",
            sessionIdentifier: sessionIdentifier
        )

        _ = try await send(request)
    }

    private static func isMusicSectionType(_ type: String) -> Bool {
        type == "artist" || type == "music"
    }

    private static func libraryContentType(for sectionType: String) -> String? {
        switch sectionType {
        case "movie":
            return "1"
        case "show":
            return "2"
        case "artist", "music":
            return MusicLibraryBrowseMode.albums.plexType
        default:
            return nil
        }
    }

    private func buildURL(
        path: String,
        additionalQueryItems: [URLQueryItem] = [],
        includeContainerLimits: Bool = true,
        connection: PlexConnection? = nil
    ) throws -> URL {
        let resolved = resolvedConnection(connection)
        guard resolved.isValid else { throw PlexAPIError.notConfigured }
        guard var components = URLComponents(string: "\(resolved.baseURL)\(path)") else {
            throw PlexAPIError.invalidURL
        }

        var queryItems = (components.queryItems ?? []) + additionalQueryItems + [
            URLQueryItem(name: "X-Plex-Token", value: resolved.token),
        ]

        if includeContainerLimits {
            queryItems.append(contentsOf: [
                URLQueryItem(name: "X-Plex-Container-Start", value: "0"),
                URLQueryItem(name: "X-Plex-Container-Size", value: "500")
            ])
        }

        components.queryItems = queryItems
        guard let url = components.url else { throw PlexAPIError.invalidURL }
        return url
    }

    private func resolvedConnection(_ connection: PlexConnection?) -> PlexConnection {
        if let connection {
            return connection
        }
        return PlexConnection(baseURL: config.normalizedBaseURL, token: config.normalizedToken)
    }

    private func fetch<T: Decodable>(url: URL) async throws -> T {
        let request = configuredRequest(url: url)
        let data = try await send(request)

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys
            return try decoder.decode(T.self, from: data)
        } catch {
            throw PlexAPIError.decodingError(error)
        }
    }

    private func configuredRequest(
        url: URL,
        method: String = "GET",
        accept: String = "application/json",
        sessionIdentifier: String? = nil
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue("StreamShelf", forHTTPHeaderField: "X-Plex-Product")
        request.setValue("1.0.0", forHTTPHeaderField: "X-Plex-Version")
        request.setValue("iOS", forHTTPHeaderField: "X-Plex-Platform")
        request.setValue("StreamShelf-iOS", forHTTPHeaderField: "X-Plex-Client-Identifier")

        if let sessionIdentifier {
            request.setValue(sessionIdentifier, forHTTPHeaderField: "X-Plex-Session-Identifier")
        }

        return request
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw PlexAPIError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw PlexAPIError.httpError(http.statusCode)
        }

        return data
    }
}
