//
//  ComposerAccessoryTests.swift
//  ChatUI
//

import CoreGraphics
import Testing

@testable import ChatUI

@Suite struct ComposerAccessoryTests {
    @Test func draftIgnoresSurroundingWhitespace() {
        #expect(!ChatComposerContext().hasDraft)
        #expect(!ChatComposerContext(draft: " \n\t").hasDraft)
        #expect(ChatComposerContext(draft: "  hi ").hasDraft)
    }

    @Test func contextDefaultsToAnIdleEmptyComposer() {
        let context = ChatComposerContext()
        #expect(context.draft.isEmpty)
        #expect(!context.isFocused)
        #expect(!context.isSending)
    }

    @Test func listScrollsOnlyWhenTheAccessoryGrows() {
        typealias Layout = ComposerAccessoryLayout
        #expect(Layout.shouldScrollToBottom(accessoryHeightFrom: 0, to: 48))
        #expect(Layout.shouldScrollToBottom(accessoryHeightFrom: 48, to: 60))
        #expect(!Layout.shouldScrollToBottom(accessoryHeightFrom: 48, to: 0))
        #expect(!Layout.shouldScrollToBottom(accessoryHeightFrom: 48, to: 48))
    }
}
