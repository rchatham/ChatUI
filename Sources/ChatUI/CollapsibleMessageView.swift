//
//  CollapsibleMessageView.swift
//  LangTools_Example
//
//  Created by Reid Chatham on 2/15/25.
//

import Foundation
import SwiftUI


struct CollapsibleMessageView<Message: ChatMessageInfo>: View {
    @ObservedObject var message: Message
    @Environment(\.colorScheme) var colorScheme
    @State private var isExpanded = false
    @Binding var parentIsExpanded: Bool?
    @Binding var expandedToolCallRoute: ToolCallExpansionRoute?

    init(
        message: Message,
        parentIsExpanded: Binding<Bool?>,
        expandedToolCallRoute: Binding<ToolCallExpansionRoute?> = .constant(nil)
    ) {
        self.message = message
        self._parentIsExpanded = parentIsExpanded
        self._expandedToolCallRoute = expandedToolCallRoute
    }

    var isHidden: Bool {
        !hasText && message.toolCalls.isEmpty && message.childChatMessages.isEmpty
    }

    private var hasText: Bool {
        !(message.text?.isEmpty ?? true)
    }

    private var showsMessageBubble: Bool {
        hasText || !message.childChatMessages.isEmpty
    }

    var body: some View {
        if !isHidden {
            VStack(alignment: .leading, spacing: 4) {
                // Main message bubble. Tool-only assistant messages omit the empty bubble,
                // while legacy textless messages retain their child disclosure control.
                if showsMessageBubble {
                    messageBubble
                }

                if !message.toolCalls.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(message.toolCalls.enumerated()), id: \.offset) { index, toolCall in
                            ToolCallView(
                                toolCall: toolCall,
                                route: ToolCallExpansionRoute(
                                    messageID: message.uuid,
                                    index: index,
                                    toolCallID: toolCall.id
                                ),
                                expandedRoute: $expandedToolCallRoute
                            )
                        }
                    }
                }

                // Child messages
                if isExpanded {
                    childMessagesView
                }
            }
        }
    }

    @ViewBuilder
    private var messageBubble: some View {
        if !hasText && !message.childChatMessages.isEmpty {
            Button(action: action) {
                messageView
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityIdentifier("message-bubble-\(message.uuid.uuidString)")
            .accessibilityLabel("Replies")
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint(isExpanded ? "Hide replies" : "Show replies")
        } else {
            Button(action: action) {
                messageView
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityIdentifier("message-bubble-\(message.uuid.uuidString)")
        }
    }

    var messageView: some View {
        HStack {
            if message.isUser { Spacer() }
            VStack(alignment: .leading) {
                HStack {
                    if !message.childChatMessages.isEmpty {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(messageColor.opacity(0.7))
                    }
                    if let text = message.text, !text.isEmpty {
                        Text(text)
                            .font(.system(size: 16))
                            .foregroundColor(messageColor)
                    }
                }
                .padding(10)
                .background(backgroundColor)
                .cornerRadius(10)
            }
            if message.isAssistant { Spacer() }
        }
    }

    var childMessagesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(message.childChatMessages) { childMessage in
                let binding = Binding<Bool?>(
                    get: { isExpanded },
                    set: { val in isExpanded = val ?? false })
                CollapsibleMessageView(
                    message: childMessage,
                    parentIsExpanded: binding,
                    expandedToolCallRoute: $expandedToolCallRoute
                )
                .padding(.leading, 16)
            }
        }
        .padding(.top, 4)
        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
        .overlay(
            Rectangle()
                .frame(width: 2)
                .foregroundColor(Color.gray.opacity(0.3))
                .padding(.leading, 7),
            alignment: .leading
        )
    }

    var action: () -> Void {
        return {
            if !message.childChatMessages.isEmpty {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    parentIsExpanded = false
                }
            }
        }
    }

    private var messageColor: Color {
        if message.isAgentEvent {
            return .secondary
        }
        return message.isUser ? 
            (colorScheme == .dark ? .white : .black) : 
            .white
    }
    
    private var backgroundColor: Color {
        if message.isAgentEvent {
            return colorScheme == .dark ? 
                Color.gray.opacity(0.3) : 
                Color.gray.opacity(0.1)
        }
        return message.isUser ? 
            (colorScheme == .dark ? Color.gray.opacity(0.5) : .gray.opacity(0.2)) : 
            .blue
    }
}
