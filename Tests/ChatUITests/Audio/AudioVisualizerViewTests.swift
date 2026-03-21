//
//  AudioVisualizerViewTests.swift
//  ChatUI
//
//  Tests for AudioVisualizerView component
//

import XCTest
import SwiftUI
@testable import ChatUI

@MainActor
final class AudioVisualizerViewTests: XCTestCase {

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        let view = AudioVisualizerView(audioLevel: 0.5)

        XCTAssertEqual(view.audioLevel, 0.5)
        XCTAssertEqual(view.barCount, 25)
        XCTAssertEqual(view.barColor, .blue)
        XCTAssertEqual(view.barSpacing, 2)
        XCTAssertEqual(view.minBarHeight, 4)
        XCTAssertEqual(view.maxBarHeight, 40)
    }

    func testCustomInitialization() {
        let view = AudioVisualizerView(
            audioLevel: 0.8,
            barCount: 30,
            barColor: .red,
            barSpacing: 3,
            minBarHeight: 5,
            maxBarHeight: 50
        )

        XCTAssertEqual(view.audioLevel, 0.8)
        XCTAssertEqual(view.barCount, 30)
        XCTAssertEqual(view.barColor, .red)
        XCTAssertEqual(view.barSpacing, 3)
        XCTAssertEqual(view.minBarHeight, 5)
        XCTAssertEqual(view.maxBarHeight, 50)
    }

    // MARK: - Audio Level Tests

    func testAudioLevelRange() {
        let levels: [Float] = [0.0, 0.25, 0.5, 0.75, 1.0]

        for level in levels {
            let view = AudioVisualizerView(audioLevel: level)
            XCTAssertEqual(view.audioLevel, level)
        }
    }

    func testSilentAudioLevel() {
        let view = AudioVisualizerView(audioLevel: 0.0)
        XCTAssertEqual(view.audioLevel, 0.0)
    }

    func testMaxAudioLevel() {
        let view = AudioVisualizerView(audioLevel: 1.0)
        XCTAssertEqual(view.audioLevel, 1.0)
    }

    // MARK: - Bar Configuration Tests

    func testMinimumBarCount() {
        let view = AudioVisualizerView(audioLevel: 0.5, barCount: 1)
        XCTAssertEqual(view.barCount, 1)
    }

    func testLargeBarCount() {
        let view = AudioVisualizerView(audioLevel: 0.5, barCount: 100)
        XCTAssertEqual(view.barCount, 100)
    }

    func testBarSpacingValues() {
        let spacings: [CGFloat] = [0, 1, 2, 5, 10]

        for spacing in spacings {
            let view = AudioVisualizerView(audioLevel: 0.5, barSpacing: spacing)
            XCTAssertEqual(view.barSpacing, spacing)
        }
    }

    // MARK: - Color Tests

    func testDifferentBarColors() {
        let colors: [Color] = [.red, .green, .blue, .orange, .purple]

        for color in colors {
            let view = AudioVisualizerView(audioLevel: 0.5, barColor: color)
            XCTAssertEqual(view.barColor, color)
        }
    }

    // MARK: - Height Configuration Tests

    func testMinimumBarHeight() {
        let view = AudioVisualizerView(audioLevel: 0.5, minBarHeight: 2)
        XCTAssertEqual(view.minBarHeight, 2)
    }

    func testMaximumBarHeight() {
        let view = AudioVisualizerView(audioLevel: 0.5, maxBarHeight: 100)
        XCTAssertEqual(view.maxBarHeight, 100)
    }

    func testMinMaxHeightRelationship() {
        let minHeight: CGFloat = 4
        let maxHeight: CGFloat = 40

        let view = AudioVisualizerView(
            audioLevel: 0.5,
            minBarHeight: minHeight,
            maxBarHeight: maxHeight
        )

        XCTAssertLessThan(view.minBarHeight, view.maxBarHeight)
    }

    // MARK: - View Body Tests

    func testViewCreation() {
        let view = AudioVisualizerView(audioLevel: 0.5)
        let body = view.body

        // Verify body is not nil (basic SwiftUI view test)
        XCTAssertNotNil(body)
    }
}
