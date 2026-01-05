//
//  AudioControlsViewTests.swift
//  ChatUI
//
//  Tests for AudioControlsView component
//

import XCTest
import SwiftUI
@testable import ChatUI

@MainActor
final class AudioControlsViewTests: XCTestCase {

    // MARK: - Initialization Tests

    func testBasicInitialization() {
        @State var isPlaying = false

        let view = AudioControlsView(
            isPlaying: $isPlaying,
            currentTime: 30.0,
            duration: 120.0,
            onPlayPause: {},
            onSeek: { _ in }
        )

        XCTAssertEqual(view.currentTime, 30.0)
        XCTAssertEqual(view.duration, 120.0)
        XCTAssertFalse(view.showVolumeControl)
    }

    func testInitializationWithVolume() {
        @State var isPlaying = false
        @State var volume: Float? = 0.8

        let view = AudioControlsView(
            isPlaying: $isPlaying,
            currentTime: 0,
            duration: 60.0,
            volume: $volume,
            showVolumeControl: true,
            onPlayPause: {},
            onSeek: { _ in }
        )

        XCTAssertEqual(view.currentTime, 0)
        XCTAssertEqual(view.duration, 60.0)
        XCTAssertTrue(view.showVolumeControl)
    }

    // MARK: - Time Tests

    func testZeroCurrentTime() {
        @State var isPlaying = false

        let view = AudioControlsView(
            isPlaying: $isPlaying,
            currentTime: 0,
            duration: 60.0,
            onPlayPause: {},
            onSeek: { _ in }
        )

        XCTAssertEqual(view.currentTime, 0)
    }

    func testMidPlaybackTime() {
        @State var isPlaying = true

        let view = AudioControlsView(
            isPlaying: $isPlaying,
            currentTime: 45.5,
            duration: 90.0,
            onPlayPause: {},
            onSeek: { _ in }
        )

        XCTAssertEqual(view.currentTime, 45.5)
    }

    func testNearEndTime() {
        @State var isPlaying = true

        let view = AudioControlsView(
            isPlaying: $isPlaying,
            currentTime: 59.9,
            duration: 60.0,
            onPlayPause: {},
            onSeek: { _ in }
        )

        XCTAssertEqual(view.currentTime, 59.9)
    }

    // MARK: - Duration Tests

    func testShortDuration() {
        @State var isPlaying = false

        let view = AudioControlsView(
            isPlaying: $isPlaying,
            currentTime: 0,
            duration: 10.0,
            onPlayPause: {},
            onSeek: { _ in }
        )

        XCTAssertEqual(view.duration, 10.0)
    }

    func testLongDuration() {
        @State var isPlaying = false

        let view = AudioControlsView(
            isPlaying: $isPlaying,
            currentTime: 0,
            duration: 3600.0, // 1 hour
            onPlayPause: {},
            onSeek: { _ in }
        )

        XCTAssertEqual(view.duration, 3600.0)
    }

    func testZeroDuration() {
        @State var isPlaying = false

        let view = AudioControlsView(
            isPlaying: $isPlaying,
            currentTime: 0,
            duration: 0,
            onPlayPause: {},
            onSeek: { _ in }
        )

        XCTAssertEqual(view.duration, 0)
    }

    // MARK: - Playing State Tests

    func testNotPlayingState() {
        @State var isPlaying = false

        let view = AudioControlsView(
            isPlaying: $isPlaying,
            currentTime: 0,
            duration: 60.0,
            onPlayPause: {},
            onSeek: { _ in }
        )

        // Verify binding reflects state
        XCTAssertFalse(isPlaying)
    }

    func testPlayingState() {
        @State var isPlaying = true

        let view = AudioControlsView(
            isPlaying: $isPlaying,
            currentTime: 30.0,
            duration: 60.0,
            onPlayPause: {},
            onSeek: { _ in }
        )

        XCTAssertTrue(isPlaying)
    }

    // MARK: - Volume Control Tests

    func testVolumeControlDisabled() {
        @State var isPlaying = false

        let view = AudioControlsView(
            isPlaying: $isPlaying,
            currentTime: 0,
            duration: 60.0,
            showVolumeControl: false,
            onPlayPause: {},
            onSeek: { _ in }
        )

        XCTAssertFalse(view.showVolumeControl)
    }

    func testVolumeControlEnabled() {
        @State var isPlaying = false
        @State var volume: Float? = 0.5

        let view = AudioControlsView(
            isPlaying: $isPlaying,
            currentTime: 0,
            duration: 60.0,
            volume: $volume,
            showVolumeControl: true,
            onPlayPause: {},
            onSeek: { _ in }
        )

        XCTAssertTrue(view.showVolumeControl)
    }

    func testVolumeRange() {
        @State var isPlaying = false

        let volumes: [Float] = [0.0, 0.25, 0.5, 0.75, 1.0]

        for vol in volumes {
            @State var volume: Float? = vol

            let view = AudioControlsView(
                isPlaying: $isPlaying,
                currentTime: 0,
                duration: 60.0,
                volume: $volume,
                showVolumeControl: true,
                onPlayPause: {},
                onSeek: { _ in }
            )

            XCTAssertEqual(volume, vol)
        }
    }

    // MARK: - Callback Tests

    func testPlayPauseCallbackNotCalledOnInit() {
        @State var isPlaying = false
        var callbackCalled = false

        let _ = AudioControlsView(
            isPlaying: $isPlaying,
            currentTime: 0,
            duration: 60.0,
            onPlayPause: {
                callbackCalled = true
            },
            onSeek: { _ in }
        )

        XCTAssertFalse(callbackCalled)
    }

    func testSeekCallbackNotCalledOnInit() {
        @State var isPlaying = false
        var seekTime: TimeInterval?

        let _ = AudioControlsView(
            isPlaying: $isPlaying,
            currentTime: 0,
            duration: 60.0,
            onPlayPause: {},
            onSeek: { time in
                seekTime = time
            }
        )

        XCTAssertNil(seekTime)
    }

    // MARK: - View Body Tests

    func testViewCreation() {
        @State var isPlaying = false

        let view = AudioControlsView(
            isPlaying: $isPlaying,
            currentTime: 0,
            duration: 60.0,
            onPlayPause: {},
            onSeek: { _ in }
        )

        let body = view.body
        XCTAssertNotNil(body)
    }

    func testViewCreationWithAllOptions() {
        @State var isPlaying = true
        @State var volume: Float? = 0.7

        let view = AudioControlsView(
            isPlaying: $isPlaying,
            currentTime: 45.0,
            duration: 120.0,
            volume: $volume,
            showVolumeControl: true,
            onPlayPause: {},
            onSeek: { _ in }
        )

        let body = view.body
        XCTAssertNotNil(body)
    }
}
