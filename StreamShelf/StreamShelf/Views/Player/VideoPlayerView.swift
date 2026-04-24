import SwiftUI
import AVKit
import UIKit

struct VideoPlayerView: View {
    let item: PlexMovie
    let title: String

    private let controlsAutoHideDelayNanoseconds: UInt64 = 3_000_000_000
    private let progressSyncIntervalNanoseconds: UInt64 = 15_000_000_000
    private let playbackStartupTimeoutNanoseconds: UInt64 = 20_000_000_000
    private let playbackStatusPollIntervalNanoseconds: UInt64 = 250_000_000

    @State private var player: AVPlayer?
    @State private var isReady = false
    @State private var playbackMetadata: PlexMovie
    @State private var audioTracks: [PlaybackTrack] = []
    @State private var subtitleTracks: [PlaybackTrack] = []
    @State private var selectedAudioStreamID: Int?
    @State private var selectedSubtitleStreamID: Int?
    @State private var playbackError: String?
    @State private var controlsVisible = true
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var playbackStartupTask: Task<Void, Never>?
    @State private var progressReportingTask: Task<Void, Never>?
    @State private var playbackSessionID = "StreamShelf-\(UUID().uuidString)"

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var config: PlexConfig

    private let api = PlexAPIClient.shared

    init(item: PlexMovie, title: String) {
        self.item = item
        self.title = title
        _playbackMetadata = State(initialValue: item)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let playbackError {
                errorView(message: playbackError)
            } else if let player, isReady {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                loadingView
            }

            if !controlsVisible && playbackError == nil && isReady {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        showControlsTemporarily()
                    }
            }
        }
        .overlay(alignment: .topLeading) {
            if controlsVisible {
                dismissButton
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .topTrailing) {
            if controlsVisible {
                mediaMenus
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            if controlsVisible {
                titleOverlay
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .animation(.easeInOut(duration: 0.25), value: controlsVisible)
        .task {
            await preparePlaybackIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { notification in
            handlePlaybackEndedNotification(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime)) { notification in
            handlePlaybackFailedNotification(notification)
        }
        .onDisappear(perform: stopPlayback)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.4)
            Text("Preparing playback…")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.9))
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 28)
        }
    }

    private var dismissButton: some View {
        Button {
            stopPlayback()
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.white.opacity(0.85))
                .shadow(radius: 4)
        }
        .padding(.top, 56)
        .padding(.leading, 20)
    }

    private var mediaMenus: some View {
        HStack(spacing: 12) {
            if !subtitleTracks.isEmpty {
                Menu {
                    ForEach(subtitleTracks) { track in
                        Button {
                            selectSubtitleTrack(track)
                        } label: {
                            HStack {
                                Text(track.label)
                                if selectedSubtitleStreamID == track.streamID {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "captions.bubble.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(radius: 4)
                }
                .accessibilityLabel("Subtitle Stream")
            }

            if !audioTracks.isEmpty {
                Menu {
                    ForEach(audioTracks) { track in
                        Button {
                            selectAudioTrack(track)
                        } label: {
                            HStack {
                                Text(track.label)
                                if selectedAudioStreamID == track.streamID {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(radius: 4)
                }
                .accessibilityLabel("Audio Stream")
            }
        }
        .padding(.top, 56)
        .padding(.trailing, 20)
    }

    private var titleOverlay: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.black.opacity(0.35))
            .clipShape(Capsule())
            .padding(.top, 56)
    }

    @MainActor
    private func preparePlaybackIfNeeded() async {
        guard player == nil, playbackError == nil else { return }

        configureStreamMenus()
        startPlayback(offsetMilliseconds: config.resumeOffset(for: playbackMetadata))

        await loadPlaybackMetadataIfNeeded()
        configureStreamMenus()
    }

    @MainActor
    private func loadPlaybackMetadataIfNeeded() async {
        guard playbackMetadata.audioStreams.isEmpty && playbackMetadata.subtitleStreams.isEmpty else { return }

        do {
            if let detail = try await api.fetchMovieDetail(ratingKey: item.ratingKey) {
                playbackMetadata = detail
            }
        } catch {
            // Playback can still work even if stream metadata enrichment fails.
        }
    }

    @MainActor
    private func configureStreamMenus() {
        audioTracks = [PlaybackTrack.autoAudio] + playbackMetadata.audioStreams.map(PlaybackTrack.audio)
        subtitleTracks = [PlaybackTrack.subtitleOff] + playbackMetadata.subtitleStreams.map(PlaybackTrack.subtitle)

        if selectedAudioStreamID == nil {
            selectedAudioStreamID = playbackMetadata.audioStreams.first(where: { $0.selected == true || $0.isDefault == true })?.id
        }

        if selectedSubtitleStreamID == nil {
            selectedSubtitleStreamID = playbackMetadata.subtitleStreams.first(where: { $0.selected == true })?.id
        }
    }

    @MainActor
    private func selectAudioTrack(_ track: PlaybackTrack) {
        selectedAudioStreamID = track.streamID
        reloadPlaybackPreservingTime()
        showControlsTemporarily()
    }

    @MainActor
    private func selectSubtitleTrack(_ track: PlaybackTrack) {
        selectedSubtitleStreamID = track.streamID
        reloadPlaybackPreservingTime()
        showControlsTemporarily()
    }

    @MainActor
    private func reloadPlaybackPreservingTime() {
        let offsetMilliseconds = currentOffsetMilliseconds() ?? config.resumeOffset(for: playbackMetadata)
        startPlayback(offsetMilliseconds: offsetMilliseconds)
    }

    @MainActor
    private func startPlayback(offsetMilliseconds: Int?) {
        guard let url = currentPlaybackURL(offsetMilliseconds: offsetMilliseconds) else {
            playbackError = "Stream URL unavailable"
            return
        }

        playbackError = nil
        let playerItem = AVPlayerItem(url: url)
        playerItem.preferredForwardBufferDuration = 5

        if let player {
            player.replaceCurrentItem(with: playerItem)
            schedulePlayback(on: player, item: playerItem)
        } else {
            let player = AVPlayer(playerItem: playerItem)
            self.player = player
            schedulePlayback(on: player, item: playerItem)
        }
    }

    private func schedulePlayback(on player: AVPlayer, item: AVPlayerItem) {
        isReady = false
        controlsVisible = true
        playbackStartupTask?.cancel()
        progressReportingTask?.cancel()

        playbackStartupTask = Task { @MainActor in
            var elapsedNanoseconds: UInt64 = 0

            while !Task.isCancelled {
                guard self.player === player, player.currentItem === item else { return }

                switch item.status {
                case .readyToPlay:
                    self.playbackStartupTask = nil
                    self.isReady = true
                    player.play()
                    self.startProgressReporting()
                    self.showControlsTemporarily()
                    return
                case .failed:
                    self.playbackStartupTask = nil
                    self.playbackError = self.playbackErrorMessage(for: item)
                    return
                case .unknown:
                    break
                @unknown default:
                    break
                }

                if elapsedNanoseconds >= self.playbackStartupTimeoutNanoseconds {
                    self.playbackStartupTask = nil
                    self.playbackError = "Playback did not start. Check that your no-ip address and forwarded port can reach Plex from cellular or another outside network."
                    return
                }

                try? await Task.sleep(nanoseconds: self.playbackStatusPollIntervalNanoseconds)
                elapsedNanoseconds += self.playbackStatusPollIntervalNanoseconds
            }
        }
    }

    private func stopPlayback() {
        if let snapshot = currentProgressSnapshot() {
            persistAndReportProgress(snapshot, state: .stopped)
        }

        hideControlsTask?.cancel()
        hideControlsTask = nil
        playbackStartupTask?.cancel()
        playbackStartupTask = nil
        progressReportingTask?.cancel()
        progressReportingTask = nil
        player?.pause()
        player = nil
        isReady = false
        controlsVisible = true
    }

    private func currentPlaybackURL(offsetMilliseconds: Int?) -> URL? {
        return config.playbackURL(
            for: playbackMetadata.metadataKey,
            offset: offsetMilliseconds,
            audioStreamID: selectedAudioStreamID,
            subtitleStreamID: selectedSubtitleStreamID,
            sessionIdentifier: playbackSessionID
        )
    }

    private func currentOffsetMilliseconds() -> Int? {
        guard let seconds = player?.currentTime().seconds, seconds.isFinite, seconds > 0 else {
            return nil
        }
        return Int(seconds * 1000)
    }

    private func showControlsTemporarily() {
        hideControlsTask?.cancel()
        withAnimation(.easeInOut(duration: 0.25)) {
            controlsVisible = true
        }

        guard playbackError == nil, isReady else { return }

        hideControlsTask = Task {
            try? await Task.sleep(nanoseconds: controlsAutoHideDelayNanoseconds)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.25)) {
                    controlsVisible = false
                }
            }
        }
    }

    private func startProgressReporting() {
        progressReportingTask?.cancel()
        progressReportingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: progressSyncIntervalNanoseconds)
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    syncCurrentProgress(state: .playing)
                }
            }
        }
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        guard player != nil else { return }

        switch newPhase {
        case .inactive, .background:
            syncCurrentProgress(state: .paused)
        case .active:
            break
        @unknown default:
            break
        }
    }

    private func handlePlaybackEndedNotification(_ notification: Notification) {
        guard notification.object as AnyObject? === player?.currentItem else { return }
        progressReportingTask?.cancel()
        progressReportingTask = nil

        if let durationMilliseconds = playbackMetadata.playbackDuration {
            persistAndReportProgress(
                PlaybackProgressSnapshot(
                    offsetMilliseconds: durationMilliseconds,
                    durationMilliseconds: durationMilliseconds
                ),
                state: .stopped
            )
        } else {
            syncCurrentProgress(state: .stopped)
        }
    }

    private func handlePlaybackFailedNotification(_ notification: Notification) {
        guard notification.object as AnyObject? === player?.currentItem else { return }
        playbackError = playbackErrorMessage(for: player?.currentItem)
    }

    private func playbackErrorMessage(for item: AVPlayerItem?) -> String {
        let detail = item?.error?.localizedDescription
            ?? item?.errorLog()?.events.last?.errorComment
            ?? item?.errorLog()?.events.last?.uri

        if let detail, !detail.isEmpty {
            return "Playback failed: \(detail)"
        }

        return "Playback failed. Check that the Plex remote URL is reachable and that remote streaming is allowed on the server."
    }

    private func syncCurrentProgress(state: PlexPlaybackState) {
        guard let snapshot = currentProgressSnapshot() else { return }
        persistAndReportProgress(snapshot, state: state)
    }

    private func currentProgressSnapshot() -> PlaybackProgressSnapshot? {
        guard let offsetMilliseconds = currentOffsetMilliseconds() else { return nil }
        return PlaybackProgressSnapshot(
            offsetMilliseconds: offsetMilliseconds,
            durationMilliseconds: playbackMetadata.playbackDuration
        )
    }

    private func persistAndReportProgress(_ snapshot: PlaybackProgressSnapshot, state: PlexPlaybackState) {
        config.savePlaybackProgress(
            for: playbackMetadata,
            offsetMilliseconds: snapshot.offsetMilliseconds,
            durationMilliseconds: snapshot.durationMilliseconds
        )

        let item = playbackMetadata
        let sessionIdentifier = playbackSessionID

        Task {
            try? await api.reportTimeline(
                for: item,
                offsetMilliseconds: snapshot.offsetMilliseconds,
                durationMilliseconds: snapshot.durationMilliseconds,
                state: state,
                sessionIdentifier: sessionIdentifier
            )
        }
    }
}

private struct PlaybackProgressSnapshot {
    let offsetMilliseconds: Int
    let durationMilliseconds: Int?
}

private struct PlaybackTrack: Identifiable {
    let id: String
    let label: String
    let streamID: Int?

    static let autoAudio = PlaybackTrack(id: "audio-auto", label: "Auto", streamID: nil)
    static let subtitleOff = PlaybackTrack(id: "subtitle-off", label: "Off", streamID: nil)

    static func audio(_ stream: PlexMediaStream) -> PlaybackTrack {
        PlaybackTrack(id: "audio-\(stream.id)", label: stream.label, streamID: stream.id)
    }

    static func subtitle(_ stream: PlexMediaStream) -> PlaybackTrack {
        PlaybackTrack(id: "subtitle-\(stream.id)", label: stream.label, streamID: stream.id)
    }
}

struct AudioPlayerView: View {
    let item: PlexMovie
    let queue: [PlexMovie]

    private let progressSyncIntervalNanoseconds: UInt64 = 15_000_000_000
    private let playbackStartupTimeoutNanoseconds: UInt64 = 20_000_000_000
    private let playbackStatusPollIntervalNanoseconds: UInt64 = 250_000_000

    @State private var player: AVPlayer?
    @State private var currentIndex: Int
    @State private var playOrder: [Int]
    @State private var playOrderPosition: Int
    @State private var isShuffleEnabled = false
    @State private var playbackMetadata: PlexMovie
    @State private var isReady = false
    @State private var isPlaying = false
    @State private var progressSeconds = 0.0
    @State private var durationSeconds = 0.0
    @State private var playbackError: String?
    @State private var playbackStartupTask: Task<Void, Never>?
    @State private var progressReportingTask: Task<Void, Never>?
    @State private var playbackSessionID = "StreamShelf-\(UUID().uuidString)"

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var config: PlexConfig

    private let api = PlexAPIClient.shared

    init(item: PlexMovie, queue: [PlexMovie] = []) {
        let resolvedQueue = Self.normalizedQueue(item: item, queue: queue)
        let resolvedIndex = resolvedQueue.firstIndex(where: { $0.id == item.id }) ?? 0

        self.item = item
        self.queue = resolvedQueue
        _currentIndex = State(initialValue: resolvedIndex)
        _playOrder = State(initialValue: Array(resolvedQueue.indices))
        _playOrderPosition = State(initialValue: resolvedIndex)
        _playbackMetadata = State(initialValue: resolvedQueue[resolvedIndex])
    }

    var body: some View {
        ZStack {
            StreamShelfTheme.Colors.appBackground.ignoresSafeArea()

            VStack(spacing: StreamShelfTheme.Spacing.xl) {
                header
                artwork
                trackInfo

                if let playbackError {
                    Label(playbackError, systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(StreamShelfTheme.Colors.warning)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, StreamShelfTheme.Spacing.lg)
                } else {
                    playbackControls
                }

                Spacer(minLength: 0)
            }
            .padding(StreamShelfTheme.Spacing.lg)
        }
        .preferredColorScheme(.dark)
        .task {
            await preparePlaybackIfNeeded()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            updatePlaybackPosition()
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { notification in
            handlePlaybackEndedNotification(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime)) { notification in
            guard notification.object as AnyObject? === player?.currentItem else { return }
            playbackError = playbackErrorMessage(for: player?.currentItem)
        }
        .onDisappear(perform: stopPlayback)
    }

    private var header: some View {
        HStack {
            Button {
                stopPlayback()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
            }
            .accessibilityLabel("Close Player")

            Spacer()

            Text("Now Playing")
                .font(.headline)
                .foregroundStyle(StreamShelfTheme.Colors.primaryText)

            Spacer()

            Color.clear
                .frame(width: 30, height: 30)
        }
    }

    private var artwork: some View {
        PosterView(
            url: config.imageURL(for: playbackMetadata.artworkPath, width: 600, height: 600),
            width: min(UIScreen.main.bounds.width - 80, 320),
            height: min(UIScreen.main.bounds.width - 80, 320),
            cornerRadius: 12
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(StreamShelfTheme.Colors.separator)
        )
        .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
    }

    private var trackInfo: some View {
        VStack(spacing: StreamShelfTheme.Spacing.xs) {
            Text(playbackMetadata.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(StreamShelfTheme.Colors.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            if let subtitle = playbackMetadata.browseSubtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            if queue.count > 1 {
                Text("\(currentIndex + 1) of \(queue.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(StreamShelfTheme.Colors.tertiaryText)
            }
        }
    }

    private var playbackControls: some View {
        VStack(spacing: StreamShelfTheme.Spacing.lg) {
            VStack(spacing: StreamShelfTheme.Spacing.xs) {
                Slider(
                    value: Binding(
                        get: { progressSeconds },
                        set: { seek(to: $0) }
                    ),
                    in: 0...max(durationSeconds, 1)
                )
                .tint(StreamShelfTheme.Colors.accent)
                .disabled(!isReady)

                HStack {
                    Text(timeLabel(progressSeconds))
                    Spacer()
                    Text(timeLabel(durationSeconds))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
            }

            HStack(spacing: StreamShelfTheme.Spacing.md) {
                Button {
                    toggleShuffle()
                } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(isShuffleEnabled ? StreamShelfTheme.Colors.accent : StreamShelfTheme.Colors.secondaryText)
                        .frame(width: 40, height: 44)
                }
                .disabled(queue.count < 2)
                .accessibilityLabel(isShuffleEnabled ? "Turn Shuffle Off" : "Turn Shuffle On")

                Button {
                    playPreviousTrack()
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(canPlayPrevious ? StreamShelfTheme.Colors.primaryText : StreamShelfTheme.Colors.tertiaryText)
                        .frame(width: 40, height: 44)
                }
                .disabled(!canPlayPrevious)
                .accessibilityLabel("Previous Track")

                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(isReady ? StreamShelfTheme.Colors.accent : StreamShelfTheme.Colors.tertiaryText)
                }
                .disabled(!isReady)
                .accessibilityLabel(isPlaying ? "Pause" : "Play")

                Button {
                    playNextTrack()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(canPlayNext ? StreamShelfTheme.Colors.primaryText : StreamShelfTheme.Colors.tertiaryText)
                        .frame(width: 40, height: 44)
                }
                .disabled(!canPlayNext)
                .accessibilityLabel("Next Track")
            }
        }
    }

    private var canPlayNext: Bool {
        guard queue.count > 1 else { return false }
        if isShuffleEnabled {
            return playOrderPosition < playOrder.count - 1
        }
        return currentIndex < queue.count - 1
    }

    private var canPlayPrevious: Bool {
        if progressSeconds > 3 {
            return true
        }

        guard queue.count > 1 else { return false }
        if isShuffleEnabled {
            return playOrderPosition > 0
        }
        return currentIndex > 0
    }

    @MainActor
    private func preparePlaybackIfNeeded() async {
        guard player == nil, playbackError == nil else { return }
        startPlayback(offsetMilliseconds: config.resumeOffset(for: playbackMetadata))

        do {
            let ratingKey = playbackMetadata.ratingKey
            if let detail = try await api.fetchMovieDetail(ratingKey: ratingKey), playbackMetadata.ratingKey == ratingKey {
                playbackMetadata = detail
            }
        } catch {
            // Audio can still start with the metadata returned by the library listing.
        }
    }

    @MainActor
    private func startPlayback(offsetMilliseconds: Int?) {
        configureAudioSession()

        guard let url = config.playbackURL(
            for: playbackMetadata.metadataKey,
            offset: offsetMilliseconds,
            sessionIdentifier: playbackSessionID,
            mediaKind: .audio
        ) else {
            playbackError = "Stream URL unavailable"
            return
        }

        playbackError = nil
        let playerItem = AVPlayerItem(url: url)
        playerItem.preferredForwardBufferDuration = 5
        let player = AVPlayer(playerItem: playerItem)
        self.player = player
        schedulePlayback(on: player, item: playerItem)
    }

    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func schedulePlayback(on player: AVPlayer, item: AVPlayerItem) {
        isReady = false
        isPlaying = false
        playbackStartupTask?.cancel()
        progressReportingTask?.cancel()

        playbackStartupTask = Task { @MainActor in
            var elapsedNanoseconds: UInt64 = 0

            while !Task.isCancelled {
                guard self.player === player, player.currentItem === item else { return }

                switch item.status {
                case .readyToPlay:
                    self.playbackStartupTask = nil
                    self.isReady = true
                    self.durationSeconds = self.resolvedDurationSeconds(for: item)
                    player.play()
                    self.isPlaying = true
                    self.startProgressReporting()
                    return
                case .failed:
                    self.playbackStartupTask = nil
                    self.playbackError = self.playbackErrorMessage(for: item)
                    return
                case .unknown:
                    break
                @unknown default:
                    break
                }

                if elapsedNanoseconds >= self.playbackStartupTimeoutNanoseconds {
                    self.playbackStartupTask = nil
                    self.playbackError = "Playback did not start. Check that your Plex remote URL is reachable and that remote streaming is allowed on the server."
                    return
                }

                try? await Task.sleep(nanoseconds: self.playbackStatusPollIntervalNanoseconds)
                elapsedNanoseconds += self.playbackStatusPollIntervalNanoseconds
            }
        }
    }

    private func togglePlayback() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
            syncCurrentProgress(state: .paused)
        } else {
            player.play()
            isPlaying = true
            startProgressReporting()
        }
    }

    private func toggleShuffle() {
        guard queue.count > 1 else { return }
        isShuffleEnabled.toggle()

        if isShuffleEnabled {
            let remaining = queue.indices.filter { $0 != currentIndex }.shuffled()
            playOrder = [currentIndex] + remaining
            playOrderPosition = 0
        } else {
            playOrder = Array(queue.indices)
            playOrderPosition = currentIndex
        }
    }

    private func playNextTrack() {
        guard canPlayNext else { return }

        if isShuffleEnabled {
            moveToTrack(at: playOrderPosition + 1)
        } else {
            moveToQueueIndex(currentIndex + 1)
        }
    }

    private func playPreviousTrack() {
        if progressSeconds > 3 {
            seek(to: 0)
            return
        }

        guard canPlayPrevious else { return }

        if isShuffleEnabled {
            moveToTrack(at: playOrderPosition - 1)
        } else {
            moveToQueueIndex(currentIndex - 1)
        }
    }

    private func moveToTrack(at orderPosition: Int) {
        guard playOrder.indices.contains(orderPosition) else { return }
        playOrderPosition = orderPosition
        moveToQueueIndex(playOrder[orderPosition], updatePlayOrderPosition: false)
    }

    private func moveToQueueIndex(_ index: Int, updatePlayOrderPosition: Bool = true) {
        guard queue.indices.contains(index) else { return }

        syncCurrentProgress(state: .stopped)
        currentIndex = index
        if updatePlayOrderPosition {
            playOrderPosition = playOrder.firstIndex(of: index) ?? index
        }
        playbackMetadata = queue[index]
        progressSeconds = 0
        durationSeconds = Double(queue[index].playbackDuration ?? 0) / 1000
        playbackSessionID = "StreamShelf-\(UUID().uuidString)"
        startPlayback(offsetMilliseconds: config.resumeOffset(for: queue[index]))

        Task { @MainActor in
            await loadCurrentTrackMetadataIfNeeded()
        }
    }

    private func seek(to seconds: Double) {
        progressSeconds = seconds
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600)) { _ in
            Task { @MainActor in
                syncCurrentProgress(state: isPlaying ? .playing : .paused)
            }
        }
    }

    private func stopPlayback() {
        if let snapshot = currentProgressSnapshot() {
            persistAndReportProgress(snapshot, state: .stopped)
        }

        playbackStartupTask?.cancel()
        playbackStartupTask = nil
        progressReportingTask?.cancel()
        progressReportingTask = nil
        player?.pause()
        player = nil
        isReady = false
        isPlaying = false
    }

    private func updatePlaybackPosition() {
        guard let player else { return }
        let seconds = player.currentTime().seconds
        if seconds.isFinite, seconds >= 0 {
            progressSeconds = seconds
        }

        if let item = player.currentItem {
            durationSeconds = resolvedDurationSeconds(for: item)
        }
    }

    private func resolvedDurationSeconds(for item: AVPlayerItem) -> Double {
        let itemDuration = item.duration.seconds
        if itemDuration.isFinite, itemDuration > 0 {
            return itemDuration
        }

        if let duration = playbackMetadata.playbackDuration, duration > 0 {
            return Double(duration) / 1000
        }

        return max(durationSeconds, 1)
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        guard player != nil else { return }

        switch newPhase {
        case .inactive, .background:
            syncCurrentProgress(state: .paused)
        case .active:
            break
        @unknown default:
            break
        }
    }

    private func handlePlaybackEndedNotification(_ notification: Notification) {
        guard notification.object as AnyObject? === player?.currentItem else { return }
        isPlaying = false
        progressReportingTask?.cancel()
        progressReportingTask = nil

        if let durationMilliseconds = playbackMetadata.playbackDuration {
            persistAndReportProgress(
                PlaybackProgressSnapshot(
                    offsetMilliseconds: durationMilliseconds,
                    durationMilliseconds: durationMilliseconds
                ),
                state: .stopped
            )
        } else {
            syncCurrentProgress(state: .stopped)
        }

        if canPlayNext {
            playNextTrack()
        }
    }

    @MainActor
    private func loadCurrentTrackMetadataIfNeeded() async {
        do {
            if let detail = try await api.fetchMovieDetail(ratingKey: playbackMetadata.ratingKey) {
                guard queue.indices.contains(currentIndex), detail.ratingKey == queue[currentIndex].ratingKey else { return }
                playbackMetadata = detail
            }
        } catch {
            // The queued track can still play with the metadata already loaded in the album listing.
        }
    }

    private func playbackErrorMessage(for item: AVPlayerItem?) -> String {
        let detail = item?.error?.localizedDescription
            ?? item?.errorLog()?.events.last?.errorComment
            ?? item?.errorLog()?.events.last?.uri

        if let detail, !detail.isEmpty {
            return "Playback failed: \(detail)"
        }

        return "Playback failed. Check that the Plex remote URL is reachable and that remote streaming is allowed on the server."
    }

    private func startProgressReporting() {
        progressReportingTask?.cancel()
        progressReportingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: progressSyncIntervalNanoseconds)
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    syncCurrentProgress(state: isPlaying ? .playing : .paused)
                }
            }
        }
    }

    private func syncCurrentProgress(state: PlexPlaybackState) {
        guard let snapshot = currentProgressSnapshot() else { return }
        persistAndReportProgress(snapshot, state: state)
    }

    private func currentProgressSnapshot() -> PlaybackProgressSnapshot? {
        guard progressSeconds.isFinite, progressSeconds > 0 else { return nil }
        return PlaybackProgressSnapshot(
            offsetMilliseconds: Int(progressSeconds * 1000),
            durationMilliseconds: playbackMetadata.playbackDuration
        )
    }

    private func persistAndReportProgress(_ snapshot: PlaybackProgressSnapshot, state: PlexPlaybackState) {
        config.savePlaybackProgress(
            for: playbackMetadata,
            offsetMilliseconds: snapshot.offsetMilliseconds,
            durationMilliseconds: snapshot.durationMilliseconds
        )

        let item = playbackMetadata
        let sessionIdentifier = playbackSessionID

        Task {
            try? await api.reportTimeline(
                for: item,
                offsetMilliseconds: snapshot.offsetMilliseconds,
                durationMilliseconds: snapshot.durationMilliseconds,
                state: state,
                sessionIdentifier: sessionIdentifier
            )
        }
    }

    private func timeLabel(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let remainingSeconds = total % 60

        if hours > 0 {
            return "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", remainingSeconds))"
        }

        return "\(minutes):\(String(format: "%02d", remainingSeconds))"
    }

    private static func normalizedQueue(item: PlexMovie, queue: [PlexMovie]) -> [PlexMovie] {
        var resolved: [PlexMovie] = []

        for candidate in queue.filter(\.isTrack) + [item] {
            guard !resolved.contains(where: { $0.id == candidate.id }) else { continue }
            resolved.append(candidate)
        }

        return resolved.isEmpty ? [item] : resolved
    }
}

#Preview {
    NavigationStack {
        VideoPlayerView(item: .preview, title: "Sample")
            .environmentObject(PlexConfig.shared)
    }
}
