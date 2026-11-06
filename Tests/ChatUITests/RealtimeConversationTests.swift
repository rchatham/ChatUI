//
//  RealtimeConversationTests.swift
//  ChatUI
//
//  Created by Reid Chatham on 11/6/26.
//

import Combine
import SwiftUI
import Testing
@testable import ChatUI

@MainActor
final class MockRealtimeHandler: RealtimeConversationHandler {
    @Published var connectionState: RealtimeConnectionState = .disconnected
    @Published var transcript: [RealtimeTranscriptEntry] = []
    @Published var isUserSpeaking = false
    @Published var isModelSpeaking = false
    @Published var audioLevel: Float = 0
    @Published var lastError: String?

    private(set) var sentTexts: [String] = []
    private(set) var interruptCount = 0

    func connect() async { connectionState = .connected }
    func disconnect() async { connectionState = .disconnected }
    func interrupt() async {
        interruptCount += 1
        isModelSpeaking = false
    }
    func sendText(_ text: String) async {
        sentTexts.append(text)
        transcript.append(RealtimeTranscriptEntry(id: UUID().uuidString, role: .user, text: text, isFinal: true))
    }
}

@MainActor
@Suite struct RealtimeConversationTests {
    @Test func transcriptEntriesCompareByContent() {
        var entry = RealtimeTranscriptEntry(id: "a", role: .assistant, text: "Hel", isFinal: false)
        let partial = entry
        entry.text += "lo"
        entry.isFinal = true

        #expect(entry != partial)
        #expect(entry == RealtimeTranscriptEntry(id: "a", role: .assistant, text: "Hello", isFinal: true))
    }

    @Test func handlerDrivesConversationLifecycle() async {
        let handler = MockRealtimeHandler()
        await handler.connect()
        #expect(handler.connectionState == .connected)

        await handler.sendText("hi there")
        #expect(handler.sentTexts == ["hi there"])
        #expect(handler.transcript.last?.role == .user)

        await handler.disconnect()
        #expect(handler.connectionState == .disconnected)
    }

    @Test func conversationViewBuildsForAnyHandler() {
        let handler = MockRealtimeHandler()
        handler.connectionState = .connected
        handler.transcript = [RealtimeTranscriptEntry(id: "1", role: .assistant, text: "Hi!", isFinal: true)]

        // Compiles only if the generic view accepts any conforming handler.
        _ = RealtimeConversationView(handler: handler, title: "Test")
        _ = AnyView(RealtimeConversationView(handler: handler))
    }
}
