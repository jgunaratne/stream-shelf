import Foundation

extension PlexMovie {
    static let preview = PlexMovie(
        ratingKey: "1001",
        key: "/library/metadata/1001",
        title: "The Grand Illusion",
        type: "movie",
        year: 1937,
        summary: "A classic wartime drama about class, nationality, and humanity, directed by Jean Renoir.",
        thumb: nil,
        art: nil,
        duration: 7020000,
        contentRating: "NR",
        rating: 8.1,
        studio: "Realisation d'Art Cinematographique",
        tagline: "One of cinema's lasting masterpieces.",
        originallyAvailableAt: "1937-06-04",
        viewOffset: 1800000,
        index: nil,
        parentIndex: nil,
        parentTitle: nil,
        parentThumb: nil,
        grandparentTitle: nil,
        grandparentKey: nil,
        grandparentThumb: nil,
        childCount: nil,
        leafCount: nil,
        genre: [PlexTag(tag: "Drama"), PlexTag(tag: "War")],
        director: [PlexTag(tag: "Jean Renoir")],
        writer: [PlexTag(tag: "Jean Renoir"), PlexTag(tag: "Charles Spaak")],
        role: [PlexRole(rawID: 1, tag: "Jean Gabin", role: "Lt. Maréchal")],
        media: [
            PlexMedia(
                id: 1,
                duration: 7020000,
                bitrate: 4000,
                videoCodec: "h264",
                audioCodec: "aac",
                container: "mkv",
                part: [
                    PlexPart(
                        id: 1,
                        key: "/library/parts/1/stream",
                        duration: 7020000,
                        file: nil,
                        size: nil,
                        container: "mkv",
                        streams: [
                            PlexMediaStream(
                                id: 101,
                                streamType: 2,
                                language: "English",
                                languageTag: "en",
                                title: nil,
                                displayTitle: "English (AAC Stereo)",
                                extendedDisplayTitle: "English",
                                codec: "aac",
                                channels: 2,
                                selected: true,
                                forced: nil,
                                isDefault: true
                            ),
                            PlexMediaStream(
                                id: 102,
                                streamType: 2,
                                language: "Italian",
                                languageTag: "it",
                                title: nil,
                                displayTitle: "Italian (AAC Stereo)",
                                extendedDisplayTitle: "Italian",
                                codec: "aac",
                                channels: 2,
                                selected: false,
                                forced: nil,
                                isDefault: false
                            ),
                            PlexMediaStream(
                                id: 201,
                                streamType: 3,
                                language: "English",
                                languageTag: "en",
                                title: nil,
                                displayTitle: "English (SRT)",
                                extendedDisplayTitle: "English",
                                codec: "srt",
                                channels: nil,
                                selected: false,
                                forced: nil,
                                isDefault: false
                            )
                        ]
                    )
                ]
            )
        ]
    )
}

extension PlexLibrarySection {
    static let preview = PlexLibrarySection(key: "1", title: "Movies", type: "movie", thumb: nil)
}
