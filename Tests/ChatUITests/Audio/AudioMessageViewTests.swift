//
//  AudioMessageViewTests.swift
//  ChatUI
//
//  Tests for AudioMessageView component
//

import XCTest
import SwiftUI
@testable import ChatUI

@MainActor
final class AudioMessageViewTests: XCTestCase {

    // MARK: - AudioMessageStyle Tests

    func testDefaultStyle() {
        let style = AudioMessageStyle.default

        XCTAssertEqual(style.waveformColor, .blue)
        XCTAssertEqual(style.waveformHeight, 50)
        XCTAssertEqual(style.barCount, 30)
        XCTAssertEqual(style.backgroundColor, Color.gray.opacity(0.1))
        XCTAssertEqual(style.cornerRadius, 12)
        XCTAssertEqual(style.padding, EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
    }

    func testCompactStyle() {
        let style = AudioMessageStyle.compact

        XCTAssertEqual(style.waveformHeight, 30)
        XCTAssertEqual(style.barCount, 20)
        XCTAssertEqual(style.padding, EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
    }

    func testMinimalStyle() {
        let style = AudioMessageStyle.minimal

        XCTAssertEqual(style.waveformHeight, 40)
        XCTAssertEqual(style.barCount, 25)
        XCTAssertEqual(style.backgroundColor, .clear)
        XCTAssertEqual(style.cornerRadius, 0)
        XCTAssertEqual(style.padding, EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }

    func testCustomStyle() {
        let style = AudioMessageStyle(
            waveformColor: .red,
            waveformHeight: 60,
            barCount: 35,
            backgroundColor: .yellow,
            cornerRadius: 8,
            padding: EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        )

        XCTAssertEqual(style.waveformColor, .red)
        XCTAssertEqual(style.waveformHeight, 60)
        XCTAssertEqual(style.barCount, 35)
        XCTAssertEqual(style.backgroundColor, .yellow)
        XCTAssertEqual(style.cornerRadius, 8)
        XCTAssertEqual(style.padding, EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
    }

    func testStyleIsSendable() {
        // Test that AudioMessageStyle conforms to Sendable
        let style = AudioMessageStyle.default

        Task {
            // Should compile without warnings - style is Sendable
            let _ = style
        }
    }

    // MARK: - AudioMessageView Initialization Tests

    func testViewInitialization() {
        @State var isPlaying = false
        @State var volume: Float? = 0.8

        let view = AudioMessageView(
            isPlaying: $isPlaying,
            currentTime: 30.0,
            duration: 120.0,
            audioLevel: 0.5,
            volume: $volume,
            showVolumeControl: true,
            style: .default,
            onPlayPause: {},
            onSeek: { _ in }
        )

        XCTAssertEqual(view.currentTime, 30.0)
        XCTAssertEqual(view.duration, 120.0)
        XCTAssertEqual(view.audioLevel, 0.5)
        XCTAssertTrue(view.showVolumeControl)
        XCTAssertEqual(view.style.barCount, 30)
    }

    func testViewWithMinimalParameters() {
        @State var isPlaying = false

        let view = AudioMessageView(
            isPlaying: $isPlaying,
            currentTime: 0,
            duration: 60.0,
            onPlayPause: {},
            onSeek: { _ in }
        )

        XCTAssertEqual(view.currentTime, 0)
        XCTAssertEqual(view.duration, 60.0)
        XCTAssertEqual(view.audioLevel, 0.0)
        XCTAssertFalse(view.showVolumeControl)
    }

    // MARK: - Time Tests

    func testZeroDuration() {
        @State var isPlaying = false

        let view = AudioMessageView(
            isPlaying: $isPlaying,
            currentTime: 0,
            duration: 0,
            onPlayPause: {},
            onSeek: { _ in }
        )

        XCTAssertEqual(view.duration, 0)
    }

    func testLongDuration() {
        @State var isPlaying = false

        let view = AudioMessageView(
            isPlaying: $isPlaying,
            currentTime: 300,
            duration: 3600, // 1 hour
            onPlayPause: {},
            onSeek: { _ in }
        )

        XCTAssertEqual(view.duration, 3600)
        XCTAssertEqual(view.currentTime, 300)
    }

    // MARK: - Audio Level Tests

    func testAudioLevelRange() {
        @State var isPlaying = true

        let levels: [Float] = [0.0, 0.25, 0.5, 0.75, 1.0]

        for level in levels {
            let view = AudioMessageView(
                isPlaying: $isPlaying,
                currentTime: 0,
                duration: 60,
                audioLevel: level,
                onPlayPause: {},
                onSeek: { _ in }
            )
            XCTAssertEqual(view.audioLevel, level)
        }
    }

    // MARK: - Callback Tests

    func testPlayPauseCallback() {
        @State var isPlaying = false
        var callbackCalled = false

        let _ = AudioMessageView(
            isPlaying: $isPlaying,
            currentTime: 0,
            duration: 60,
            onPlayPause: {
                callbackCalled = true
            },
            onSeek: { _ in }
        )

        // Callbacks are stored but not called during initialization
        XCTAssertFalse(callbackCalled)
    }

    func testSeekCallback() {
        @State var isPlaying = false
        var seekTime: TimeInterval?

        let _ = AudioMessageView(
            isPlaying: $isPlaying,
            currentTime: 0,
            duration: 60,
            onPlayPause: {},
            onSeek: { time in
                seekTime = time
            }
        )

        // Callback not called during initialization
        XCTAssertNil(seekTime)
    }

    // MARK: - Volume Control Tests

    func testVolumeControlHidden() {
        @State var isPlaying = false

        let view = AudioMessageView(
            isPlaying: $isPlaying,
            currentTime: 0,
            duration: 60,
            showVolumeControl: false,
            onPlayPause: {},
            onSeek: { _ in }
        )

        XCTAssertFalse(view.showVolumeControl)
    }

    func testVolumeControlVisible() {
        @State var isPlaying = false
        @State var volume: Float? = 0.5

        let view = AudioMessageView(
            isPlaying: $isPlaying,
            currentTime: 0,
            duration: 60,
            volume: $volume,
            showVolumeControl: true,
            onPlayPause: {},
            onSeek: { _ in }
        )

        XCTAssertTrue(view.showVolumeControl)
    }

    // MARK: - Style Application Tests

    func testDifferentStyles() {
        @State var isPlaying = false

        let styles: [AudioMessageStyle] = [.default, .compact, .minimal]

        for style in styles {
            let view = AudioMessageView(
                isPlaying: $isPlaying,
                currentTime: 0,
                duration: 60,
                style: style,
                onPlayPause: {},
                onSeek: { _ in }
            )
            XCTAssertEqual(view.style.barCount, style.barCount)
            XCTAssertEqual(view.style.waveformHeight, style.waveformHeight)
        }
    }

    // MARK: - View Body Tests

    func testViewCreation() {
        @State var isPlaying = false

        let view = AudioMessageView(
            isPlaying: $isPlaying,
            currentTime: 0,
            duration: 60,
            onPlayPause: {},
            onSeek: { _ in }
        )

        let body = view.body
        XCTAssertNotNil(body)
    }
}
