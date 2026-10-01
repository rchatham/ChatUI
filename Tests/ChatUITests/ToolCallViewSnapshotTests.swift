//
//  ToolCallViewSnapshotTests.swift
//  ChatUITests
//
//  Renders ToolCallView in representative states to PNG files for visual review.
//

import Combine
import SwiftUI
import Testing
@testable import ChatUI

@MainActor
struct ToolCallViewSnapshotTests {

    private let outputDir = "/tmp/chatui-toolcall-screenshots"

    init() {
        try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
    }

    @Test func renderToolPending() async throws {
        let view = ToolCallView(toolCall: ChatToolCall(id: "t1", name: "calculate", kind: .tool, arguments: #"{"expression":"1+1"}"#, status: .pending))
        try render(view, name: "tool-pending", width: 420)
    }

    @Test func renderToolSuccess() async throws {
        let call = ChatToolCall(id: "t1", name: "calculate", kind: .tool, arguments: #"{"expression":"(2+3)*4"}"#, status: .success, result: "20")
        try render(ToolCallView(toolCall: call, isExpanded: true), name: "tool-success-expanded", width: 420)
        try render(ToolCallView(toolCall: call), name: "tool-success-collapsed", width: 420)
    }

    @Test func renderToolFailure() async throws {
        let call = ChatToolCall(id: "t1", name: "calculate", kind: .tool, arguments: #"{"expression":"1/0"}"#, status: .failure, result: "division by zero")
        try render(ToolCallView(toolCall: call, isExpanded: true), name: "tool-failure-expanded", width: 420)
    }

    @Test func renderAgentWithChildren() async throws {
        let agent = ChatToolCall(
            id: "a1", name: "CalendarAgent", kind: .agent, status: .success, details: "started: list today's events",
            children: [
                ChatToolCall(id: "c1", name: "list_events", kind: .tool, arguments: #"{"calendar":"primary"}"#, status: .success, result: "3 events"),
                ChatToolCall(id: "c2", name: "create_event", kind: .tool, arguments: #"{"title":"Lunch"}"#, status: .success, result: "created")
            ]
        )
        let view = ToolCallView(toolCall: agent, isExpanded: true)
        try render(view, name: "agent-with-children-expanded", width: 460)
    }

    @Test func renderAgentDelegation() async throws {
        let main = ChatToolCall(
            id: "m1", name: "Main", kind: .agent, status: .success, details: "started: plan the trip",
            children: [
                ChatToolCall(id: "d1", name: "Research", kind: .agent, status: .success, details: "delegated: find flights",
                              children: [
                                ChatToolCall(id: "t1", name: "search", kind: .tool, arguments: #"{"q":"flights"}"#, status: .success, result: "5 results")
                              ])
            ]
        )
        let view = ToolCallView(toolCall: main, isExpanded: true)
        try render(view, name: "agent-delegation-expanded", width: 480)
    }

    @Test func renderAgentPendingRunningChild() async throws {
        let agent = ChatToolCall(
            id: "a1", name: "CalendarAgent", kind: .agent, status: .pending, details: "started: list events",
            children: [
                ChatToolCall(id: "c1", name: "list_events", kind: .tool, arguments: #"{"calendar":"primary"}"#, status: .pending)
            ]
        )
        let view = ToolCallView(toolCall: agent, isExpanded: true)
        try render(view, name: "agent-pending-running-child-expanded", width: 460)
    }

    @Test func renderStoppedResponseNotice() throws {
        let message = SnapshotMessage(text: "Book the afternoon flight")
        message.wasResponseStopped = true
        let service = SnapshotMessageService(message: message)
        let view = MessageListRow(
            message: message,
            composerViewModel: MessageComposerView.ViewModel(messageService: service),
            supplementaryContent: { _ in nil }
        )
        try render(view, name: "stopped-response-notice", width: 460)
    }

    @Test func renderFailedMessageRetry() throws {
        let message = SnapshotMessage(text: "Book the afternoon flight")
        message.sendFailure = ChatSendFailure(message: "The connection was interrupted.")
        let service = SnapshotMessageService(message: message)
        let composerViewModel = MessageComposerView.ViewModel(messageService: service)
        let view = MessageListRow(
            message: message,
            composerViewModel: composerViewModel,
            supplementaryContent: { _ in nil }
        )

        try render(view, name: "failed-message-retry", width: 460)
    }

    @MainActor
    private func render<Content: View>(_ view: Content, name: String, width: CGFloat) throws {
        let host = view
            .frame(width: width, alignment: .leading)
            .padding(16)
            .background(Color.white)
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

private final class SnapshotMessageService: ChatMessageService, @unchecked Sendable {
    @Published private(set) var chatMessages: [SnapshotMessage]

    init(message: SnapshotMessage) {
        chatMessages = [message]
    }

    func send(message: String, stream: Bool) async throws {}
    func handleError(error: any Error) -> ChatAlertInfo? { nil }
    func deleteMessage(id: UUID) {}
}

private final class SnapshotMessage: ChatMessageInfo, @unchecked Sendable {
    let uuid = UUID()
    var id: UUID { uuid }
    let text: String?
    let childChatMessages: [SnapshotMessage] = []
    let isUser = true
    let isAssistant = false
    let isAgentEvent = false
    @Published var sendFailure: ChatSendFailure?
    @Published var wasResponseStopped = false

    init(text: String) {
        self.text = text
    }

    static func == (lhs: SnapshotMessage, rhs: SnapshotMessage) -> Bool {
        lhs.uuid == rhs.uuid
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }
}

#if canImport(AppKit)
import AppKit
#endif
