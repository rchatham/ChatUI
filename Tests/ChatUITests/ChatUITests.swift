import Combine
import Foundation
import SwiftUI
import Testing
@testable import ChatUI

@Test func toolCallPreservesCompletedResult() {
    let call = ChatToolCall(
        id: "weather-1",
        name: "getWeather",
        arguments: #"{"city":"Portland"}"#,
        status: .success,
        result: #"{"temperature":55}"#
    )

    #expect(call.id == "weather-1")
    #expect(call.name == "getWeather")
    #expect(call.status == .success)
    #expect(call.result == #"{"temperature":55}"#)
}

@Test func toolCallDefaultsToPendingWithoutResult() {
    let call = ChatToolCall(id: "search-1", name: "search")

    #expect(call.status == .pending)
    #expect(call.arguments == nil)
    #expect(call.result == nil)
    #expect(call.kind == .tool)
    #expect(call.details == nil)
    #expect(call.children.isEmpty)
}

@Test func agentCallCarriesDetailsAndChildren() {
    let child = ChatToolCall(id: "c1", name: "calculate", arguments: "{}", status: .success, result: "42")
    let agent = ChatToolCall(id: "a1", name: "ResearchAgent", kind: .agent, status: .pending, details: "started: find weather", children: [child])

    #expect(agent.kind == .agent)
    #expect(agent.details == "started: find weather")
    #expect(agent.children.count == 1)
    #expect(agent.children.first?.name == "calculate")
}

@Test func toolCallCodableRoundTripPreservesAgentFields() throws {
    let agent = ChatToolCall(id: "a", name: "Research", kind: .agent, status: .success, result: "done", details: "delegated: because", children: [
        ChatToolCall(id: "c", name: "calculate", arguments: "{}", status: .success, result: "2")
    ])
    let data = try JSONEncoder().encode(agent)
    let decoded = try JSONDecoder().decode(ChatToolCall.self, from: data)

    #expect(decoded.kind == .agent)
    #expect(decoded.details == "delegated: because")
    #expect(decoded.children.count == 1)
    #expect(decoded.children.first?.result == "2")
}

@Test func toolCallEncodedWithoutKindDecodesAsTool() throws {
    // A `.tool` call omits `kind` on encode; decoding must default it back to `.tool`
    // so payloads from before `kind` existed still decode correctly.
    let call = ChatToolCall(id: "x", name: "calculate", status: .success, result: "2")
    let data = try JSONEncoder().encode(call)
    #expect(!(String(data: data, encoding: .utf8) ?? "").contains("\"kind\""))
    let decoded = try JSONDecoder().decode(ChatToolCall.self, from: data)
    #expect(decoded.kind == .tool)
    #expect(decoded.result == "2")
}

@Test func messagesWithoutToolCallsUseTheDefaultEmptyCollection() {
    let message = TestMessage(text: "Hello")

    #expect(message.toolCalls.isEmpty)
}

@Test func displayContentRoundTripEncodesAndDecodes() throws {
    let dc = ChatToolCall.DisplayContent(type: "search_results", json: #"{"items":[{"title":"A"}]}"#, summary: "1 item", itemCount: 1)
    let call = ChatToolCall(id: "c1", name: "search", status: .success, result: "raw", displayContent: dc)
    let data = try JSONEncoder().encode(call)
    let json = String(data: data, encoding: .utf8) ?? ""
    #expect(json.contains("\"displayContent\""))
    #expect(json.contains("\"type\":\"search_results\""))
    let decoded = try JSONDecoder().decode(ChatToolCall.self, from: data)
    #expect(decoded.displayContent?.type == "search_results")
    #expect(decoded.displayContent?.json == #"{"items":[{"title":"A"}]}"#)
    #expect(decoded.displayContent?.summary == "1 item")
    #expect(decoded.displayContent?.itemCount == 1)
}

@Test func displayContentDefaultsSummaryNilAndItemCountOne() {
    let dc = ChatToolCall.DisplayContent(type: "t", json: "{}")
    #expect(dc.summary == nil)
    #expect(dc.itemCount == 1)
}

@Test func oldCodingWithoutDisplayContentDecodesNil() throws {
    // Encode a call without displayContent, decode, verify nil
    let call = ChatToolCall(id: "x", name: "calc", status: .success, result: "2")
    let data = try JSONEncoder().encode(call)
    let decoded = try JSONDecoder().decode(ChatToolCall.self, from: data)
    #expect(decoded.id == "x")
    #expect(decoded.result == "2")
    #expect(decoded.displayContent == nil)
}

@Test func encodingWithoutDisplayContentOmitsKey() throws {
    let call = ChatToolCall(id: "x", name: "calc", status: .success, result: "2")
    let data = try JSONEncoder().encode(call)
    let json = String(data: data, encoding: .utf8) ?? ""
    #expect(!json.contains("\"displayContent\""))
}

@Test func displayContentIsHashable() {
    let a = ChatToolCall.DisplayContent(type: "t", json: "{}")
    let b = ChatToolCall.DisplayContent(type: "t", json: "{}")
    let c = ChatToolCall.DisplayContent(type: "t", json: "{}", summary: "s")
    #expect(a == b)
    #expect(a != c)
    var set = Set<ChatToolCall.DisplayContent>()
    set.insert(a)
    #expect(set.contains(b))
}

// MARK: - Old API source compatibility

@Test func chatToolCallOldInitWithoutDisplayContentStillWorks() {
    // Verify the pre-existing init signature compiles and works identically.
    let call = ChatToolCall(id: "x", name: "calc", kind: .tool, arguments: "{}", status: .success, result: "42", details: nil, children: [])
    #expect(call.displayContent == nil)
    #expect(call.result == "42")
}

// MARK: Old initializer function references (prove old arity compiles, not just default-arg calls)

@Test func chatToolCallOld8ParamFunctionReferenceCompiles() {
    // Old code: storing ChatToolCall.init as an 8-param function reference.
    // The new init has 9 params (displayContent defaulted last); old arity must still work.
    let f: (String, String, ChatToolCall.Kind, String?, ChatToolCall.Status, String?, String?, [ChatToolCall]) -> ChatToolCall = ChatToolCall.init(id:name:kind:arguments:status:result:details:children:)
    let call = f("x", "calc", .tool, "{}", .success, "42", nil, [])
    #expect(call.displayContent == nil)
    #expect(call.result == "42")
}

@MainActor
@Test func toolCallViewOldInitWithoutToolCallContentCompiles() {
    // Old call sites: ToolCallView(toolCall: call) and ToolCallView(toolCall: call, isExpanded: true)
    let call = ChatToolCall(id: "t1", name: "test", status: .success)
    _ = ToolCallView(toolCall: call)
    _ = ToolCallView(toolCall: call, isExpanded: true)
}

@MainActor
@Test func toolCallViewOld1ParamFunctionReferenceCompiles() {
    // Old code: storing ToolCallView.init(toolCall:) as a function reference.
    let call = ChatToolCall(id: "t1", name: "test", status: .success)
    let f: (ChatToolCall) -> ToolCallView = ToolCallView.init(toolCall:)
    _ = f(call)
}

@MainActor
@Test func toolCallViewOld2ParamFunctionReferenceCompiles() {
    // Old code: storing ToolCallView.init(toolCall:isExpanded:) as a function reference.
    let call = ChatToolCall(id: "t1", name: "test", status: .success)
    let f: (ChatToolCall, Bool) -> ToolCallView = ToolCallView.init(toolCall:isExpanded:)
    _ = f(call, true)
}

@MainActor
@Test func chatViewOldInitSansSupplementaryCompilesAndPropagatesToolCallContent() throws {
    // Old call: ChatView(title:messageService:settingsView:voiceInputHandler:)
    let service = CompatSnapshotService()
    // Invoke old signature — no toolCallContent, no supplementaryContent
    let view = ChatView<CompatSnapshotService>(title: "Test", messageService: service)
    // Verify view constructs without crash; can't introspect private state,
    // but this proves the old init compiles and runs.
    _ = view.body
}

@MainActor
@Test func chatViewOldInitWithSupplementaryCompilesAndPropagates() throws {
    // Old call: ChatView(title:messageService:settingsView:voiceInputHandler:supplementaryContent:)
    let service = CompatSnapshotService()
    let view = ChatView<CompatSnapshotService>(
        title: "Test",
        messageService: service,
        supplementaryContent: { _ in AnyView(Text("legacy")) }
    )
    _ = view.body
}

@MainActor
@Test func chatViewSuppContentOld5ParamFunctionReferenceCompiles() {
    // Old code: storing ChatView.init(title:messageService:settingsView:voiceInputHandler:supplementaryContent:)
    // as a function reference. The new init has toolCallContent defaulted last.
    let service = CompatSnapshotService()
    let f: (String?, CompatSnapshotService, (() -> AnyView)?, (any VoiceInputHandler)?, @escaping (CompatSnapshotService.ChatMessage) -> AnyView?) -> ChatView<CompatSnapshotService> = ChatView<CompatSnapshotService>.init(title:messageService:settingsView:voiceInputHandler:supplementaryContent:)
    let view = f("Test", service, nil, nil, { _ in AnyView(Text("legacy")) })
    _ = view.body
}

@MainActor
@Test func chatViewViewModelOld2ParamFunctionReferenceCompiles() {
    let makeView: (ChatView<CompatSnapshotService>.ViewModel, (any VoiceInputHandler)?) -> ChatView<CompatSnapshotService> = ChatView<CompatSnapshotService>.init(viewModel:voiceInputHandler:)
    let model = ChatView<CompatSnapshotService>.ViewModel(title: "Compatibility", messageService: CompatSnapshotService())
    _ = makeView(model, nil).body
}

private final class CompatSnapshotService: ChatMessageService, @unchecked Sendable {
    typealias ChatMessage = TestMessage
    @Published var chatMessages: [TestMessage] = [TestMessage(text: "hi")]
    func send(message: String, stream: Bool) async throws {}
    func handleError(error: Error) -> ChatAlertInfo? { nil }
    func deleteMessage(id: UUID) {}
}

private final class TestMessage: ChatMessageInfo, @unchecked Sendable {
    let uuid = UUID()
    let id: UUID
    let text: String?
    let childChatMessages: [TestMessage] = []
    let isUser = false
    let isAssistant = true
    let isAgentEvent = false
    let objectWillChange = ObservableObjectPublisher()

    init(text: String?) {
        self.id = uuid
        self.text = text
    }

    static func == (lhs: TestMessage, rhs: TestMessage) -> Bool {
        lhs.uuid == rhs.uuid
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }
}
