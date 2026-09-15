//
//  MessageService.swift
//  LangTools_Example
//
//  Created by Reid Chatham on 2/16/25.
//

import Foundation
import Combine
import SwiftUI

/// A tool invocation associated with a chat message.
///
/// A call remains ``Status/pending`` until its host app records either a successful
/// or failed result. `arguments` and `result` are presented as expandable details.
public struct ChatToolCall: Identifiable, Sendable, Hashable, Codable {
    public enum Status: Sendable, Hashable, Codable {
        case pending
        case success
        case failure
    }

    /// A stable identifier supplied by the tool provider or host app.
    public let id: String
    /// The human-readable tool name displayed in the conversation.
    public let name: String
    /// The serialized tool input, if available.
    public let arguments: String?
    /// The tool execution state.
    public let status: Status
    /// The serialized tool output or error, if execution has completed.
    public let result: String?

    public init(id: String, name: String, arguments: String? = nil, status: Status = .pending, result: String? = nil) {
        self.id = id
        self.name = name
        self.arguments = arguments
        self.status = status
        self.result = result
    }
}

public protocol ChatMessageInfo: Sendable, ObservableObject, Identifiable, Hashable where ID == UUID {
    var uuid: UUID { get }
    var text: String? { get }
    /// Tool invocations made while producing this message.
    var toolCalls: [ChatToolCall] { get }

    var childChatMessages: [Self] { get }

    var isUser: Bool { get }
    var isAssistant: Bool { get }
    var isAgentEvent: Bool { get }
}

public extension ChatMessageInfo {
    /// Existing message models without tool activity continue to render normally.
    var toolCalls: [ChatToolCall] { [] }
}

public protocol ChatMessageService: Sendable, ObservableObject {
    associatedtype ChatMessage: ChatMessageInfo
    var chatMessages: [ChatMessage] { get }
    func send(message: String, stream: Bool) async throws
    func handleError(error: Error) -> ChatAlertInfo?
    func deleteMessage(id: UUID)
}

public struct ChatAlertInfo {
    public var title: String
    public var textField: TextFieldInfo?
    public var button: ButtonInfo?
    public var message: String?
    public init(title: String, textField: TextFieldInfo? = nil, button: ButtonInfo? = nil, message: String? = nil) {
        self.title = title
        self.textField = textField
        self.button = button
        self.message = message
    }
}

public struct TextFieldInfo {
    public var placeholder: String?
    public var label: String
    public var text: Binding<String>
    public init(placeholder: String? = nil, label: String, text: Binding<String>) {
        self.placeholder = placeholder
        self.label = label
        self.text = text
    }
}

public struct ButtonInfo {
    public var text: String
    public var action: (ChatAlertInfo) throws -> Void
    public var role: ButtonRole?
    public init(text: String, action: @escaping (ChatAlertInfo) throws -> Void = {_ in}, role: ButtonRole? = nil) {
        self.text = text
        self.action = action
        self.role = role
    }
}
