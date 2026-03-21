//
//  AudioVisualizerView.swift
//  ChatUI
//
//  Waveform visualization for audio recording and playback
//

import SwiftUI

/// Visual representation of audio levels using animated bars
///
/// Displays audio amplitude as a series of vertical bars that animate
/// in real-time. Useful for voice recording UI and audio playback visualization.
///
/// Example usage:
/// ```swift
/// struct RecordingView: View {
///     @State private var audioLevel: Float = 0.0
///
///     var body: some View {
///         AudioVisualizerView(
///             audioLevel: audioLevel,
///             barCount: 30,
///             barColor: .blue
///         )
///         .frame(height: 60)
///     }
/// }
/// ```
public struct AudioVisualizerView: View {
    /// Current audio level (0.0 to 1.0)
    public let audioLevel: Float

    /// Number of bars to display
    public let barCount: Int

    /// Color of the visualizer bars
    public let barColor: Color

    /// Spacing between bars
    public let barSpacing: CGFloat

    /// Minimum bar height when silent
    public let minBarHeight: CGFloat

    /// Maximum bar height at full volume
    public let maxBarHeight: CGFloat

    public init(
        audioLevel: Float,
        barCount: Int = 25,
        barColor: Color = .blue,
        barSpacing: CGFloat = 2,
        minBarHeight: CGFloat = 4,
        maxBarHeight: CGFloat = 40
    ) {
        self.audioLevel = audioLevel
        self.barCount = barCount
        self.barColor = barColor
        self.barSpacing = barSpacing
        self.minBarHeight = minBarHeight
        self.maxBarHeight = maxBarHeight
    }

    public var body: some View {
        GeometryReader { geometry in
            HStack(spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor)
                        .frame(
                            width: (geometry.size.width - CGFloat(barCount - 1) * barSpacing) / CGFloat(barCount),
                            height: barHeight(for: index, in: geometry.size)
                        )
                        .animation(.easeInOut(duration: 0.1), value: audioLevel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    /// Calculate bar height based on audio level and bar index
    /// Creates a wave pattern that responds to audio amplitude
    private func barHeight(for index: Int, in size: CGSize) -> CGFloat {
        let normalizedLevel = CGFloat(max(0, min(1, audioLevel)))

        // Create a wave pattern across bars
        let centerIndex = CGFloat(barCount) / 2
        let distanceFromCenter = abs(CGFloat(index) - centerIndex)
        let normalizedDistance = distanceFromCenter / centerIndex

        // Calculate height with wave effect
        let waveMultiplier = 1.0 - (normalizedDistance * 0.5)
        let height = minBarHeight + (maxBarHeight - minBarHeight) * normalizedLevel * waveMultiplier

        return min(height, size.height)
    }
}

#if DEBUG
struct AudioVisualizerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Silent")
            AudioVisualizerView(audioLevel: 0.0)
                .frame(height: 60)

            Text("Low Volume")
            AudioVisualizerView(audioLevel: 0.3)
                .frame(height: 60)

            Text("Medium Volume")
            AudioVisualizerView(audioLevel: 0.6, barColor: .green)
                .frame(height: 60)

            Text("High Volume")
            AudioVisualizerView(audioLevel: 0.9, barColor: .red)
                .frame(height: 60)
        }
        .padding()
    }
}
#endif
