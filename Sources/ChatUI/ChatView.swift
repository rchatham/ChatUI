//
//  ChatView.swift
//
//  Created by Reid Chatham on 1/20/23.
//

import SwiftUI
import CoreData
import Combine

public struct ChatView<MessageService: ChatMessageService>: View {
    @StateObject var viewModel: ViewModel
    private var _settingsView: (() -> AnyView)?
    private var _supplementaryContent: ((MessageService.ChatMessage) -> AnyView?)?
    private var _toolCallContent: ((ChatToolCall) -> AnyView?)?
    private var voiceInputHandler: (any VoiceInputHandler)?

    /// Creates a chat view without supplementary content.
    ///
    /// - Parameters:
    ///   - title: Optional navigation title.
    ///   - messageService: The chat message service.
    ///   - settingsView: Optional settings view builder.
    ///   - voiceInputHandler: Optional voice input handler.
    ///   - toolCallContent: Optional closure returning a custom view for a
    ///     successful tool/agent call. The view renders **below** the call card
    ///     independently of collapsed/expanded disclosure. Return `nil` to fall
    ///     back to raw output. Never invoked for pending or failed calls.
    public init(title: String? = nil, messageService: MessageService, settingsView: (() -> AnyView)? = nil, voiceInputHandler: (any VoiceInputHandler)? = nil, toolCallContent: ((ChatToolCall) -> AnyView?)? = nil) {
        _viewModel = StateObject(wrappedValue: ViewModel(title: title, messageService: messageService))
        _settingsView = settingsView
        _supplementaryContent = nil
        _toolCallContent = toolCallContent
        self.voiceInputHandler = voiceInputHandler
    }

    /// Old 4-parameter initializer preserved for source compatibility.
    /// Function references and call sites using the pre-``toolCallContent``
    /// arity continue to compile; delegates to the full initializer.
    public init(title: String? = nil, messageService: MessageService, settingsView: (() -> AnyView)? = nil, voiceInputHandler: (any VoiceInputHandler)? = nil) {
        self.init(title: title, messageService: messageService, settingsView: settingsView, voiceInputHandler: voiceInputHandler, toolCallContent: nil)
    }

    /// Creates a chat view with supplementary message content.
    ///
    /// - Parameters:
    ///   - title: Optional navigation title.
    ///   - messageService: The chat message service.
    ///   - settingsView: Optional settings view builder.
    ///   - voiceInputHandler: Optional voice input handler.
    ///   - supplementaryContent: Closure returning a custom view for a chat
    ///     message, rendered below the message bubble.
    ///   - toolCallContent: Optional closure returning a custom view for a
    ///     successful tool/agent call. The view renders **below** the call card
    ///     independently of collapsed/expanded disclosure. Return `nil` to fall
    ///     back to raw output. Never invoked for pending or failed calls.
    public init(
        title: String? = nil,
        messageService: MessageService,
        settingsView: (() -> AnyView)? = nil,
        voiceInputHandler: (any VoiceInputHandler)? = nil,
        supplementaryContent: @escaping (MessageService.ChatMessage) -> AnyView?,
        toolCallContent: ((ChatToolCall) -> AnyView?)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: ViewModel(title: title, messageService: messageService))
        _settingsView = settingsView
        _supplementaryContent = supplementaryContent
        _toolCallContent = toolCallContent
        self.voiceInputHandler = voiceInputHandler
    }

    /// Old 5-parameter initializer with supplementary content, preserved for
    /// source compatibility. Function references using the pre-``toolCallContent``
    /// arity continue to compile; delegates to the full initializer.
    public init(
        title: String? = nil,
        messageService: MessageService,
        settingsView: (() -> AnyView)? = nil,
        voiceInputHandler: (any VoiceInputHandler)? = nil,
        supplementaryContent: @escaping (MessageService.ChatMessage) -> AnyView?
    ) {
        self.init(title: title, messageService: messageService, settingsView: settingsView, voiceInputHandler: voiceInputHandler, supplementaryContent: supplementaryContent, toolCallContent: nil)
    }

    /// Creates a chat view from a pre-built ViewModel.
    ///
    /// - Parameters:
    ///   - viewModel: The pre-configured ViewModel.
    ///   - voiceInputHandler: Optional voice input handler.
    ///   - toolCallContent: Optional closure returning a custom view for a
    ///     successful tool/agent call. The view renders **below** the call card
    ///     independently of collapsed/expanded disclosure. Return `nil` to fall
    ///     back to raw output. Never invoked for pending or failed calls.
    public init(viewModel: ViewModel, voiceInputHandler: (any VoiceInputHandler)? = nil) {
        self.init(viewModel: viewModel, voiceInputHandler: voiceInputHandler, toolCallContent: nil)
    }

    public init(viewModel: ViewModel, voiceInputHandler: (any VoiceInputHandler)? = nil, toolCallContent: ((ChatToolCall) -> AnyView?)? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _supplementaryContent = nil
        _toolCallContent = toolCallContent
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
        MessageListView(
            viewModel: viewModel.messageListViewModel(),
            composerViewModel: viewModel.messageComposerViewModel(voiceInputHandler: voiceInputHandler),
            supplementaryContent: _supplementaryContent,
            toolCallContent: _toolCallContent
        )
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
        private var _messageComposerViewModel: MessageComposerView.ViewModel?

        public init(title: String? = nil, messageService: MessageService) {
            self.title = title
            self.messageService = messageService
        }

        func delete(id: UUID) {
            messageService.deleteMessage(id: id)
        }

        func messageComposerViewModel(voiceInputHandler: (any VoiceInputHandler)? = nil) -> MessageComposerView.ViewModel {
            if let cached = _messageComposerViewModel {
                return cached
            }
            let vm = MessageComposerView.ViewModel(messageService: messageService, voiceInputHandler: voiceInputHandler)
            _messageComposerViewModel = vm
            return vm
        }

        func messageListViewModel() -> MessageListView<MessageService>.ViewModel {
            return MessageListView.ViewModel(messageService: messageService)
        }
    }
}
