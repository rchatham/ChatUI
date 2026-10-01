//
//  MessageListView.swift
//
//  Created by Reid Chatham on 4/2/23.
//

import SwiftUI

struct MessageListView<MessageService: ChatMessageService>: View {
    @StateObject var viewModel: ViewModel
    @ObservedObject var composerViewModel: MessageComposerView.ViewModel
    var supplementaryContent: ((MessageService.ChatMessage) -> AnyView?)?

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(alignment: .leading) {
                    ForEach(viewModel.messageService.chatMessages, id: \.uuid) { message in
                        MessageListRow(
                            message: message,
                            composerViewModel: composerViewModel,
                            supplementaryContent: supplementaryContent
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
            .onDisappear {
                #if os(iOS)
                NotificationCenter.default.removeObserver(self)
                #endif
            }.onChange(of: viewModel.messageService.chatMessages.last?.text) { (_,_) in
                scrollToBottom(scrollProxy: scrollProxy)
            }
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            CollapsibleMessageView(message: message, parentIsExpanded: .constant(false))
            if message.wasResponseStopped {
                Label("Stopped by you", systemImage: "stop.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .accessibilityIdentifier("chat.stoppedMessage.\(message.uuid.uuidString)")
            }
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
