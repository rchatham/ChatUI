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
