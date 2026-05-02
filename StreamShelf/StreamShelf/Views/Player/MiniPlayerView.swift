import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject private var audioPlayer: AudioPlaybackManager
    @EnvironmentObject private var config: PlexConfig

    var body: some View {
        if let item = audioPlayer.currentItem, !audioPlayer.isMiniPlayerHidden {
            HStack(spacing: StreamShelfTheme.Spacing.sm) {
                PosterView(
                    url: config.imageURL(for: item.artworkPath, width: 96, height: 96),
                    width: 46,
                    height: 46,
                    cornerRadius: 6
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(StreamShelfTheme.Colors.primaryText)
                        .lineLimit(1)

                    Text(item.browseSubtitle ?? "Now Playing")
                        .font(.caption)
                        .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: StreamShelfTheme.Spacing.sm)

                Menu {
                    Button {
                        audioPlayer.toggleShuffle()
                    } label: {
                        Label(
                            audioPlayer.isShuffleEnabled ? "Turn Shuffle Off" : "Shuffle Current Queue",
                            systemImage: "shuffle"
                        )
                    }
                    .disabled(audioPlayer.queue.count < 2)

                    Button {
                        Task { await audioPlayer.shuffleAllSongsAfterCurrent() }
                    } label: {
                        Label("Shuffle All Songs Next", systemImage: "music.note.list")
                    }
                    .disabled(audioPlayer.isExpandingToGlobalShuffle)
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 16, weight: .semibold))

                        if audioPlayer.isGlobalShuffleMode {
                            Circle()
                                .fill(StreamShelfTheme.Colors.accent)
                                .frame(width: 6, height: 6)
                                .offset(x: 1, y: -1)
                        }
                    }
                    .foregroundStyle(audioPlayer.isShuffleEnabled ? StreamShelfTheme.Colors.accent : StreamShelfTheme.Colors.secondaryText)
                    .frame(width: 32, height: 36)
                }
                .accessibilityLabel(audioPlayer.isGlobalShuffleMode ? "Global Shuffle Options" : "Shuffle Options")

                Button {
                    audioPlayer.togglePlayback()
                } label: {
                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(audioPlayer.isReady ? StreamShelfTheme.Colors.primaryText : StreamShelfTheme.Colors.tertiaryText)
                        .frame(width: 36, height: 36)
                }
                .disabled(!audioPlayer.isReady)
                .accessibilityLabel(audioPlayer.isPlaying ? "Pause" : "Play")

                Button {
                    audioPlayer.playNextTrack()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(audioPlayer.canPlayNext ? StreamShelfTheme.Colors.primaryText : StreamShelfTheme.Colors.tertiaryText)
                        .frame(width: 34, height: 36)
                }
                .disabled(!audioPlayer.canPlayNext)
                .accessibilityLabel("Next Track")

                Button {
                    audioPlayer.hideMiniPlayer()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
                        .frame(width: 28, height: 36)
                }
                .accessibilityLabel("Hide Mini Player")
            }
            .padding(.horizontal, StreamShelfTheme.Spacing.md)
            .padding(.vertical, StreamShelfTheme.Spacing.sm)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(StreamShelfTheme.Colors.separator)
            )
            .padding(.horizontal, StreamShelfTheme.Spacing.md)
            .padding(.bottom, StreamShelfTheme.Spacing.sm)
            .contentShape(Rectangle())
            .onTapGesture {
                audioPlayer.isFullPlayerPresented = true
            }
        }
    }
}
