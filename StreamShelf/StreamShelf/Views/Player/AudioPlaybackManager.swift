import AVFoundation
import Foundation
import SwiftUI

@MainActor
final class AudioPlaybackManager: ObservableObject {
    @Published private(set) var currentItem: PlexMovie?
    @Published private(set) var queue: [PlexMovie] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var playOrder: [Int] = []
    @Published private(set) var playOrderPosition = 0
    @Published private(set) var isShuffleEnabled = false
    @Published private(set) var isGlobalShuffleMode = false
    @Published private(set) var isReady = false
    @Published private(set) var isPlaying = false
    @Published private(set) var progressSeconds = 0.0
    @Published private(set) var durationSeconds = 0.0
    @Published private(set) var playbackError: String?
    @Published var isFullPlayerPresented = false
    @Published var isLoadingGlobalShuffle = false

    private let progressSyncIntervalNanoseconds: UInt64 = 15_000_000_000
    private let playbackStartupTimeoutNanoseconds: UInt64 = 20_000_000_000
    private let playbackStatusPollIntervalNanoseconds: UInt64 = 250_000_000

    private var player: AVPlayer?
    private var playbackStartupTask: Task<Void, Never>?
    private var progressReportingTask: Task<Void, Never>?
    private var playbackSessionID = "StreamShelf-\(UUID().uuidString)"
    private var endingItemIdentity: ObjectIdentifier?

    private let api: PlexAPIClient
    private let config: PlexConfig

    init(api: PlexAPIClient = .shared, config: PlexConfig = .shared) {
        self.api = api
        self.config = config
    }

    var hasActiveItem: Bool {
        currentItem != nil
    }

    var canPlayNext: Bool {
        guard queue.count > 1 else { return false }
        if isShuffleEnabled {
            return playOrderPosition < playOrder.count - 1
        }
        return currentIndex < queue.count - 1
    }

    var canPlayPrevious: Bool {
        if progressSeconds > 3 {
            return true
        }

        guard queue.count > 1 else { return false }
        if isShuffleEnabled {
            return playOrderPosition > 0
        }
        return currentIndex > 0
    }

    func play(item: PlexMovie, queue proposedQueue: [PlexMovie] = [], shuffle: Bool = false, globalShuffle: Bool = false) {
        let resolvedQueue = Self.normalizedQueue(item: item, queue: proposedQueue)
        let resolvedIndex = resolvedQueue.firstIndex(where: { $0.id == item.id }) ?? 0

        if currentItem?.id == item.id, self.queue.map(\.id) == resolvedQueue.map(\.id) {
            isFullPlayerPresented = true
            return
        }

        stopPlayback(reportProgress: true)
        queue = resolvedQueue
        currentIndex = resolvedIndex
        currentItem = resolvedQueue[resolvedIndex]
        isShuffleEnabled = shuffle
        isGlobalShuffleMode = globalShuffle
        configurePlayOrder(startingAt: resolvedIndex, shuffle: shuffle)
        progressSeconds = 0
        durationSeconds = Double(resolvedQueue[resolvedIndex].playbackDuration ?? 0) / 1000
        playbackSessionID = "StreamShelf-\(UUID().uuidString)"
        startPlayback(offsetMilliseconds: config.resumeOffset(for: resolvedQueue[resolvedIndex]))
        isFullPlayerPresented = true

        Task { @MainActor in
            await loadCurrentTrackMetadataIfNeeded()
        }
    }

    func playGlobalShuffle() async {
        guard !isLoadingGlobalShuffle else { return }
        isLoadingGlobalShuffle = true
        playbackError = nil

        do {
            let tracks = try await api.fetchAllMusicTracks()
            isLoadingGlobalShuffle = false
            guard let first = tracks.shuffled().first else {
                playbackError = "No songs were found in your music libraries."
                return
            }
            play(item: first, queue: tracks, shuffle: true, globalShuffle: true)
        } catch {
            isLoadingGlobalShuffle = false
            playbackError = error.localizedDescription
        }
    }

    func togglePlayback() {
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

    func toggleShuffle() {
        guard queue.count > 1 else { return }
        isShuffleEnabled.toggle()
        configurePlayOrder(startingAt: currentIndex, shuffle: isShuffleEnabled)
    }

    func playNextTrack() {
        guard canPlayNext else { return }

        if isShuffleEnabled {
            moveToTrack(at: playOrderPosition + 1)
        } else {
            moveToQueueIndex(currentIndex + 1)
        }
    }

    func playPreviousTrack() {
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

    func seek(to seconds: Double) {
        progressSeconds = seconds
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600)) { _ in
            Task { @MainActor in
                self.syncCurrentProgress(state: self.isPlaying ? .playing : .paused)
            }
        }
    }

    func stop() {
        stopPlayback(reportProgress: true)
        currentItem = nil
        queue = []
        currentIndex = 0
        playOrder = []
        playOrderPosition = 0
        isShuffleEnabled = false
        isGlobalShuffleMode = false
        progressSeconds = 0
        durationSeconds = 0
        playbackError = nil
        isFullPlayerPresented = false
    }

    func updatePlaybackPosition() {
        guard let player else { return }
        let seconds = player.currentTime().seconds
        if seconds.isFinite, seconds >= 0 {
            progressSeconds = seconds
        }

        if let item = player.currentItem {
            durationSeconds = resolvedDurationSeconds(for: item)
        }
    }

    func handleScenePhaseChange(_ newPhase: ScenePhase) {
        guard player != nil else { return }

        switch newPhase {
        case .inactive, .background:
            syncCurrentProgress(state: isPlaying ? .playing : .paused)
        case .active:
            break
        @unknown default:
            break
        }
    }

    func handlePlaybackEndedNotification(_ notification: Notification) {
        guard let endedItem = notification.object as? AVPlayerItem else { return }
        guard ObjectIdentifier(endedItem) == endingItemIdentity else { return }

        isPlaying = false
        progressReportingTask?.cancel()
        progressReportingTask = nil

        if let durationMilliseconds = currentItem?.playbackDuration {
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
        } else {
            endingItemIdentity = nil
        }
    }

    func handlePlaybackFailedNotification(_ notification: Notification) {
        guard notification.object as AnyObject? === player?.currentItem else { return }
        playbackError = playbackErrorMessage(for: player?.currentItem)
    }

    func timeLabel(_ seconds: Double) -> String {
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

    private func configurePlayOrder(startingAt index: Int, shuffle: Bool) {
        if shuffle {
            let remaining = queue.indices.filter { $0 != index }.shuffled()
            playOrder = [index] + remaining
            playOrderPosition = 0
        } else {
            playOrder = Array(queue.indices)
            playOrderPosition = index
        }
    }

    private func startPlayback(offsetMilliseconds: Int?) {
        guard let currentItem else { return }
        configureAudioSession()

        guard let url = config.playbackURL(
            for: currentItem.metadataKey,
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
        endingItemIdentity = ObjectIdentifier(playerItem)
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

    private func moveToTrack(at orderPosition: Int) {
        guard playOrder.indices.contains(orderPosition) else { return }
        playOrderPosition = orderPosition
        moveToQueueIndex(playOrder[orderPosition], updatePlayOrderPosition: false)
    }

    private func moveToQueueIndex(_ index: Int, updatePlayOrderPosition: Bool = true) {
        guard queue.indices.contains(index) else { return }

        syncCurrentProgress(state: .stopped)
        stopPlayback(reportProgress: false)
        currentIndex = index
        if updatePlayOrderPosition {
            playOrderPosition = playOrder.firstIndex(of: index) ?? index
        }
        currentItem = queue[index]
        progressSeconds = 0
        durationSeconds = Double(queue[index].playbackDuration ?? 0) / 1000
        playbackSessionID = "StreamShelf-\(UUID().uuidString)"
        startPlayback(offsetMilliseconds: config.resumeOffset(for: queue[index]))

        Task { @MainActor in
            await loadCurrentTrackMetadataIfNeeded()
        }
    }

    private func stopPlayback(reportProgress: Bool) {
        if reportProgress, let snapshot = currentProgressSnapshot() {
            persistAndReportProgress(snapshot, state: .stopped)
        }

        playbackStartupTask?.cancel()
        playbackStartupTask = nil
        progressReportingTask?.cancel()
        progressReportingTask = nil
        player?.pause()
        player = nil
        endingItemIdentity = nil
        isReady = false
        isPlaying = false
    }

    private func resolvedDurationSeconds(for item: AVPlayerItem) -> Double {
        let itemDuration = item.duration.seconds
        if itemDuration.isFinite, itemDuration > 0 {
            return itemDuration
        }

        if let duration = currentItem?.playbackDuration, duration > 0 {
            return Double(duration) / 1000
        }

        return max(durationSeconds, 1)
    }

    private func loadCurrentTrackMetadataIfNeeded() async {
        guard let currentItem else { return }

        do {
            if let detail = try await api.fetchMovieDetail(ratingKey: currentItem.ratingKey) {
                guard queue.indices.contains(currentIndex), detail.ratingKey == queue[currentIndex].ratingKey else { return }
                self.currentItem = detail
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
                    self.syncCurrentProgress(state: self.isPlaying ? .playing : .paused)
                }
            }
        }
    }

    private func syncCurrentProgress(state: PlexPlaybackState) {
        guard let snapshot = currentProgressSnapshot() else { return }
        persistAndReportProgress(snapshot, state: state)
    }

    private func currentProgressSnapshot() -> PlaybackProgressSnapshot? {
        guard progressSeconds.isFinite, progressSeconds > 0, let currentItem else { return nil }
        return PlaybackProgressSnapshot(
            offsetMilliseconds: Int(progressSeconds * 1000),
            durationMilliseconds: currentItem.playbackDuration
        )
    }

    private func persistAndReportProgress(_ snapshot: PlaybackProgressSnapshot, state: PlexPlaybackState) {
        guard let currentItem else { return }

        config.savePlaybackProgress(
            for: currentItem,
            offsetMilliseconds: snapshot.offsetMilliseconds,
            durationMilliseconds: snapshot.durationMilliseconds
        )

        let item = currentItem
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

    private static func normalizedQueue(item: PlexMovie, queue: [PlexMovie]) -> [PlexMovie] {
        var resolved: [PlexMovie] = []

        for candidate in queue.filter(\.isTrack) + [item] {
            guard !resolved.contains(where: { $0.id == candidate.id }) else { continue }
            resolved.append(candidate)
        }

        return resolved.isEmpty ? [item] : resolved
    }
}
