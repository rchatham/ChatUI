//
//  ToolCallViewAccessibilityTests.swift
//  ChatUITests
//
//  Verifies nested tool-call controls remain independently accessible.
//

#if canImport(AppKit)
import AppKit
import SwiftUI
import Testing
@testable import ChatUI

@MainActor
struct ToolCallViewAccessibilityTests {

    @Test func expandedParentExposesInteractiveChildAsIndependentDisclosureButton() {
        NSApplication.shared.finishLaunching()
        enableInProcessAccessibilityHierarchy()

        let parent = ChatToolCall(
            id: "parent",
            name: "Research",
            kind: .agent,
            status: .success,
            children: [
                ChatToolCall(
                    id: "interactive-child",
                    name: "Search",
                    arguments: #"{"query":"Swift accessibility"}"#,
                    status: .success
                ),
                ChatToolCall(id: "contentless-child", name: "Summarize", status: .success)
            ]
        )
        let host = NSHostingView(
            rootView: ToolCallView(toolCall: parent, isExpanded: true)
                .frame(width: 420, alignment: .leading)
        )
        host.frame = NSRect(x: 0, y: 0, width: 420, height: 240)

        let window = NSWindow(
            contentRect: host.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        window.orderFront(nil)
        defer {
            window.orderOut(nil)
            window.contentView = nil
        }

        let elements = accessibilityTree(from: host) { elements in
            elements.contains { $0.accessibleText == "Agent Research, Completed" }
                && elements.contains { $0.accessibleText == "Tool Search, Completed" }
                && elements.contains { $0.accessibleText == "Tool Summarize, Completed" }
        }
        let parentButton = elements.first {
            $0.role == .button && $0.accessibleText == "Agent Research, Completed"
        }
        let interactiveChildButton = elements.first {
            $0.role == .button && $0.accessibleText == "Tool Search, Completed"
        }
        let contentlessChild = elements.first {
            $0.accessibleText == "Tool Summarize, Completed"
        }
        let contentlessChildButton = elements.first {
            $0.role == .button && $0.accessibleText == "Tool Summarize, Completed"
        }

        #expect(parentButton != nil)
        #expect(parentButton?.value as? String == "Expanded")
        #expect(parentButton?.help == "Collapse details")
        #expect(interactiveChildButton != nil)
        #expect(interactiveChildButton?.value as? String == "Collapsed")
        #expect(interactiveChildButton?.help == "Expand details")
        #expect(parentButton?.object !== interactiveChildButton?.object)
        #expect(contentlessChild != nil)
        #expect(contentlessChildButton == nil)
        #expect(contentlessChild?.role != .button)
        #expect(contentlessChild?.value as? String != "Collapsed")
        #expect(contentlessChild?.help != "Expand details")
    }

    @Test func agentArgumentsDoNotRenderInputWhileToolArgumentsDo() {
        NSApplication.shared.finishLaunching()
        enableInProcessAccessibilityHierarchy()

        let replayArguments = #"{"reason":"Route the request to the research agent"}"#
        let agentDetails = "Delegated by the coordinator"
        let agent = ChatToolCall(
            id: "agent",
            name: "Research",
            kind: .agent,
            arguments: replayArguments,
            status: .success,
            details: agentDetails
        )
        let argumentsOnlyAgent = ChatToolCall(
            id: "arguments-only-agent",
            name: "Replay",
            kind: .agent,
            arguments: replayArguments,
            status: .success
        )
        let tool = ChatToolCall(
            id: "tool",
            name: "Search",
            arguments: replayArguments,
            status: .success
        )

        let agentElements = renderedAccessibilityElements(for: agent, waitingFor: agentDetails)
        let argumentsOnlyAgentElements = renderedAccessibilityElements(
            for: argumentsOnlyAgent,
            waitingFor: "Agent Replay, Completed"
        )
        let toolElements = renderedAccessibilityElements(for: tool, waitingFor: replayArguments)
        let agentTexts = agentElements.compactMap(\.accessibleText)
        let argumentsOnlyAgentTexts = argumentsOnlyAgentElements.compactMap(\.accessibleText)
        let toolTexts = toolElements.compactMap(\.accessibleText)

        #expect(agentTexts.contains("Agent Research, Completed"))
        #expect(agentTexts.contains(agentDetails))
        #expect(!agentTexts.contains("Input"))
        #expect(!agentTexts.contains(replayArguments))
        #expect(argumentsOnlyAgentTexts.contains("Agent Replay, Completed"))
        #expect(!argumentsOnlyAgentTexts.contains("Input"))
        #expect(!argumentsOnlyAgentTexts.contains(replayArguments))
        #expect(!argumentsOnlyAgentElements.contains {
            $0.role == .button && $0.accessibleText == "Agent Replay, Completed"
        })
        #expect(toolTexts.contains("Tool Search, Completed"))
        #expect(toolTexts.contains("Input"))
        #expect(toolTexts.contains(replayArguments))
    }

    private func renderedAccessibilityElements(
        for toolCall: ChatToolCall,
        waitingFor expectedText: String
    ) -> [AccessibilityElement] {
        let host = NSHostingView(
            rootView: ToolCallView(toolCall: toolCall, isExpanded: true)
                .frame(width: 420, alignment: .leading)
        )
        host.frame = NSRect(x: 0, y: 0, width: 420, height: 240)

        let window = NSWindow(
            contentRect: host.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        window.orderFront(nil)
        defer {
            window.orderOut(nil)
            window.contentView = nil
        }

        return accessibilityTree(from: host) { elements in
            elements.contains { $0.accessibleText == expectedText }
        }
    }

    private func enableInProcessAccessibilityHierarchy() {
        let application = NSApplication.shared
        let selector = NSSelectorFromString("accessibilitySetEnhancedUserInterfaceAttribute:")
        #expect(application.responds(to: selector))
        guard application.responds(to: selector) else { return }
        _ = application.perform(selector, with: NSNumber(value: true))
    }

    private func accessibilityTree(
        from root: NSView,
        timeout: TimeInterval = 1,
        until condition: ([AccessibilityElement]) -> Bool
    ) -> [AccessibilityElement] {
        let deadline = Date().addingTimeInterval(timeout)
        var elements: [AccessibilityElement] = []

        repeat {
            root.layoutSubtreeIfNeeded()
            elements = accessibilityTree(from: root as Any)
            if condition(elements) {
                return elements
            }
            _ = RunLoop.current.run(mode: .default, before: min(deadline, Date().addingTimeInterval(0.01)))
        } while Date() < deadline

        return elements
    }

    private func accessibilityTree(from root: Any) -> [AccessibilityElement] {
        guard let object = root as? NSObject else { return [] }

        let element = AccessibilityElement(
            object: object,
            role: accessibilityAttribute("accessibilityRole", from: object) as? NSAccessibility.Role,
            label: accessibilityAttribute("accessibilityLabel", from: object) as? String,
            value: accessibilityAttribute("accessibilityValue", from: object),
            help: accessibilityAttribute("accessibilityHelp", from: object) as? String
        )
        let children = accessibilityAttribute("accessibilityChildren", from: object) as? [Any] ?? []
        return [element] + children.flatMap(accessibilityTree)
    }

    private func accessibilityAttribute(_ name: String, from object: NSObject) -> Any? {
        let selector = NSSelectorFromString(name)
        guard object.responds(to: selector) else { return nil }
        return object.perform(selector)?.takeUnretainedValue()
    }
}

private struct AccessibilityElement {
    let object: NSObject
    let role: NSAccessibility.Role?
    let label: String?
    let value: Any?
    let help: String?

    var accessibleText: String? {
        label ?? value as? String
    }
}
#endif
