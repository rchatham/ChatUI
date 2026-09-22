import Combine
import Foundation
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
