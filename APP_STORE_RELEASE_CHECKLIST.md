# StreamShelf App Store Release Checklist

## Build

- Build with Xcode 26 or later for App Store uploads.
- Archive the `StreamShelf` scheme using the `Release` configuration.
- Confirm the installed app name is `StreamShelf`.
- Confirm the app icon renders correctly at all sizes.

## Server Access

- Use HTTPS for off-network server URLs. Do not submit a build that requires sending Plex tokens over remote HTTP.
- Local network HTTP is acceptable for home/LAN testing, but the App Store review demo account should use a reachable HTTPS endpoint.
- In App Review notes, explain that users connect the app to their own Plex Media Server and that no media content is provided by the app developer.

## Privacy

- Provide a privacy policy URL in App Store Connect.
- App Store Connect privacy answers should reflect that the app stores the server URL, library preference, favorites, playback progress, and token locally on-device.
- The Plex token is stored in Keychain. UserDefaults is used for non-sensitive local preferences.
- The app does not include analytics, ads, tracking, or third-party SDKs.

## App Store Connect

- Name: `StreamShelf`
- Subtitle: `Stream your home library`
- Primary category: Entertainment
- Content rights: user-provided/personal media server access; the app does not sell or bundle third-party media.
- Age rating: complete based on the app's ability to access user-owned media libraries.
- Add accessibility support details for VoiceOver, Larger Text, Dark Interface, Sufficient Contrast, and Differentiate Without Color if verified.

## Pre-Submission QA

- Test first launch and server setup on a clean install.
- Test LAN and off-network HTTPS server connections.
- Test library browsing, search, favorites, detail loading, resume playback, and progress sync.
- Test playback failure messaging by using an unreachable server URL.
- Test with empty libraries, missing artwork, and unavailable favorite items.
- Capture App Store screenshots from a release build with representative non-copyright-infringing media.
