//
//  RealtimeConversationHandler.swift
//  ChatUI
//
//  Created by Reid Chatham on 11/6/26.
//

import Foundation

/// Connection state of a live voice conversation.
public enum RealtimeConnectionState: String, Sendable {
    case disconnected = "Disconnected"
    case connecting = "Connecting…"
    case connected = "Connected"
    case error = "Error"
}

/// One line of a live conversation's transcript. Entries stream in: `text`
/// grows while `isFinal` is false.
public struct RealtimeTranscriptEntry: Identifiable, Equatable, Sendable {
    public enum Role: Sendable {
        case user
        case assistant
    }

    public let id: String
    public let role: Role
    public var text: String
    public var isFinal: Bool

    public init(id: String, role: Role, text: String, isFinal: Bool) {
        self.id = id
        self.role = role
        self.text = text
        self.isFinal = isFinal
    }
}

/// A live speech-to-speech conversation injected into ChatUI, the realtime
/// counterpart of `VoiceInputHandler`. The app owns the provider session
/// (e.g. the OpenAI Realtime API) plus mic capture and playback; ChatUI
/// renders it with `RealtimeConversationView`.
@MainActor
public protocol RealtimeConversationHandler: AnyObject, ObservableObject {
    var connectionState: RealtimeConnectionState { get }
    var transcript: [RealtimeTranscriptEntry] { get }
    /// The user is speaking (e.g. server or on-device VAD detected speech).
    var isUserSpeaking: Bool { get }
    /// The assistant's reply is playing.
    var isModelSpeaking: Bool { get }
    /// Microphone input level, 0.0 to 1.0.
    var audioLevel: Float { get }
    var lastError: String? { get }

    func connect() async
    func disconnect() async
    /// Stop the assistant's current reply.
    func interrupt() async
    /// Send a typed message into the live conversation.
    func sendText(_ text: String) async
}
