import Foundation

// MARK: - Library Section

struct PlexLibrarySection: Identifiable, Decodable {
    let key: String
    let title: String
    let type: String
    let thumb: String?

    var id: String { key }

    var isVideoSection: Bool {
        type == "movie" || type == "show" || isMusicSection || type.isEmpty
    }

    var isMusicSection: Bool {
        type == "artist" || type == "music"
    }
}

struct PlexLibrarySectionsResponse: Decodable {
    let mediaContainer: PlexLibrarySectionsContainer

    enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }
}

struct PlexLibrarySectionsContainer: Decodable {
    let directory: [PlexLibrarySection]

    enum CodingKeys: String, CodingKey {
        case directory = "Directory"
    }
}

// MARK: - Library Genre

struct PlexGenre: Identifiable, Decodable {
    let key: String
    let title: String
    let type: String?
    let fastKey: String?

    var id: String { key }
}

struct PlexGenresResponse: Decodable {
    let mediaContainer: PlexGenresContainer

    enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }
}

struct PlexGenresContainer: Decodable {
    let directory: [PlexGenre]?

    enum CodingKeys: String, CodingKey {
        case directory = "Directory"
    }
}

// MARK: - Movie

struct PlexMovie: Identifiable, Decodable {
    let ratingKey: String
    let key: String?
    let title: String
    let type: String?
    let year: Int?
    let summary: String?
    let thumb: String?
    let art: String?
    let duration: Int?
    let contentRating: String?
    let rating: Double?
    let studio: String?
    let tagline: String?
    let originallyAvailableAt: String?
    let viewOffset: Int?
    let index: Int?
    let parentIndex: Int?
    let parentTitle: String?
    let parentThumb: String?
    let grandparentTitle: String?
    let grandparentKey: String?
    let grandparentThumb: String?
    let childCount: Int?
    let leafCount: Int?
    let genre: [PlexTag]?
    let director: [PlexTag]?
    let writer: [PlexTag]?
    let role: [PlexRole]?
    let media: [PlexMedia]?

    var id: String { ratingKey }

    var hasProgress: Bool {
        (viewOffset ?? 0) > 0
    }

    var isMovie: Bool {
        type == nil || type == "movie"
    }

    var isShow: Bool {
        type == "show"
    }

    var isEpisode: Bool {
        type == "episode"
    }

    var isTrack: Bool {
        type == "track"
    }

    var isAlbum: Bool {
        type == "album"
    }

    var isArtist: Bool {
        type == "artist"
    }

    var isMusicItem: Bool {
        isTrack || isAlbum || isArtist
    }

    var isSupportedVideoType: Bool {
        isMovie || isShow || isEpisode
    }

    var isSupportedMediaType: Bool {
        isSupportedVideoType || isTrack || isAlbum || isArtist
    }

    var isPlayable: Bool {
        media?.contains(where: { !($0.part?.isEmpty ?? true) }) ?? false
    }

    var seasonEpisodeLabel: String? {
        switch (parentIndex, index) {
        case let (season?, episode?):
            return "S\(season) E\(episode)"
        case let (season?, nil):
            return "Season \(season)"
        case let (nil, episode?):
            return "Episode \(episode)"
        default:
            return nil
        }
    }

    var browseSubtitle: String? {
        if isShow {
            if let childCount {
                return "\(childCount) season\(childCount == 1 ? "" : "s")"
            }
            if let leafCount {
                return "\(leafCount) episode\(leafCount == 1 ? "" : "s")"
            }
            return "TV Show"
        }

        if isEpisode {
            if let seasonEpisodeLabel, let grandparentTitle, !grandparentTitle.isEmpty {
                return "\(seasonEpisodeLabel) • \(grandparentTitle)"
            }
            return seasonEpisodeLabel ?? grandparentTitle ?? "Episode"
        }

        if isTrack {
            let subtitle = [grandparentTitle, parentTitle]
                .compactMap { value in
                    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    return trimmed.isEmpty ? nil : trimmed
                }
                .joined(separator: " • ")
            return subtitle.isEmpty ? nil : subtitle
        }

        if isAlbum {
            if let leafCount {
                let trackLabel = "\(leafCount) track\(leafCount == 1 ? "" : "s")"
                if let grandparentTitle, !grandparentTitle.isEmpty {
                    return "\(grandparentTitle) • \(trackLabel)"
                }
                return trackLabel
            }
            return grandparentTitle
        }

        if isArtist {
            if let childCount {
                return "\(childCount) album\(childCount == 1 ? "" : "s")"
            }
            return "Artist"
        }

        if let year {
            return String(year)
        }

        return type?.capitalized
    }

    var playbackTitle: String {
        if isTrack || isAlbum || isArtist {
            return title
        }
        if isEpisode, let grandparentTitle, let seasonEpisodeLabel {
            return "\(grandparentTitle) • \(seasonEpisodeLabel)"
        }
        return grandparentTitle ?? title
    }

    var albumTitle: String? {
        parentTitle
    }

    var artistTitle: String? {
        grandparentTitle
    }

    var artworkPath: String? {
        thumb ?? parentThumb ?? grandparentThumb ?? art
    }
}

struct PlexRole: Decodable, Identifiable {
    let rawID: Int?
    let tag: String
    let role: String?

    enum CodingKeys: String, CodingKey {
        case rawID = "id"
        case tag, role
    }

    var id: String {
        if let rawID {
            return String(rawID)
        }
        return [tag, role].compactMap { $0 }.joined(separator: "-")
    }
}

struct PlexTag: Decodable {
    let tag: String
}

struct PlexMedia: Decodable, Identifiable {
    let id: Int
    let duration: Int?
    let bitrate: Int?
    let videoCodec: String?
    let audioCodec: String?
    let container: String?
    let part: [PlexPart]?

    enum CodingKeys: String, CodingKey {
        case id, duration, bitrate, videoCodec, audioCodec, container
        case part = "Part"
    }
}

struct PlexPart: Decodable, Identifiable {
    let id: Int
    let key: String
    let duration: Int?
    let file: String?
    let size: Int?
    let container: String?
    let streams: [PlexMediaStream]?

    enum CodingKeys: String, CodingKey {
        case id, key, duration, file, size, container
        case streams = "Stream"
    }
}

struct PlexMediaStream: Decodable, Identifiable {
    let id: Int
    let streamType: Int?
    let language: String?
    let languageTag: String?
    let title: String?
    let displayTitle: String?
    let extendedDisplayTitle: String?
    let codec: String?
    let channels: Int?
    let selected: Bool?
    let forced: Bool?
    let isDefault: Bool?

    enum CodingKeys: String, CodingKey {
        case id, streamType, language, languageTag, title, displayTitle, extendedDisplayTitle, codec, channels, selected, forced
        case isDefault = "default"
    }

    var isAudio: Bool {
        streamType == 2
    }

    var isSubtitle: Bool {
        streamType == 3
    }

    var detectedLanguageCode: String? {
        PlexLanguageDetector.detect(
            languageTag: languageTag,
            language: language,
            titles: [extendedDisplayTitle, displayTitle, title]
        )
    }

    var languageLabel: String? {
        if let detectedLanguageCode {
            return PlexLanguageDetector.localizedLanguageName(for: detectedLanguageCode)
        }
        return language
    }

    var label: String {
        let base = [extendedDisplayTitle, displayTitle, title]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })

        if let base, let languageLabel {
            if base.localizedCaseInsensitiveContains(languageLabel) {
                return base
            }
            return "\(languageLabel) • \(base)"
        }

        if let base {
            return base
        }

        if let languageLabel {
            return languageLabel
        }

        return "Track \(id)"
    }
}

struct PlexMoviesResponse: Decodable {
    let mediaContainer: PlexMoviesContainer

    enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }
}

struct PlexMoviesContainer: Decodable {
    let metadata: [PlexMovie]?
    let size: Int?

    enum CodingKeys: String, CodingKey {
        case metadata = "Metadata"
        case size
    }
}

// MARK: - Movie Detail

struct PlexMovieDetailResponse: Decodable {
    let mediaContainer: PlexMovieDetailContainer

    enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }
}

struct PlexMovieDetailContainer: Decodable {
    let metadata: [PlexMovie]?

    enum CodingKeys: String, CodingKey {
        case metadata = "Metadata"
    }
}

extension PlexMovie {
    var metadataKey: String {
        key ?? "/library/metadata/\(ratingKey)"
    }

    var playbackDuration: Int? {
        duration
        ?? media?.compactMap(\.duration).first
        ?? playbackPart?.duration
    }

    var playbackPart: PlexPart? {
        media?
            .compactMap { $0.part?.first(where: { !($0.streams?.isEmpty ?? true) }) ?? $0.part?.first }
            .first
    }

    var audioStreams: [PlexMediaStream] {
        playbackPart?.streams?.filter(\.isAudio) ?? []
    }

    var subtitleStreams: [PlexMediaStream] {
        playbackPart?.streams?.filter(\.isSubtitle) ?? []
    }
}

private enum PlexLanguageDetector {
    static func detect(languageTag: String?, language: String?, titles: [String?]) -> String? {
        if let languageTag, let code = languageCode(fromIdentifier: languageTag) {
            return code
        }

        if let language, let code = inferredLanguageCode(from: language) {
            return code
        }

        for title in titles {
            if let title, let code = inferredLanguageCode(from: title) {
                return code
            }
        }

        return nil
    }

    static func localizedLanguageName(for code: String) -> String? {
        Locale.current.localizedString(forLanguageCode: code)
        ?? Locale(identifier: "en").localizedString(forLanguageCode: code)
        ?? Locale(identifier: code).localizedString(forLanguageCode: code)
    }

    private static func inferredLanguageCode(from value: String) -> String? {
        let normalizedValue = normalizedPhrase(value)
        guard !normalizedValue.isEmpty else { return nil }

        if let identifierCode = languageCode(fromIdentifier: normalizedValue.replacingOccurrences(of: " ", with: "-")) {
            return identifierCode
        }

        for token in normalizedValue.split(separator: " ").map(String.init) {
            if let identifierCode = languageCode(fromIdentifier: token) {
                return identifierCode
            }
        }

        let haystack = " \(normalizedValue) "
        for (languageName, code) in languageNameLookup {
            if haystack.contains(" \(languageName) ") {
                return code
            }
        }

        return nil
    }

    private static func languageCode(fromIdentifier identifier: String) -> String? {
        NSLocale.components(fromLocaleIdentifier: identifier)["kCFLocaleLanguageCodeKey"]?.lowercased()
    }

    private static func normalizedPhrase(_ value: String) -> String {
        let folded = value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let scalars = folded.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar)) : " "
        }
        let normalized = String(scalars)
        return normalized
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static let languageNameLookup: [(String, String)] = {
        let displayLocales = [Locale.current, Locale(identifier: "en")]
        var lookup: [String: String] = [:]

        for code in Locale.LanguageCode.isoLanguageCodes.map(\.identifier) {
            for locale in displayLocales + [Locale(identifier: code)] {
                if let languageName = locale.localizedString(forLanguageCode: code) {
                    let normalized = normalizedPhrase(languageName)
                    if normalized.count >= 3 {
                        lookup[normalized] = code.lowercased()
                    }
                }
            }
        }

        return lookup
            .map { ($0.key, $0.value) }
            .sorted { $0.0.count > $1.0.count }
    }()
}
