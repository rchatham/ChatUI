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
            id: "m1", name: "Main", kind: .agent, status: .success, result: "Trip plan complete", details: "started: plan the trip",
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

    @Test func renderPendingNestedDelegationCollapsed() async throws {
        let agent = ChatToolCall(
            id: "a1",
            name: "Main",
            kind: .agent,
            status: .pending,
            details: "started: research the request",
            children: [
                ChatToolCall(
                    id: "d1",
                    name: "Research",
                    kind: .agent,
                    status: .pending,
                    details: "delegated: find current sources"
                )
            ]
        )
        try render(
            ToolCallView(toolCall: agent, isExpanded: false),
            name: "pending-nested-delegation-collapsed",
            width: 460
        )
    }

    @Test func renderToolOnlyAndNormalAssistantMessages() async throws {
        let toolOnly = SnapshotMessage(
            uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
            toolCalls: [
                ChatToolCall(
                    id: "search",
                    name: "Search",
                    status: .pending,
                    details: "Searching synthetic sources"
                )
            ],
            isUser: false
        )
        let normalAssistant = SnapshotMessage(
            uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
            text: "Synthetic assistant response",
            isUser: false
        )
        let view = VStack(alignment: .leading, spacing: 12) {
            CollapsibleMessageView(message: toolOnly, parentIsExpanded: .constant(false))
            CollapsibleMessageView(message: normalAssistant, parentIsExpanded: .constant(false))
        }
        try render(view, name: "tool-only-and-normal-assistant-messages", width: 460)
    }

    @Test func renderAgentPendingNestedDelegation() async throws {
        let agent = ChatToolCall(
            id: "a1", name: "Main", kind: .agent, status: .pending, details: "started: research the request",
            children: [
                ChatToolCall(
                    id: "d1",
                    name: "Research",
                    kind: .agent,
                    status: .pending,
                    details: "delegated: find current sources",
                    children: [
                        ChatToolCall(
                            id: "c1",
                            name: "search",
                            kind: .tool,
                            arguments: #"{"query":"current sources"}"#,
                            status: .pending
                        )
                    ]
                )
            ]
        )
        let view = ToolCallView(toolCall: agent, isExpanded: true)
        try render(view, name: "agent-pending-nested-delegation-expanded", width: 460)
    }

    @Test func renderStoppedResponseNotice() throws {
        let prompt = SnapshotMessage(text: "Book the afternoon flight")
        prompt.wasResponseStopped = true
        let partialResponse = SnapshotMessage(text: "The afternoon flight departs at", isUser: false)
        let messages = [prompt, partialResponse]
        let service = SnapshotMessageService(messages: messages)
        let composer = MessageComposerView.ViewModel(messageService: service)
        let sources = MessageListView<SnapshotMessageService>.stoppedNoticeSources(in: messages)
        #expect(sources[prompt.uuid] == nil)
        #expect(sources[partialResponse.uuid] === prompt)

        let view = VStack(alignment: .leading) {
            MessageListRow(message: prompt, composerViewModel: composer, supplementaryContent: { _ in nil })
            MessageListRow(
                message: partialResponse,
                composerViewModel: composer,
                supplementaryContent: { _ in nil },
                stoppedSource: sources[partialResponse.uuid]
            )
        }
        try render(view, name: "stopped-response-notice", width: 460)
    }

    @Test func stoppedNoticeMovesWhenExistingAssistantGainsText() {
        let prompt = SnapshotMessage(text: "prompt")
        let assistant = SnapshotMessage(text: nil, isUser: false, responseToMessageID: prompt.uuid)
        let list = MessageListView<SnapshotMessageService>.self
        let messages = [prompt, assistant]
        #expect(list.stoppedNoticeSources(in: messages)[prompt.uuid] === prompt)

        var emittedChange = false
        let subscription = assistant.objectWillChange.sink { emittedChange = true }
        assistant.text = "partial response"
        #expect(emittedChange)
        #expect(list.stoppedNoticeSources(in: messages)[assistant.uuid] === prompt)
        withExtendedLifetime(subscription) {}
    }

    @Test func stoppedNoticeFallsBackToPromptWithoutTextAndIgnoresLaterToolRows() {
        let prompt = SnapshotMessage(text: "first")
        let toolOnly = SnapshotMessage(text: nil, isUser: false)
        let agentEvent = SnapshotMessage(text: "Tool finished", isUser: false, isAssistant: false)
        let list = MessageListView<SnapshotMessageService>.self
        let noResponse = list.stoppedNoticeSources(in: [prompt, toolOnly, agentEvent])
        #expect(noResponse[prompt.uuid] === prompt)
        #expect(noResponse[toolOnly.uuid] == nil)
        #expect(noResponse[agentEvent.uuid] == nil)

        let partial = SnapshotMessage(text: "partial", isUser: false)
        let withResponse = list.stoppedNoticeSources(in: [prompt, partial, agentEvent])
        #expect(withResponse[partial.uuid] === prompt)
        #expect(withResponse[agentEvent.uuid] == nil)
    }

    @Test func stoppedNoticeFollowsOwnedResponseAcrossInterleavedSends() {
        let first = SnapshotMessage(text: "first")
        let second = SnapshotMessage(text: "second")
        let firstResponse = SnapshotMessage(text: "first partial", isUser: false, responseToMessageID: first.uuid)
        let secondResponse = SnapshotMessage(text: "second partial", isUser: false, responseToMessageID: second.uuid)
        let sources = MessageListView<SnapshotMessageService>.stoppedNoticeSources(
            in: [first, second, firstResponse, secondResponse]
        )
        #expect(sources[firstResponse.uuid] === first)
        #expect(sources[secondResponse.uuid] === second)
        #expect(sources[first.uuid] == nil)
    }

    @Test func stoppedNoticeStaysWithItsTurnWhenAnotherUserSends() {
        let stoppedPrompt = SnapshotMessage(text: "first")
        stoppedPrompt.wasResponseStopped = true
        let partialResponse = SnapshotMessage(text: "partial", isUser: false)
        let nextPrompt = SnapshotMessage(text: "second")
        let nextResponse = SnapshotMessage(text: "answer", isUser: false)
        let list = MessageListView<SnapshotMessageService>.self
        let messages = [stoppedPrompt, partialResponse, nextPrompt, nextResponse]
        let sources = list.stoppedNoticeSources(in: messages)

        #expect(sources[stoppedPrompt.uuid] == nil)
        #expect(sources[partialResponse.uuid] === stoppedPrompt)
        #expect(sources[nextPrompt.uuid] == nil)
        #expect(sources[nextResponse.uuid] === nextPrompt)
        #expect(list.stoppedNoticeSources(in: [stoppedPrompt])[stoppedPrompt.uuid] === stoppedPrompt)
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

    init(messages: [SnapshotMessage]) {
        chatMessages = messages
    }

    func send(message: String, stream: Bool) async throws {}
    func handleError(error: any Error) -> ChatAlertInfo? { nil }
    func deleteMessage(id: UUID) {}
}

private final class SnapshotMessage: ChatMessageInfo, @unchecked Sendable {
    let uuid: UUID
    var id: UUID { uuid }
    @Published var text: String?
    let toolCalls: [ChatToolCall]
    let childChatMessages: [SnapshotMessage]
    let isUser: Bool
    let isAssistant: Bool
    var isAgentEvent: Bool { !isUser && !isAssistant }
    let responseToMessageID: UUID?
    @Published var sendFailure: ChatSendFailure?
    @Published var wasResponseStopped = false

    init(
        uuid: UUID = UUID(),
        text: String? = nil,
        toolCalls: [ChatToolCall] = [],
        children: [SnapshotMessage] = [],
        isUser: Bool = true,
        isAssistant: Bool? = nil,
        responseToMessageID: UUID? = nil
    ) {
        self.uuid = uuid
        self.text = text
        self.toolCalls = toolCalls
        self.childChatMessages = children
        self.isUser = isUser
        self.isAssistant = isAssistant ?? !isUser
        self.responseToMessageID = responseToMessageID
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
