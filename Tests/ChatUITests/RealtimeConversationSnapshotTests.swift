//
//  RealtimeConversationSnapshotTests.swift
//  ChatUI
//
//  Created by Reid Chatham on 11/6/26.
//
//  Renders the live voice conversation UI in representative states to PNG
//  files for visual review (see .github/pr-assets/realtime-conversation).
//  Set CHATUI_SNAPSHOT_DIR to choose the output directory.
//

import Combine
import Foundation
import SwiftUI
import Testing
@testable import ChatUI
#if canImport(AppKit)
import AppKit
#endif

@MainActor
@Suite(.serialized)
struct RealtimeConversationSnapshotTests {

    private let outputDir = ProcessInfo.processInfo.environment["CHATUI_SNAPSHOT_DIR"]
        ?? "/tmp/chatui-realtime-screenshots"

    init() {
        try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
    }

    @Test func renderDisconnected() throws {
        let handler = MockRealtimeHandler()
        try render(RealtimeConversationView(handler: handler), name: "realtime-disconnected")
    }

    @Test func renderConnectedConversation() throws {
        let handler = MockRealtimeHandler()
        handler.connectionState = .connected
        handler.isModelSpeaking = true
        handler.audioLevel = 0.35
        handler.transcript = [
            RealtimeTranscriptEntry(id: "1", role: .user, text: "What's the weather like in Portland today?", isFinal: true),
            RealtimeTranscriptEntry(id: "2", role: .assistant, text: "It's 55 degrees and overcast in Portland, with light rain expected this", isFinal: false),
        ]
        try render(RealtimeConversationView(handler: handler), name: "realtime-connected-speaking")
    }

    @Test func renderUserSpeaking() throws {
        let handler = MockRealtimeHandler()
        handler.connectionState = .connected
        handler.isUserSpeaking = true
        handler.audioLevel = 0.8
        handler.transcript = [
            RealtimeTranscriptEntry(id: "1", role: .assistant, text: "Hi! What can I help you with?", isFinal: true),
            RealtimeTranscriptEntry(id: "2", role: .user, text: "Can you remind me to", isFinal: false),
        ]
        try render(RealtimeConversationView(handler: handler), name: "realtime-user-speaking")
    }

    @Test func renderError() throws {
        let handler = MockRealtimeHandler()
        handler.connectionState = .error
        handler.lastError = "No OpenAI API key configured. Add one in Settings."
        try render(RealtimeConversationView(handler: handler), name: "realtime-error")
    }

    @Test func renderComposerLiveVoiceButton() throws {
        let composer = MessageComposerView.ViewModel(messageService: RealtimeSnapshotMessageService())
        let view = MessageComposerView(viewModel: composer, onStartRealtime: {})
        try render(view, name: "composer-live-voice-button", height: 90)
    }

    private func render<Content: View>(_ view: Content, name: String, width: CGFloat = 390, height: CGFloat = 640) throws {
        let host = view
            .frame(width: width, height: height)
            .background(Color.white)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: host)
        renderer.scale = 2
        #if canImport(AppKit)
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            Issue.record("Failed to render \(name)")
            return
        }
        let url = URL(fileURLWithPath: "\(outputDir)/\(name).png")
        try png.write(to: url)
        print("📸 wrote \(url.path)")
        #else
        Issue.record("Screenshot rendering requires macOS/AppKit host")
        #endif
    }
}

private final class RealtimeSnapshotMessageService: ChatMessageService, @unchecked Sendable {
    @Published private(set) var chatMessages: [RealtimeSnapshotMessage] = []

    func send(message: String, stream: Bool) async throws {}
    func handleError(error: any Error) -> ChatAlertInfo? { nil }
    func deleteMessage(id: UUID) {}
}

private final class RealtimeSnapshotMessage: ChatMessageInfo, @unchecked Sendable {
    let uuid = UUID()
    var id: UUID { uuid }
    let text: String? = nil
    let childChatMessages: [RealtimeSnapshotMessage] = []
    let isUser = true
    let isAssistant = false
    let isAgentEvent = false

    static func == (lhs: RealtimeSnapshotMessage, rhs: RealtimeSnapshotMessage) -> Bool {
        lhs.uuid == rhs.uuid
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }
}
