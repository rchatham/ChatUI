//
//  SendLifecycleTests.swift
//  ChatUI
//
//  Created by Reid Chatham on 9/30/26.
//

import Combine
import Foundation
import Testing

@testable import ChatUI

@MainActor
@Suite struct SendLifecycleTests {
    @Test func composerCoordinatesEstablishStreamStopAndPreservesNextDraft() async throws {
        let service = LifecycleMessageService()
        let viewModel = MessageComposerView.ViewModel(messageService: service)
        viewModel.input = "first prompt"

        let send = Task { await viewModel.sendMessage() }
        await Task.yield()

        #expect(viewModel.input.isEmpty)
        #expect(viewModel.sendState == .establishing)
        #expect(viewModel.isComposerEditingDisabled)
        #expect(service.sentMessages == ["first prompt"])

        viewModel.input = "next keyboard or voice draft"
        await viewModel.sendMessage("second prompt")
        #expect(service.sentMessages == ["first prompt"])

        service.establishCurrent()
        try await waitUntil { viewModel.sendState == .streaming }
        #expect(viewModel.sendState == .streaming)
        #expect(!viewModel.isComposerEditingDisabled)

        await viewModel.sendMessage("second prompt after establishment")
        #expect(service.sentMessages == ["first prompt"])

        viewModel.stopSending()
        #expect(viewModel.sendState == .stopping)
        #expect(service.chatMessages.first?.wasResponseStopped == true)
        await send.value

        #expect(viewModel.sendState == .idle)
        #expect(viewModel.input == "next keyboard or voice draft")
        #expect(!viewModel.showAlert)
    }

    @MainActor
    @Test func synchronousSubmissionDoesNotEraseANewDraft() async throws {
        let service = LifecycleMessageService()
        let viewModel = MessageComposerView.ViewModel(messageService: service)

        // MessageComposerView clears its field before synchronously starting the send.
        let send = try #require(viewModel.startSending("submitted prompt"))
        #expect(service.sentMessages == ["submitted prompt"])
        #expect(viewModel.sendState == .establishing)

        viewModel.input = "new keyboard or voice draft"
        service.establishCurrent()
        service.finishCurrent()
        await send.value
        #expect(viewModel.input == "new keyboard or voice draft")
    }

    @MainActor
    @Test func establishmentFailureReturnsComposerToIdleAndShowsError() async throws {
        let service = LifecycleMessageService()
        let viewModel = MessageComposerView.ViewModel(messageService: service)

        let send = Task { await viewModel.sendMessage("cannot establish") }
        try await waitUntil { viewModel.sendState == .establishing }
        service.failBeforeEstablishment(message: "Connection unavailable")
        await send.value

        #expect(viewModel.sendState == .idle)
        #expect(viewModel.showAlert)
        #expect(viewModel.alertInfo?.title == "Connection unavailable")
    }

    @MainActor
    @Test func composerUsesInlineFailureAndRetriesThroughSameViewModel() async throws {
        let service = LifecycleMessageService()
        let viewModel = MessageComposerView.ViewModel(messageService: service)

        let send = Task { await viewModel.sendMessage("retry me") }
        await Task.yield()
        service.establishCurrent()
        try await waitUntil { viewModel.sendState == .streaming }
        #expect(viewModel.sendState == .streaming)
        viewModel.input = "newer draft"
        service.failCurrentInline(message: "Connection lost")
        await send.value

        let messageID = try #require(service.chatMessages.first?.uuid)
        #expect(service.chatMessages.first?.sendFailure?.message == "Connection lost")
        #expect(viewModel.input == "newer draft")
        #expect(!viewModel.showAlert)

        let retry = Task { await viewModel.retry(messageID: messageID) }
        await Task.yield()
        #expect(service.retriedMessageIDs == [messageID])
        #expect(viewModel.sendState == .establishing)
        service.establishCurrent()
        service.finishCurrent()
        await retry.value

        #expect(viewModel.sendState == .idle)
        #expect(viewModel.input == "newer draft")
    }

    @MainActor
    @Test func legacyFailureDoesNotRestoreSentTextOrEraseNewerDraft() async throws {
        let service = FailingLegacyMessageService()
        let viewModel = MessageComposerView.ViewModel(messageService: service)
        viewModel.input = "legacy prompt"

        let send = Task { await viewModel.sendMessage() }
        try await waitUntil {
            service.sentMessages == ["legacy prompt"] && viewModel.sendState == .streaming
        }
        viewModel.input = "newer legacy draft"
        service.failCurrent(message: "Legacy failure")
        await send.value

        #expect(viewModel.input == "newer legacy draft")
        #expect(viewModel.alertInfo?.title == "Legacy failure")
        #expect(viewModel.showAlert)
    }

    @MainActor
    @Test func streamingSendPreservesConsumedVoiceDraft() async throws {
        let service = LifecycleMessageService()
        let voiceHandler = FakeVoiceInputHandler()
        voiceHandler.replaceSendButton = true
        let viewModel = MessageComposerView.ViewModel(
            messageService: service,
            voiceInputHandler: voiceHandler
        )
        let composer = MessageComposerView(viewModel: viewModel)
        let send = try #require(viewModel.startSending("submitted prompt"))

        #expect(!composer.shouldShowLeadingMicrophone)
        service.establishCurrent()
        try await waitUntil { viewModel.sendState == .streaming }
        #expect(!composer.shouldShowLeadingMicrophone)
        #expect(composer.viewModel.sendState == .streaming)
        voiceHandler.pendingTranscribedText = "streaming voice draft"

        #expect(viewModel.consumePendingVoiceText() == "streaming voice draft")
        #expect(voiceHandler.pendingTranscribedText == nil)
        service.finishCurrent()
        await send.value

        #expect(viewModel.input == "streaming voice draft")
    }

    @MainActor
    @Test func leftSideMicrophoneKeepsItsPositionWhileStreaming() async throws {
        let service = LifecycleMessageService()
        let voiceHandler = FakeVoiceInputHandler()
        voiceHandler.replaceSendButton = false
        let viewModel = MessageComposerView.ViewModel(
            messageService: service,
            voiceInputHandler: voiceHandler
        )
        let composer = MessageComposerView(viewModel: viewModel)
        #expect(composer.shouldShowLeadingMicrophone)

        let send = try #require(viewModel.startSending("prompt"))
        service.establishCurrent()
        try await waitUntil { viewModel.sendState == .streaming }
        #expect(composer.shouldShowLeadingMicrophone)
        service.finishCurrent()
        await send.value
    }

    @MainActor
    @Test func legacyServiceGetsOperationAdapterAndRetryUnsupported() async throws {
        let service = LegacyMessageService()
        let operation = service.sendOperation(message: "legacy", stream: true)

        try await operation.waitUntilEstablished()
        try await operation.waitForCompletion()
        #expect(service.sentMessages == ["legacy"])
        #expect(throws: ChatMessageServiceError.retryUnsupported) {
            _ = try service.retryOperation(messageID: UUID(), stream: true)
        }
    }
}

@MainActor
private func waitUntil(
    _ condition: @escaping @MainActor () -> Bool
) async throws {
    for _ in 0..<1_000 {
        if condition() { return }
        await Task.yield()
    }
    throw LifecycleWaitError.timedOut
}

private enum LifecycleWaitError: Error {
    case timedOut
}

private enum LifecycleTestError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message): message
        }
    }
}

private final class LifecycleGate: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<Void, any Error>?
    private var continuations: [CheckedContinuation<Void, any Error>] = []

    func wait() async throws {
        try await withCheckedThrowingContinuation { continuation in
            lock.withLock {
                if let result {
                    continuation.resume(with: result)
                } else {
                    continuations.append(continuation)
                }
            }
        }
    }

    func succeed() {
        resolve(.success(()))
    }

    func fail(_ error: any Error) {
        resolve(.failure(error))
    }

    private func resolve(_ result: Result<Void, any Error>) {
        let pending = lock.withLock { () -> [CheckedContinuation<Void, any Error>] in
            guard self.result == nil else { return [] }
            self.result = result
            let pending = continuations
            continuations.removeAll()
            return pending
        }
        pending.forEach { $0.resume(with: result) }
    }
}

private final class LifecycleMessageService: ChatMessageService, @unchecked Sendable {
    @Published var chatMessages: [LifecycleMessage] = []
    private(set) var sentMessages: [String] = []
    private(set) var retriedMessageIDs: [UUID] = []
    private var establishment = LifecycleGate()
    private var completion = LifecycleGate()

    func send(message: String, stream: Bool) async throws {}

    func sendOperation(message: String, stream: Bool) -> ChatSendOperation {
        sentMessages.append(message)
        let chatMessage = LifecycleMessage(text: message, isUser: true)
        chatMessages.append(chatMessage)
        return operation(messageID: chatMessage.uuid)
    }

    func retryOperation(messageID: UUID, stream: Bool) throws -> ChatSendOperation {
        retriedMessageIDs.append(messageID)
        establishment = LifecycleGate()
        completion = LifecycleGate()
        return operation(messageID: messageID)
    }

    func establishCurrent() {
        establishment.succeed()
    }

    func finishCurrent() {
        completion.succeed()
    }

    func failBeforeEstablishment(message: String) {
        let error = LifecycleTestError.failed(message)
        establishment.fail(error)
        completion.fail(error)
    }

    func failCurrentInline(message: String) {
        chatMessages.first?.sendFailure = ChatSendFailure(message: message)
        completion.fail(LifecycleTestError.failed(message))
    }

    func handleError(error: any Error) -> ChatAlertInfo? {
        ChatAlertInfo(title: error.localizedDescription)
    }

    func markResponseStopped(messageID: UUID) {
        chatMessages.first(where: { $0.uuid == messageID })?.wasResponseStopped = true
    }

    func deleteMessage(id: UUID) {
        chatMessages.removeAll { $0.uuid == id }
    }

    private func operation(messageID: UUID) -> ChatSendOperation {
        let establishment = self.establishment
        let completion = self.completion
        let establishmentTask = Task { try await establishment.wait() }
        let completionTask = Task { try await completion.wait() }
        return ChatSendOperation(
            messageID: messageID,
            establishment: establishmentTask,
            completion: completionTask,
            cancel: {
                establishment.fail(CancellationError())
                completion.fail(CancellationError())
                establishmentTask.cancel()
                completionTask.cancel()
            }
        )
    }
}

private final class FailingLegacyMessageService: ChatMessageService, @unchecked Sendable {
    @Published private(set) var chatMessages: [LifecycleMessage] = []
    private(set) var sentMessages: [String] = []
    private let completion = LifecycleGate()

    func send(message: String, stream: Bool) async throws {
        sentMessages.append(message)
        try await completion.wait()
    }

    func failCurrent(message: String) {
        completion.fail(LifecycleTestError.failed(message))
    }

    func handleError(error: any Error) -> ChatAlertInfo? {
        ChatAlertInfo(title: error.localizedDescription)
    }

    func deleteMessage(id: UUID) {}
}

@MainActor
private final class FakeVoiceInputHandler: VoiceInputHandler {
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var audioLevel: Float = 0
    @Published var statusDescription = "Idle"
    @Published var isEnabled = true
    @Published var replaceSendButton = false
    @Published var partialText = ""
    @Published var pendingTranscribedText: String?

    func toggleRecording() async throws {
        isRecording.toggle()
    }

    func cancelRecording() {
        isRecording = false
    }

    func getTranscribedText() -> String? { nil }
}

private final class LegacyMessageService: ChatMessageService, @unchecked Sendable {
    @Published private(set) var chatMessages: [LifecycleMessage] = []
    private(set) var sentMessages: [String] = []

    func send(message: String, stream: Bool) async throws {
        sentMessages.append(message)
    }

    func handleError(error: any Error) -> ChatAlertInfo? { nil }
    func deleteMessage(id: UUID) {}
}

private final class LifecycleMessage: ChatMessageInfo, @unchecked Sendable {
    let uuid = UUID()
    var id: UUID { uuid }
    let text: String?
    let childChatMessages: [LifecycleMessage] = []
    let isUser: Bool
    var isAssistant: Bool { !isUser }
    let isAgentEvent = false
    @Published var sendFailure: ChatSendFailure?
    @Published var wasResponseStopped = false

    init(text: String?, isUser: Bool) {
        self.text = text
        self.isUser = isUser
    }

    static func == (lhs: LifecycleMessage, rhs: LifecycleMessage) -> Bool {
        lhs.uuid == rhs.uuid
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }
}
