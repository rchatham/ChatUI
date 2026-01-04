//
//  AudioMessageView.swift
//  ChatUI
//
//  Display audio messages with playback controls
//

import SwiftUI

/// Display and control audio message playback
///
/// Combines waveform visualization with playback controls for
/// a complete audio message UI. Integrates with any audio playback
/// backend that provides state updates.
///
/// Example usage:
/// ```swift
/// struct MessageView: View {
///     @StateObject private var audioPlayer = AudioPlayerManager()
///
///     var body: some View {
///         AudioMessageView(
///             isPlaying: $audioPlayer.isPlaying,
///             currentTime: audioPlayer.currentTime,
///             duration: audioPlayer.duration,
///             audioLevel: audioPlayer.level,
///             onPlayPause: { audioPlayer.togglePlayback() },
///             onSeek: { time in audioPlayer.seek(to: time) }
///         )
///     }
/// }
/// ```
public struct AudioMessageView: View {
    /// Whether audio is currently playing
    @Binding public var isPlaying: Bool

    /// Current playback position in seconds
    public let currentTime: TimeInterval

    /// Total duration in seconds
    public let duration: TimeInterval

    /// Current audio level for visualization (0.0 to 1.0)
    public let audioLevel: Float

    /// Optional volume control binding
    @Binding public var volume: Float?

    /// Callback when play/pause is tapped
    public let onPlayPause: () -> Void

    /// Callback when seeking to a new position
    public let onSeek: (TimeInterval) -> Void

    /// Whether to show volume control
    public let showVolumeControl: Bool

    /// Visual style for the message
    public let style: AudioMessageStyle

    public init(
        isPlaying: Binding<Bool>,
        currentTime: TimeInterval,
        duration: TimeInterval,
        audioLevel: Float = 0.0,
        volume: Binding<Float?> = .constant(nil),
        showVolumeControl: Bool = false,
        style: AudioMessageStyle = .default,
        onPlayPause: @escaping () -> Void,
        onSeek: @escaping (TimeInterval) -> Void
    ) {
        self._isPlaying = isPlaying
        self.currentTime = currentTime
        self.duration = duration
        self.audioLevel = audioLevel
        self._volume = volume
        self.showVolumeControl = showVolumeControl
        self.style = style
        self.onPlayPause = onPlayPause
        self.onSeek = onSeek
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Waveform visualization
            if isPlaying || audioLevel > 0 {
                AudioVisualizerView(
                    audioLevel: isPlaying ? audioLevel : 0,
                    barCount: style.barCount,
                    barColor: style.waveformColor,
                    maxBarHeight: style.waveformHeight
                )
                .frame(height: style.waveformHeight)
            } else {
                // Static waveform when not playing
                AudioVisualizerView(
                    audioLevel: 0.3,
                    barCount: style.barCount,
                    barColor: style.waveformColor.opacity(0.3),
                    maxBarHeight: style.waveformHeight
                )
                .frame(height: style.waveformHeight)
            }

            // Playback controls
            AudioControlsView(
                isPlaying: $isPlaying,
                currentTime: currentTime,
                duration: duration,
                volume: $volume,
                showVolumeControl: showVolumeControl,
                onPlayPause: onPlayPause,
                onSeek: onSeek
            )
        }
        .padding(style.padding)
        .background(style.backgroundColor)
        .cornerRadius(style.cornerRadius)
    }
}

/// Visual styling options for AudioMessageView
public struct AudioMessageStyle: Sendable {
    public let waveformColor: Color
    public let waveformHeight: CGFloat
    public let barCount: Int
    public let backgroundColor: Color
    public let cornerRadius: CGFloat
    public let padding: EdgeInsets

    public init(
        waveformColor: Color = .blue,
        waveformHeight: CGFloat = 50,
        barCount: Int = 30,
        backgroundColor: Color = Color.gray.opacity(0.1),
        cornerRadius: CGFloat = 12,
        padding: EdgeInsets = EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
    ) {
        self.waveformColor = waveformColor
        self.waveformHeight = waveformHeight
        self.barCount = barCount
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.padding = padding
    }

    public static let `default` = AudioMessageStyle()

    public static let compact = AudioMessageStyle(
        waveformHeight: 30,
        barCount: 20,
        padding: EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
    )

    public static let minimal = AudioMessageStyle(
        waveformHeight: 40,
        barCount: 25,
        backgroundColor: .clear,
        cornerRadius: 0,
        padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
    )
}

#if DEBUG
struct AudioMessageView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Not playing
            AudioMessageView(
                isPlaying: .constant(false),
                currentTime: 0,
                duration: 120.0,
                audioLevel: 0,
                onPlayPause: {},
                onSeek: { _ in }
            )

            // Playing with audio
            AudioMessageView(
                isPlaying: .constant(true),
                currentTime: 45.5,
                duration: 120.0,
                audioLevel: 0.7,
                style: .default,
                onPlayPause: {},
                onSeek: { _ in }
            )

            // Compact style
            AudioMessageView(
                isPlaying: .constant(false),
                currentTime: 30,
                duration: 90.0,
                audioLevel: 0,
                style: .compact,
                onPlayPause: {},
                onSeek: { _ in }
            )

            // With volume control
            AudioMessageView(
                isPlaying: .constant(true),
                currentTime: 15,
                duration: 60.0,
                audioLevel: 0.5,
                volume: .constant(0.8),
                showVolumeControl: true,
                onPlayPause: {},
                onSeek: { _ in }
            )
        }
        .padding()
    }
}
#endif
