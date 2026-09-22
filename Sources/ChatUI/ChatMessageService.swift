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
/// Agent invocations use ``Kind/agent`` and carry `details` plus `children` for
/// nested sub-tool calls and sub-agent delegations.
public struct ChatToolCall: Identifiable, Sendable, Hashable, Codable {
    public enum Status: Sendable, Hashable, Codable {
        case pending
        case success
        case failure
    }

    /// Distinguishes a plain tool call from an agent invocation.
    public enum Kind: Sendable, Hashable, Codable {
        case tool
        case agent
    }

    /// A stable identifier supplied by the tool provider or host app.
    public let id: String
    /// The human-readable name displayed in the conversation.
    public let name: String
    /// Whether this call is a plain tool or an agent.
    public let kind: Kind
    /// The serialized tool input, if available (tools only).
    public let arguments: String?
    /// The execution state.
    public let status: Status
    /// The serialized tool output or error, if execution has completed.
    public let result: String?
    /// Agent narrative (e.g. "started: …", "delegated: …") or an error message.
    public var details: String?
    /// Nested sub-tool calls and sub-agent delegations (agents only).
    public var children: [ChatToolCall]

    public init(id: String, name: String, kind: Kind = .tool, arguments: String? = nil, status: Status = .pending, result: String? = nil, details: String? = nil, children: [ChatToolCall] = []) {
        self.id = id
        self.name = name
        self.kind = kind
        self.arguments = arguments
        self.status = status
        self.result = result
        self.details = details
        self.children = children
    }

    private enum CodingKeys: String, CodingKey { case id, name, kind, arguments, status, result, details, children }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        kind = try c.decodeIfPresent(Kind.self, forKey: .kind) ?? .tool
        arguments = try c.decodeIfPresent(String.self, forKey: .arguments)
        status = try c.decodeIfPresent(Status.self, forKey: .status) ?? .pending
        result = try c.decodeIfPresent(String.self, forKey: .result)
        details = try c.decodeIfPresent(String.self, forKey: .details)
        children = try c.decodeIfPresent([ChatToolCall].self, forKey: .children) ?? []
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        if kind != .tool { try c.encode(kind, forKey: .kind) }
        try c.encodeIfPresent(arguments, forKey: .arguments)
        try c.encode(status, forKey: .status)
        try c.encodeIfPresent(result, forKey: .result)
        try c.encodeIfPresent(details, forKey: .details)
        if !children.isEmpty { try c.encode(children, forKey: .children) }
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
