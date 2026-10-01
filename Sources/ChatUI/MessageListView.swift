//
//  MessageListView.swift
//
//  Created by Reid Chatham on 4/2/23.
//

import SwiftUI
import Combine

struct MessageListView<MessageService: ChatMessageService>: View {
    @StateObject var viewModel: ViewModel
    @ObservedObject var composerViewModel: MessageComposerView.ViewModel
    @State private var messageRevision = 0
    var supplementaryContent: ((MessageService.ChatMessage) -> AnyView?)?

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                let messages = viewModel.messageService.chatMessages
                let stoppedSources = Self.stoppedNoticeSources(in: messages, revision: messageRevision)
                LazyVStack(alignment: .leading) {
                    ForEach(messages, id: \.uuid) { message in
                        MessageListRow(
                            message: message,
                            composerViewModel: composerViewModel,
                            supplementaryContent: supplementaryContent,
                            stoppedSource: stoppedSources[message.uuid]
                        )
                    }
                }
                .padding(16)
            }
            .onAppear {
                scrollToBottom(scrollProxy: scrollProxy)
                #if os(iOS)
                NotificationCenter.default.addObserver(
                    forName: UIResponder.keyboardDidShowNotification,
                    object: nil,
                    queue: .main
                ) { _ in
                    Task { @MainActor in
                        scrollToBottom(scrollProxy: scrollProxy)
                    }
                }
                #endif
            }
            .onReceive(
                Publishers.MergeMany(viewModel.messageService.chatMessages.map { $0.objectWillChange })
                    .receive(on: DispatchQueue.main)
            ) { _ in
                // A streaming message can gain text without changing the array.
                // Recalculate which row owns the stopped notice in that case.
                messageRevision &+= 1
            }
            .onDisappear {
                #if os(iOS)
                NotificationCenter.default.removeObserver(self)
                #endif
            }.onChange(of: viewModel.messageService.chatMessages.last?.text) { (_,_) in
                scrollToBottom(scrollProxy: scrollProxy)
            }
        }
    }

    /// Show each user's stop status beneath their last textual response, or
    /// beneath their prompt if no response text arrived. Explicit ownership
    /// handles responses interleaved with another in-flight send.
    static func stoppedNoticeSources(
        in messages: [MessageService.ChatMessage],
        revision: Int = 0
    ) -> [UUID: MessageService.ChatMessage] {
        var users: [UUID: MessageService.ChatMessage] = [:]
        var lastResponse: [UUID: MessageService.ChatMessage] = [:]
        var currentUserID: UUID?
        for message in messages {
            if message.isUser {
                users[message.uuid] = message
                currentUserID = message.uuid
            } else if message.isAssistant,
                      let text = message.text,
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      let ownerID = message.responseToMessageID ?? currentUserID {
                lastResponse[ownerID] = message
            }
        }
        var sources: [UUID: MessageService.ChatMessage] = [:]
        for (id, user) in users {
            sources[lastResponse[id]?.uuid ?? id] = user
        }
        return sources
    }

    func scrollToBottom(scrollProxy: ScrollViewProxy) {
        guard let last = viewModel.messageService.chatMessages.last else { return }
        withAnimation {
            scrollProxy.scrollTo(last.uuid, anchor: .bottom)
        }
    }
}

struct MessageListRow<Message: ChatMessageInfo>: View {
    @ObservedObject var message: Message
    @ObservedObject var composerViewModel: MessageComposerView.ViewModel
    var supplementaryContent: ((Message) -> AnyView?)?
    var stoppedSource: Message? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            CollapsibleMessageView(message: message, parentIsExpanded: .constant(false))
            if let failure = message.sendFailure {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(failure.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button("Retry") {
                        Task { await composerViewModel.retry(messageID: message.uuid) }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                    .disabled(composerViewModel.isMessageSending)
                    .accessibilityIdentifier("chat.retryButton.\(message.uuid.uuidString)")
                }
                .padding(.horizontal, 8)
            }
            if let supplementary = supplementaryContent?(message) {
                supplementary
            }
            if let stoppedSource {
                StoppedResponseNotice(userMessage: stoppedSource)
            }
        }
    }
}

private struct StoppedResponseNotice<Message: ChatMessageInfo>: View {
    @ObservedObject var userMessage: Message

    var body: some View {
        if userMessage.wasResponseStopped {
            Label("Stopped by you", systemImage: "stop.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .accessibilityIdentifier("chat.stoppedMessage.\(userMessage.uuid.uuidString)")
        }
    }
}

extension MessageListView {
    @MainActor class ViewModel: ObservableObject {
        @Published var messageService: MessageService

        init(messageService: MessageService) {
            self.messageService = messageService
        }
    }
}
