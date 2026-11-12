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
    private var _composerAccessory: ((ChatComposerContext) -> AnyView)?
    private var voiceInputHandler: (any VoiceInputHandler)?
    /// Height of the composer accessory, so the list can keep its last row in view.
    @State private var composerAccessoryHeight: CGFloat = 0

    public init(title: String? = nil, messageService: MessageService, settingsView: (() -> AnyView)? = nil, voiceInputHandler: (any VoiceInputHandler)? = nil) {
        _viewModel = StateObject(wrappedValue: ViewModel(title: title, messageService: messageService))
        _settingsView = settingsView
        _supplementaryContent = nil
        _composerAccessory = nil
        self.voiceInputHandler = voiceInputHandler
    }

    /// - Parameters:
    ///   - composerAccessory: A view placed directly above the composer, between it and the
    ///     message list. It receives the composer's current state, so it can react to the
    ///     person typing. Return a view with no content to take no space.
    ///   - supplementaryContent: Extra content shown beneath a message row.
    public init(
        title: String? = nil,
        messageService: MessageService,
        settingsView: (() -> AnyView)? = nil,
        voiceInputHandler: (any VoiceInputHandler)? = nil,
        composerAccessory: ((ChatComposerContext) -> AnyView)? = nil,
        supplementaryContent: @escaping (MessageService.ChatMessage) -> AnyView?
    ) {
        _viewModel = StateObject(wrappedValue: ViewModel(title: title, messageService: messageService))
        _settingsView = settingsView
        _supplementaryContent = supplementaryContent
        _composerAccessory = composerAccessory
        self.voiceInputHandler = voiceInputHandler
    }

    public init(viewModel: ViewModel, voiceInputHandler: (any VoiceInputHandler)? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _supplementaryContent = nil
        _composerAccessory = nil
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
            // One child of the outer stack, so an empty accessory adds no spacing.
            VStack(spacing: 0) {
                composerAccessory
                messageComposerView
                    .invalidInputAlert(isPresented: $viewModel.showAlert)
            }
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
            composerAccessoryHeight: composerAccessoryHeight
        )
    }

    @ViewBuilder
    var composerAccessory: some View {
        if let accessory = _composerAccessory {
            ComposerAccessoryHost(
                composer: viewModel.messageComposerViewModel(voiceInputHandler: voiceInputHandler),
                content: accessory
            )
            .onHeightChange { composerAccessoryHeight = $0 }
        }
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
