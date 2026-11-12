//
//  ComposerAccessory.swift
//

import SwiftUI

/// What the composer is doing right now, handed to a view placed directly above it.
///
/// Apps use this to react to the person typing, focusing the field, or waiting on a send.
public struct ChatComposerContext: Equatable, Sendable {
    /// The unsent text in the prompt field.
    public var draft: String
    /// Whether the prompt field has keyboard focus.
    public var isFocused: Bool
    /// Whether a send is establishing, streaming or stopping.
    public var isSending: Bool

    public init(draft: String = "", isFocused: Bool = false, isSending: Bool = false) {
        self.draft = draft
        self.isFocused = isFocused
        self.isSending = isSending
    }

    /// Whether the draft holds anything besides whitespace.
    public var hasDraft: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension ChatComposerContext {
    @MainActor
    init(_ composer: MessageComposerView.ViewModel) {
        self.init(draft: composer.input, isFocused: composer.isInputFocused, isSending: composer.isMessageSending)
    }
}

enum ComposerAccessoryLayout {
    /// Only growth hides the list's last row. Shrinking reveals more and needs no
    /// scroll, which also leaves someone reading history where they are.
    static func shouldScrollToBottom(accessoryHeightFrom oldHeight: CGFloat, to newHeight: CGFloat) -> Bool {
        newHeight > oldHeight
    }
}

/// Observes the composer so the accessory re-renders as the person types.
struct ComposerAccessoryHost: View {
    @ObservedObject var composer: MessageComposerView.ViewModel
    let content: (ChatComposerContext) -> AnyView

    var body: some View {
        content(ChatComposerContext(composer))
    }
}

extension View {
    /// Reports this view's height whenever it changes.
    @ViewBuilder
    func onHeightChange(_ action: @escaping (CGFloat) -> Void) -> some View {
        if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
            onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                action(height)
            }
        } else {
            self
        }
    }
}
