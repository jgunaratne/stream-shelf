import Foundation
import Combine
import Security

final class PlexConfig: ObservableObject {
    static let shared = PlexConfig()

    private let defaults = UserDefaults.standard
    private var playbackProgressByID: [String: PlaybackProgress] {
        didSet { persistPlaybackProgress() }
    }

    private enum Keys {
        static let baseURL = "plex_baseURL"
        static let token = "plex_token"
        static let librarySectionKey = "plex_librarySectionKey"
        static let favoriteMovieIDs = "plex_favoriteMovieIDs"
        static let playbackProgress = "plex_playbackProgress"
    }

    private struct PlaybackProgress: Codable {
        let offsetMilliseconds: Int
        let durationMilliseconds: Int?
        let updatedAt: Date
    }

    @Published var baseURL: String {
        didSet { defaults.set(baseURL, forKey: Keys.baseURL) }
    }

    @Published var token: String {
        didSet {
            TokenStore.save(token)
            defaults.removeObject(forKey: Keys.token)
        }
    }

    @Published var librarySectionKey: String {
        didSet { defaults.set(librarySectionKey, forKey: Keys.librarySectionKey) }
    }

    @Published private(set) var favoriteMovieIDs: Set<String> {
        didSet { defaults.set(Array(favoriteMovieIDs).sorted(), forKey: Keys.favoriteMovieIDs) }
    }

    var isConfigured: Bool {
        !normalizedBaseURL.isEmpty && !normalizedToken.isEmpty
    }

    var normalizedBaseURL: String {
        normalized(baseURL)
    }

    var normalizedToken: String {
        token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private init() {
        baseURL = defaults.string(forKey: Keys.baseURL) ?? ""

        let legacyToken = defaults.string(forKey: Keys.token) ?? ""
        token = TokenStore.read() ?? legacyToken
        if !legacyToken.isEmpty, TokenStore.read() == nil {
            TokenStore.save(legacyToken)
        }
        defaults.removeObject(forKey: Keys.token)

        librarySectionKey = defaults.string(forKey: Keys.librarySectionKey) ?? ""
        favoriteMovieIDs = Set(defaults.stringArray(forKey: Keys.favoriteMovieIDs) ?? [])
        playbackProgressByID = Self.decodedPlaybackProgress(from: defaults.data(forKey: Keys.playbackProgress))
        pruneStalePlaybackProgress()
        persistPlaybackProgress()
    }

    func streamURL(for partKey: String) -> URL? {
        url(for: partKey, token: normalizedToken)
    }

    func playbackURL(
        for metadataKey: String,
        offset: Int? = nil,
        audioStreamID: Int? = nil,
        subtitleStreamID: Int? = nil,
        sessionIdentifier: String? = nil,
        mediaKind: PlaybackMediaKind = .video
    ) -> URL? {
        playbackURL(
            for: metadataKey,
            baseURL: normalizedBaseURL,
            token: normalizedToken,
            offset: offset,
            audioStreamID: audioStreamID,
            subtitleStreamID: subtitleStreamID,
            sessionIdentifier: sessionIdentifier,
            mediaKind: mediaKind
        )
    }

    func imageURL(for path: String?, width: Int = 300, height: Int? = nil) -> URL? {
        guard let path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let normalizedBaseURL = self.normalizedBaseURL
        let normalizedToken = self.normalizedToken
        guard !normalizedBaseURL.isEmpty, !normalizedToken.isEmpty else { return nil }
        let resolvedHeight = height ?? (width * 3 / 2)
        guard var components = URLComponents(string: normalizedBaseURL + "/photo/:/transcode") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "url", value: transcodeImageSource(for: path, baseURL: normalizedBaseURL)),
            URLQueryItem(name: "width", value: "\(width)"),
            URLQueryItem(name: "height", value: "\(resolvedHeight)"),
            URLQueryItem(name: "minSize", value: "1"),
            URLQueryItem(name: "X-Plex-Token", value: normalizedToken)
        ]
        return components.url
    }

    func streamURL(for partKey: String, baseURL: String, token: String) -> URL? {
        url(for: partKey, baseURL: normalized(baseURL), token: normalized(token))
    }

    func imageURL(for path: String?, baseURL: String, token: String, width: Int = 300, height: Int? = nil) -> URL? {
        guard let path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let normalizedBaseURL = normalized(baseURL)
        let normalizedToken = normalized(token)
        guard !normalizedBaseURL.isEmpty, !normalizedToken.isEmpty else { return nil }
        let resolvedHeight = height ?? (width * 3 / 2)
        guard var components = URLComponents(string: normalizedBaseURL + "/photo/:/transcode") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "url", value: transcodeImageSource(for: path, baseURL: normalizedBaseURL)),
            URLQueryItem(name: "width", value: "\(width)"),
            URLQueryItem(name: "height", value: "\(resolvedHeight)"),
            URLQueryItem(name: "minSize", value: "1"),
            URLQueryItem(name: "X-Plex-Token", value: normalizedToken)
        ]
        return components.url
    }

    func playbackURL(
        for metadataKey: String,
        baseURL: String,
        token: String,
        offset: Int? = nil,
        audioStreamID: Int? = nil,
        subtitleStreamID: Int? = nil,
        sessionIdentifier: String? = nil,
        mediaKind: PlaybackMediaKind = .video
    ) -> URL? {
        let normalizedBaseURL = normalized(baseURL)
        let normalizedToken = normalized(token)
        guard !normalizedBaseURL.isEmpty, !normalizedToken.isEmpty, !metadataKey.isEmpty else { return nil }
        guard var components = URLComponents(string: normalizedBaseURL + mediaKind.transcodePath) else {
            return nil
        }

        let transcodeSessionIdentifier = sessionIdentifier ?? "StreamShelf-\(UUID().uuidString)"
        var queryItems = [
            URLQueryItem(name: "path", value: metadataKey),
            URLQueryItem(name: "protocol", value: "hls"),
            URLQueryItem(name: "mediaIndex", value: "0"),
            URLQueryItem(name: "partIndex", value: "0"),
            URLQueryItem(name: "fastSeek", value: "1"),
            URLQueryItem(name: "directPlay", value: mediaKind.directPlayValue),
            URLQueryItem(name: "directStream", value: "1"),
            URLQueryItem(name: "subtitleSize", value: "100"),
            URLQueryItem(name: "audioBoost", value: "100"),
            URLQueryItem(name: "session", value: transcodeSessionIdentifier),
            URLQueryItem(name: "transcodeSessionId", value: transcodeSessionIdentifier),
            URLQueryItem(name: "X-Plex-Product", value: "StreamShelf"),
            URLQueryItem(name: "X-Plex-Version", value: "1.0.0"),
            URLQueryItem(name: "X-Plex-Platform", value: "iOS"),
            URLQueryItem(name: "X-Plex-Client-Identifier", value: "StreamShelf-iOS"),
            URLQueryItem(name: "X-Plex-Session-Identifier", value: transcodeSessionIdentifier),
            URLQueryItem(name: "X-Plex-Token", value: normalizedToken)
        ]

        queryItems.append(contentsOf: mediaKind.additionalTranscodeQueryItems)

        if let offset, offset > 0 {
            queryItems.append(URLQueryItem(name: "offset", value: String(offset / 1000)))
        }

        if let audioStreamID {
            queryItems.append(URLQueryItem(name: "audioStreamID", value: String(audioStreamID)))
        }

        if let subtitleStreamID {
            queryItems.append(URLQueryItem(name: "subtitleStreamID", value: String(subtitleStreamID)))
        }

        components.queryItems = queryItems
        return components.url
    }

    func isFavorite(movieID: String) -> Bool {
        favoriteMovieIDs.contains(movieID)
    }

    func toggleFavorite(movieID: String) {
        if favoriteMovieIDs.contains(movieID) {
            favoriteMovieIDs.remove(movieID)
        } else {
            favoriteMovieIDs.insert(movieID)
        }
    }

    func resumeOffset(for item: PlexMovie) -> Int? {
        pruneStalePlaybackProgress()

        let serverOffset = normalizedPlaybackOffset(item.viewOffset, durationMilliseconds: item.playbackDuration)
        let localEntry = playbackProgressByID[item.ratingKey]
        let localOffset = localEntry.flatMap { entry in
            normalizedPlaybackOffset(
                entry.offsetMilliseconds,
                durationMilliseconds: entry.durationMilliseconds ?? item.playbackDuration
            )
        }

        guard let localOffset else { return serverOffset }
        guard let serverOffset else { return localOffset }

        if localOffset >= serverOffset {
            return localOffset
        }

        let rewindGracePeriod: TimeInterval = 4 * 60 * 60
        if let localEntry, localEntry.updatedAt >= Date().addingTimeInterval(-rewindGracePeriod) {
            return localOffset
        }

        return serverOffset
    }

    func savePlaybackProgress(for item: PlexMovie, offsetMilliseconds: Int, durationMilliseconds: Int? = nil) {
        let resolvedDuration = durationMilliseconds ?? item.playbackDuration
        guard let normalizedOffset = normalizedPlaybackOffset(offsetMilliseconds, durationMilliseconds: resolvedDuration) else {
            clearPlaybackProgress(for: item.ratingKey)
            return
        }

        playbackProgressByID[item.ratingKey] = PlaybackProgress(
            offsetMilliseconds: normalizedOffset,
            durationMilliseconds: resolvedDuration,
            updatedAt: Date()
        )
    }

    func clearPlaybackProgress(for ratingKey: String) {
        playbackProgressByID.removeValue(forKey: ratingKey)
    }

    private func url(for partKey: String, token: String) -> URL? {
        url(for: partKey, baseURL: normalizedBaseURL, token: token)
    }

    private func url(for partKey: String, baseURL: String, token: String) -> URL? {
        guard !baseURL.isEmpty, !token.isEmpty else { return nil }
        guard var components = URLComponents(string: baseURL + partKey) else { return nil }
        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "X-Plex-Token", value: token))
        components.queryItems = queryItems
        return components.url
    }

    private func normalized(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
    }

    private func transcodeImageSource(for path: String, baseURL: String) -> String {
        guard let sourceURL = URL(string: path), sourceURL.scheme != nil else {
            return path
        }

        guard
            let baseURL = URL(string: baseURL),
            sourceURL.scheme?.lowercased() == baseURL.scheme?.lowercased(),
            sourceURL.host?.lowercased() == baseURL.host?.lowercased(),
            sourceURL.port == baseURL.port
        else {
            return path
        }

        var components = URLComponents()
        components.path = sourceURL.path
        components.query = sourceURL.query
        return components.string ?? path
    }

    private func normalizedPlaybackOffset(_ offsetMilliseconds: Int?, durationMilliseconds: Int?) -> Int? {
        guard let offsetMilliseconds, offsetMilliseconds > 0 else { return nil }

        if let durationMilliseconds, durationMilliseconds > 0 {
            let clampedOffset = min(offsetMilliseconds, durationMilliseconds)
            let minimumResumeOffset = min(10_000, max(5_000, durationMilliseconds / 100))
            let completionThreshold = min(
                durationMilliseconds,
                max(Int(Double(durationMilliseconds) * 0.95), durationMilliseconds - 60_000)
            )

            guard clampedOffset >= minimumResumeOffset, clampedOffset < completionThreshold else {
                return nil
            }

            return clampedOffset
        }

        return offsetMilliseconds >= 10_000 ? offsetMilliseconds : nil
    }

    private func persistPlaybackProgress() {
        guard let data = try? JSONEncoder().encode(playbackProgressByID) else { return }
        defaults.set(data, forKey: Keys.playbackProgress)
    }

    private func pruneStalePlaybackProgress(referenceDate: Date = Date()) {
        let cutoff = referenceDate.addingTimeInterval(-(30 * 24 * 60 * 60))
        let retained = playbackProgressByID.filter { $0.value.updatedAt >= cutoff }

        guard retained.count != playbackProgressByID.count else { return }
        playbackProgressByID = retained
    }

    private static func decodedPlaybackProgress(from data: Data?) -> [String: PlaybackProgress] {
        guard let data else { return [:] }
        return (try? JSONDecoder().decode([String: PlaybackProgress].self, from: data)) ?? [:]
    }
}

enum PlaybackMediaKind {
    case video
    case audio

    var transcodePath: String {
        switch self {
        case .video:
            return "/video/:/transcode/universal/start.m3u8"
        case .audio:
            return "/music/:/transcode/universal/start.m3u8"
        }
    }

    var directPlayValue: String {
        switch self {
        case .video:
            return "0"
        case .audio:
            return "1"
        }
    }

    var additionalTranscodeQueryItems: [URLQueryItem] {
        switch self {
        case .video:
            return []
        case .audio:
            return [
                URLQueryItem(name: "directStreamAudio", value: "1"),
                URLQueryItem(name: "hasMDE", value: "1"),
                URLQueryItem(name: "download", value: "0"),
                URLQueryItem(name: "musicBitrate", value: "192"),
                URLQueryItem(
                    name: "X-Plex-Client-Profile-Extra",
                    value: "add-transcode-target(type=musicProfile&context=streaming&protocol=hls&container=mpegts&audioCodec=aac,mp3)"
                )
            ]
        }
    }
}

private enum TokenStore {
    private static let service = "com.gunaratne.StreamShelf.plex-token"
    private static let account = "primary"

    static func read() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
            delete()
            return
        }

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemUpdate(baseQuery() as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = baseQuery()
            item.merge(attributes) { _, new in new }
            SecItemAdd(item as CFDictionary, nil)
        }
    }

    private static func delete() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
