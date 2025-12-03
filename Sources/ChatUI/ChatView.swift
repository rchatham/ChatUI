//
//  ChatView.swift
//
//  Created by Reid Chatham on 1/20/23.
//

import SwiftUI
import CoreData
import Combine

public struct ChatView<MessageService: ChatMessageService>: View {
    @ObservedObject var viewModel: ViewModel
    private var _settingsView: (() -> AnyView)?
    private var _messageContent: ((MessageService.ChatMessage) -> AnyView)?
    private var voiceInputHandler: VoiceInputHandler?

    public init(title: String? = nil, messageService: MessageService, settingsView: (() -> AnyView)? = nil, voiceInputHandler: VoiceInputHandler? = nil) {
        viewModel = ViewModel(title: title, messageService: messageService)
        _settingsView = settingsView
        _messageContent = nil
        self.voiceInputHandler = voiceInputHandler
    }

    public init(
        title: String? = nil,
        messageService: MessageService,
        settingsView: (() -> AnyView)? = nil,
        voiceInputHandler: VoiceInputHandler? = nil,
        @ViewBuilder messageContent: @escaping (MessageService.ChatMessage) -> some View
    ) {
        viewModel = ViewModel(title: title, messageService: messageService)
        _settingsView = settingsView
        _messageContent = { message in AnyView(messageContent(message)) }
        self.voiceInputHandler = voiceInputHandler
    }

    public init(viewModel: ViewModel, voiceInputHandler: VoiceInputHandler? = nil) {
        self.viewModel = viewModel
        _messageContent = nil
        self.voiceInputHandler = voiceInputHandler
    }

    public var body: some View {
        if let title = viewModel.title {
            chatView.navigationTitle(title)
        } else {
            chatView
        }
    }

    var chatView: some View {
        VStack {
            messageList
            messageComposerView
                .invalidInputAlert(isPresented: $viewModel.showAlert)
        }
        .toolbar {
            if let settingsView = _settingsView?() {
                NavigationLink(destination: settingsView) {
                    Image(systemName: "gear")
                }
            }
        }
        #if os(iOS)
        .dismissKeyboardOnSwipe()
        #endif
    }

    @ViewBuilder
    var messageList: some View {
        MessageListView(viewModel: viewModel.messageListViewModel(), messageContent: _messageContent)
    }

    @ViewBuilder
    var messageComposerView: some View {
        MessageComposerView(viewModel: viewModel.messageComposerViewModel(voiceInputHandler: voiceInputHandler))
    }
}

extension ChatView {
    @MainActor public class ViewModel: ObservableObject {
        @Published var title: String?
        @Published var input = ""
        @Published var showAlert = false
        private let messageService: MessageService

        public init(title: String? = nil, messageService: MessageService) {
            self.title = title
            self.messageService = messageService
        }

        func delete(id: UUID) {
            messageService.deleteMessage(id: id)
        }

        func messageComposerViewModel(voiceInputHandler: VoiceInputHandler? = nil) -> MessageComposerView.ViewModel {
            return MessageComposerView.ViewModel(messageService: messageService, voiceInputHandler: voiceInputHandler)
        }

        func messageListViewModel() -> MessageListView<MessageService>.ViewModel {
            return MessageListView.ViewModel(messageService: messageService)
        }
    }
}
