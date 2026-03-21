//
//  AudioControlsView.swift
//  ChatUI
//
//  Playback controls for audio messages
//

import SwiftUI

/// Playback controls for audio content
///
/// Provides standard media controls: play/pause, time display,
/// seek slider, and optional volume control.
///
/// Example usage:
/// ```swift
/// struct AudioPlayerView: View {
///     @State private var isPlaying = false
///     @State private var currentTime: TimeInterval = 0
///     @State private var volume: Float = 0.8
///
///     var body: some View {
///         AudioControlsView(
///             isPlaying: $isPlaying,
///             currentTime: currentTime,
///             duration: 120.0,
///             volume: $volume,
///             onPlayPause: { /* toggle playback */ },
///             onSeek: { time in /* seek to time */ }
///         )
///     }
/// }
/// ```
public struct AudioControlsView: View {
    /// Whether audio is currently playing
    @Binding public var isPlaying: Bool

    /// Current playback position in seconds
    public let currentTime: TimeInterval

    /// Total duration in seconds
    public let duration: TimeInterval

    /// Current volume (0.0 to 1.0), nil to hide volume control
    @Binding public var volume: Float?

    /// Callback when play/pause button is tapped
    public let onPlayPause: () -> Void

    /// Callback when user seeks to a new position
    public let onSeek: (TimeInterval) -> Void

    /// Whether to show the volume control
    public let showVolumeControl: Bool

    @State private var isSeeking = false
    @State private var seekPosition: Double = 0

    public init(
        isPlaying: Binding<Bool>,
        currentTime: TimeInterval,
        duration: TimeInterval,
        volume: Binding<Float?> = .constant(nil),
        showVolumeControl: Bool = false,
        onPlayPause: @escaping () -> Void,
        onSeek: @escaping (TimeInterval) -> Void
    ) {
        self._isPlaying = isPlaying
        self.currentTime = currentTime
        self.duration = duration
        self._volume = volume
        self.showVolumeControl = showVolumeControl
        self.onPlayPause = onPlayPause
        self.onSeek = onSeek
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Seek slider and time display
            HStack(spacing: 12) {
                Text(formatTime(isSeeking ? seekPosition : currentTime))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary)

                Slider(
                    value: isSeeking ? $seekPosition : Binding(
                        get: { currentTime },
                        set: { _ in }
                    ),
                    in: 0...max(duration, 0.1),
                    onEditingChanged: { editing in
                        isSeeking = editing
                        if !editing {
                            onSeek(seekPosition)
                        }
                    }
                )

                Text(formatTime(duration))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }

            // Play/pause and volume controls
            HStack(spacing: 16) {
                // Play/Pause button
                Button(action: onPlayPause) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)

                if showVolumeControl, volume != nil {
                    Divider()
                        .frame(height: 24)

                    // Volume control
                    HStack(spacing: 8) {
                        Image(systemName: volumeIcon)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)

                        Slider(
                            value: Binding(
                                get: { Double(volume ?? 1.0) },
                                set: { volume = Float($0) }
                            ),
                            in: 0...1
                        )
                        .frame(maxWidth: 100)
                    }
                }

                Spacer()
            }
        }
        .padding(.vertical, 8)
    }

    /// Format time interval as MM:SS
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Volume icon based on current volume level
    private var volumeIcon: String {
        guard let vol = volume else { return "speaker.fill" }
        if vol == 0 { return "speaker.slash.fill" }
        if vol < 0.33 { return "speaker.wave.1.fill" }
        if vol < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

#if DEBUG
struct AudioControlsView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            // Playing state
            AudioControlsView(
                isPlaying: .constant(true),
                currentTime: 45.5,
                duration: 180.0,
                volume: .constant(0.8),
                showVolumeControl: true,
                onPlayPause: {},
                onSeek: { _ in }
            )
            .padding()
            .background(Color.gray.opacity(0.1))

            // Paused state
            AudioControlsView(
                isPlaying: .constant(false),
                currentTime: 0,
                duration: 120.0,
                onPlayPause: {},
                onSeek: { _ in }
            )
            .padding()
            .background(Color.gray.opacity(0.1))

            // With volume control
            AudioControlsView(
                isPlaying: .constant(false),
                currentTime: 30,
                duration: 90.0,
                volume: .constant(0.5),
                showVolumeControl: true,
                onPlayPause: {},
                onSeek: { _ in }
            )
            .padding()
            .background(Color.gray.opacity(0.1))
        }
        .padding()
    }
}
#endif
