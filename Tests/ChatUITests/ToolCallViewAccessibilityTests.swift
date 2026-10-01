//
//  ToolCallViewAccessibilityTests.swift
//  ChatUITests
//
//  Verifies nested tool-call controls remain independently accessible.
//

#if canImport(AppKit)
import AppKit
import Combine
import SwiftUI
import Testing
@testable import ChatUI

@Suite(.serialized)
@MainActor
struct ToolCallViewAccessibilityTests {

    @Test func pendingToolCallStartsCollapsed() throws {
        let message = AccessibilityMessage(
            uuid: uuid("00000000-0000-0000-0000-000000000001"),
            toolCalls: [
                ChatToolCall(
                    id: "pending",
                    name: "Pending",
                    status: .pending,
                    details: "Pending details"
                )
            ]
        )
        let hosted = hostMessageList(messages: [message])
        defer { hosted.close() }

        let elements = hosted.elements(waitingForButton: "Tool Pending, Running")
        let pending = try #require(elements.first {
            $0.role == .button && $0.accessibleText == "Tool Pending, Running"
        })

        #expect(pending.value as? String == "Collapsed")
        #expect(!elements.contains { $0.accessibleText == "Pending details" })
    }

    @Test func clickingBlankHeaderRegionTogglesDisclosure() throws {
        let toolCall = ChatToolCall(
            id: "wide-header",
            name: "A",
            status: .success,
            details: "Expanded details"
        )
        let hosted = AccessibilityHost(
            rootView: ToolCallView(toolCall: toolCall),
            width: 420,
            height: 120
        )
        defer { hosted.close() }

        try hosted.click(
            blankRegionOfButton: "Tool A, Completed",
            waitingForValue: "Expanded"
        )

        let elements = hosted.elements(waitingFor: "Expanded details")
        #expect(elements.first { $0.accessibleText == "Tool A, Completed" }?.value as? String == "Expanded")
    }

    @Test func clickingExpandedNonselectableDetailsCollapsesDisclosure() throws {
        let toolCall = ChatToolCall(
            id: "details",
            name: "Details",
            status: .success,
            details: "Tap this nonselectable summary"
        )
        let hosted = AccessibilityHost(
            rootView: ToolCallView(toolCall: toolCall, isExpanded: true),
            width: 420,
            height: 160
        )
        defer { hosted.close() }

        try hosted.click(
            elementWithText: "Tap this nonselectable summary",
            disclosureLabel: "Tool Details, Completed",
            waitingForValue: "Collapsed"
        )

        let elements = hosted.elements(waitingForButton: "Tool Details, Completed")
        #expect(!elements.contains { $0.accessibleText == "Tap this nonselectable summary" })
    }

    @Test func coordinateClickOnNestedHeaderDoesNotCollapseParent() throws {
        let parent = ChatToolCall(
            id: "parent",
            name: "Parent",
            kind: .agent,
            status: .success,
            children: [
                ChatToolCall(
                    id: "child",
                    name: "Child",
                    status: .success,
                    details: "Child details"
                )
            ]
        )
        let hosted = AccessibilityHost(
            rootView: ToolCallView(toolCall: parent, isExpanded: true),
            width: 420,
            height: 240
        )
        defer { hosted.close() }

        try hosted.click(
            blankRegionOfButton: "Tool Child, Completed",
            waitingForValue: "Expanded"
        )

        let elements = hosted.elements(waitingFor: "Child details")
        #expect(elements.first { $0.accessibleText == "Agent Parent, Completed" }?.value as? String == "Expanded")
        #expect(elements.first { $0.accessibleText == "Tool Child, Completed" }?.value as? String == "Expanded")
    }

    @Test func standaloneExpandedParentDoesNotAutoExpandPendingChild() throws {
        try expectStandaloneChildCollapsed(status: .pending, statusLabel: "Running")
    }

    @Test func standaloneExpandedParentDoesNotAutoExpandCompletedChild() throws {
        try expectStandaloneChildCollapsed(status: .success, statusLabel: "Completed")
    }

    @Test func openingSameLevelSiblingClosesPreviouslyExpandedCard() throws {
        let message = AccessibilityMessage(
            uuid: uuid("00000000-0000-0000-0000-000000000002"),
            toolCalls: [
                ChatToolCall(id: "duplicate", name: "First", status: .success, details: "First details"),
                ChatToolCall(id: "duplicate", name: "Second", status: .success, details: "Second details")
            ]
        )
        let hosted = hostMessageList(messages: [message])
        defer { hosted.close() }

        try hosted.press(label: "Tool First, Completed", waitingForValue: "Expanded")
        var elements = hosted.elements(waitingFor: "First details")
        #expect(elements.first { $0.accessibleText == "Tool First, Completed" }?.value as? String == "Expanded")
        #expect(elements.first { $0.accessibleText == "Tool Second, Completed" }?.value as? String == "Collapsed")

        try hosted.press(label: "Tool Second, Completed", waitingForValue: "Expanded")
        elements = hosted.elements(waitingFor: "Second details")
        let first = elements.first { $0.accessibleText == "Tool First, Completed" }
        let second = elements.first { $0.accessibleText == "Tool Second, Completed" }
        #expect(first?.value as? String == "Collapsed")
        #expect(second?.value as? String == "Expanded")
        #expect(first?.identifier != second?.identifier)
        #expect(!elements.contains { $0.accessibleText == "First details" })
    }

    @Test func openingNestedSiblingKeepsAncestorExpanded() throws {
        let message = AccessibilityMessage(
            uuid: uuid("00000000-0000-0000-0000-000000000003"),
            toolCalls: [
                ChatToolCall(
                    id: "parent",
                    name: "Parent",
                    kind: .agent,
                    status: .success,
                    children: [
                        ChatToolCall(id: "child-a", name: "Child A", status: .success, details: "A details"),
                        ChatToolCall(id: "child-b", name: "Child B", status: .success, details: "B details")
                    ]
                )
            ]
        )
        let hosted = hostMessageList(messages: [message], height: 420)
        defer { hosted.close() }

        try hosted.press(label: "Agent Parent, Completed", waitingForValue: "Expanded")
        try hosted.press(label: "Tool Child A, Completed", waitingForValue: "Expanded")
        try hosted.press(label: "Tool Child B, Completed", waitingForValue: "Expanded")
        let elements = hosted.elements(waitingFor: "B details")

        #expect(elements.first { $0.accessibleText == "Agent Parent, Completed" }?.value as? String == "Expanded")
        #expect(elements.first { $0.accessibleText == "Tool Child A, Completed" }?.value as? String == "Collapsed")
        #expect(elements.first { $0.accessibleText == "Tool Child B, Completed" }?.value as? String == "Expanded")
        #expect(!elements.contains { $0.accessibleText == "A details" })
    }

    @Test func topLevelAccordionCoordinatesAcrossMessages() throws {
        let firstMessage = AccessibilityMessage(
            uuid: uuid("00000000-0000-0000-0000-000000000004"),
            toolCalls: [ChatToolCall(id: "duplicate", name: "Message One", status: .success, details: "One details")]
        )
        let secondMessage = AccessibilityMessage(
            uuid: uuid("00000000-0000-0000-0000-000000000005"),
            toolCalls: [ChatToolCall(id: "duplicate", name: "Message Two", status: .success, details: "Two details")]
        )
        let hosted = hostMessageList(messages: [firstMessage, secondMessage], height: 420)
        defer { hosted.close() }

        try hosted.press(label: "Tool Message One, Completed", waitingForValue: "Expanded")
        try hosted.press(label: "Tool Message Two, Completed", waitingForValue: "Expanded")
        let elements = hosted.elements(waitingFor: "Two details")
        let first = try #require(elements.first { $0.accessibleText == "Tool Message One, Completed" })
        let second = try #require(elements.first { $0.accessibleText == "Tool Message Two, Completed" })

        #expect(first.value as? String == "Collapsed")
        #expect(second.value as? String == "Expanded")
        #expect(first.identifier != second.identifier)
        #expect(!elements.contains { $0.accessibleText == "One details" })
    }

    @Test func toolOnlyMessageOmitsEmptyBubbleWhileLegacyChildrenKeepDisclosure() throws {
        let toolOnlyID = uuid("00000000-0000-0000-0000-000000000006")
        let legacyID = uuid("00000000-0000-0000-0000-000000000007")
        let toolOnly = AccessibilityMessage(
            uuid: toolOnlyID,
            toolCalls: [ChatToolCall(id: "tool", name: "Visible Tool", status: .pending, details: "Input")]
        )
        let legacy = AccessibilityMessage(
            uuid: legacyID,
            children: [AccessibilityMessage(text: "Legacy child")]
        )
        let hosted = hostMessageList(messages: [toolOnly, legacy], height: 420)
        defer { hosted.close() }

        let elements = hosted.elements(waitingFor: "Tool Visible Tool, Running")

        #expect(!elements.contains { $0.identifier == "message-bubble-\(toolOnlyID.uuidString)" })
        let legacyDisclosure = elements.first {
            $0.identifier == "message-bubble-\(legacyID.uuidString)" && $0.role == .button
        }
        #expect(legacyDisclosure?.accessibleText == "Replies")
        #expect(legacyDisclosure?.value as? String == "Collapsed")
        #expect(legacyDisclosure?.help == "Show replies")
        #expect(elements.contains { $0.accessibleText == "Tool Visible Tool, Running" })

        try hosted.press(
            identifier: "message-bubble-\(legacyID.uuidString)",
            waitingForText: "Legacy child"
        )
        let expandedElements = hosted.elements(waitingFor: "Legacy child")
        let expandedDisclosure = expandedElements.first {
            $0.identifier == "message-bubble-\(legacyID.uuidString)"
        }
        #expect(expandedDisclosure?.accessibleText == "Replies")
        #expect(expandedDisclosure?.value as? String == "Expanded")
        #expect(expandedDisclosure?.help == "Hide replies")
        #expect(expandedElements.contains { $0.accessibleText == "Legacy child" })
    }

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

    @Test func nestedActivityPrecedesParentOutput() throws {
        let parentResult = "Parent final result"
        let message = AccessibilityMessage(
            uuid: uuid("00000000-0000-0000-0000-000000000008"),
            toolCalls: [
                ChatToolCall(
                    id: "parent",
                    name: "Coordinator",
                    kind: .agent,
                    status: .success,
                    result: parentResult,
                    children: [
                        ChatToolCall(
                            id: "delegate",
                            name: "Research",
                            kind: .agent,
                            status: .success,
                            children: [
                                ChatToolCall(
                                    id: "grandchild",
                                    name: "Search",
                                    kind: .tool,
                                    arguments: #"{"query":"chronology"}"#,
                                    status: .success,
                                    result: "source"
                                )
                            ]
                        )
                    ]
                )
            ]
        )
        let hosted = hostMessageList(messages: [message], height: 420)
        defer { hosted.close() }

        try hosted.press(label: "Agent Coordinator, Completed", waitingForValue: "Expanded")
        try hosted.press(label: "Agent Research, Completed", waitingForValue: "Expanded")
        let elements = hosted.elements(waitingFor: parentResult)
        let texts = elements.compactMap(\.accessibleText)
        let delegateIndex = try #require(texts.firstIndex(of: "Agent Research, Completed"))
        let grandchildIndex = try #require(texts.firstIndex(of: "Tool Search, Completed"))
        let outputIndex = try #require(texts.firstIndex(of: "Output"))
        let resultIndex = try #require(texts.firstIndex(of: parentResult))

        #expect(delegateIndex < grandchildIndex)
        #expect(grandchildIndex < outputIndex)
        #expect(outputIndex < resultIndex)
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

    private func expectStandaloneChildCollapsed(
        status: ChatToolCall.Status,
        statusLabel: String
    ) throws {
        let parent = ChatToolCall(
            id: "parent",
            name: "Parent",
            kind: .agent,
            status: .success,
            children: [
                ChatToolCall(
                    id: "child",
                    name: "Child",
                    kind: .agent,
                    status: status,
                    details: "Child details"
                )
            ]
        )
        let childLabel = "Agent Child, \(statusLabel)"
        let elements = renderedAccessibilityElements(
            for: parent,
            waitingFor: childLabel
        )
        let child = try #require(elements.first {
            $0.role == .button && $0.accessibleText == childLabel
        })

        #expect(child.value as? String == "Collapsed")
        #expect(!elements.contains { $0.accessibleText == "Child details" })
    }

    private func renderedAccessibilityElements(
        for toolCall: ChatToolCall,
        waitingFor expectedText: String,
        height: CGFloat = 240
    ) -> [AccessibilityElement] {
        let host = NSHostingView(
            rootView: ToolCallView(toolCall: toolCall, isExpanded: true)
                .frame(width: 420, alignment: .leading)
        )
        host.frame = NSRect(x: 0, y: 0, width: 420, height: height)

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

    private func hostMessageList(
        messages: [AccessibilityMessage],
        height: CGFloat = 320
    ) -> AccessibilityHost {
        NSApplication.shared.finishLaunching()
        enableInProcessAccessibilityHierarchy()
        let service = AccessibilityMessageService(messages: messages)
        let view = MessageListView(
            viewModel: MessageListView<AccessibilityMessageService>.ViewModel(messageService: service),
            composerViewModel: MessageComposerView.ViewModel(messageService: service),
            supplementaryContent: nil
        )
        return AccessibilityHost(rootView: view, height: height)
    }

    private func uuid(_ value: String) -> UUID {
        UUID(uuidString: value)!
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
            help: accessibilityAttribute("accessibilityHelp", from: object) as? String,
            identifier: accessibilityAttribute("accessibilityIdentifier", from: object) as? String
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
    let identifier: String?

    var accessibleText: String? {
        label ?? value as? String
    }
}

@MainActor
private final class AccessibilityHost {
    private let host: NSHostingView<AnyView>
    private let window: NSWindow

    init<Content: View>(rootView: Content, width: CGFloat = 520, height: CGFloat) {
        NSApplication.shared.finishLaunching()
        let selector = NSSelectorFromString("accessibilitySetEnhancedUserInterfaceAttribute:")
        if NSApplication.shared.responds(to: selector) {
            _ = NSApplication.shared.perform(selector, with: NSNumber(value: true))
        }

        host = NSHostingView(rootView: AnyView(rootView.frame(width: width, alignment: .leading)))
        host.frame = NSRect(x: 0, y: 0, width: width, height: height)
        window = NSWindow(
            contentRect: host.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        window.orderFront(nil)
    }

    func close() {
        window.orderOut(nil)
        window.contentView = nil
    }

    func press(label: String, waitingForValue expectedValue: String) throws {
        let button = try #require(elements(waitingFor: label).first {
            $0.role == .button && $0.accessibleText == label
        })
        performPress(button)
        let updatedElements = elements { elements in
            elements.first { $0.accessibleText == label }?.value as? String == expectedValue
        }
        #expect(updatedElements.first { $0.accessibleText == label }?.value as? String == expectedValue)
    }

    func press(identifier: String, waitingForText expectedText: String) throws {
        let button = try #require(elements { elements in
            elements.contains { $0.role == .button && $0.identifier == identifier }
        }.first {
            $0.role == .button && $0.identifier == identifier
        })
        performPress(button)
        let updatedElements = elements(waitingFor: expectedText)
        #expect(updatedElements.contains { $0.accessibleText == expectedText })
    }

    func click(blankRegionOfButton label: String, waitingForValue expectedValue: String) throws {
        let button = try #require(elements(waitingForButton: label).first {
            $0.role == .button && $0.accessibleText == label
        })
        let frame = try #require(accessibilityFrame(of: button.object))
        #expect(frame.width > 300)

        let screenPoint = NSPoint(x: frame.midX, y: frame.midY)
        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        sendMouseEvent(type: .leftMouseDown, at: windowPoint, clickCount: 1)
        sendMouseEvent(type: .leftMouseUp, at: windowPoint, clickCount: 1)

        let updatedElements = elements { elements in
            elements.first { $0.accessibleText == label }?.value as? String == expectedValue
        }
        #expect(updatedElements.first { $0.accessibleText == label }?.value as? String == expectedValue)
    }

    func click(
        elementWithText text: String,
        disclosureLabel: String,
        waitingForValue expectedValue: String
    ) throws {
        let element = try #require(elements(waitingFor: text).first {
            $0.accessibleText == text
        })
        let frame = try #require(accessibilityFrame(of: element.object))
        let screenPoint = NSPoint(x: frame.midX, y: frame.midY)
        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        sendMouseEvent(type: .leftMouseDown, at: windowPoint, clickCount: 1)
        sendMouseEvent(type: .leftMouseUp, at: windowPoint, clickCount: 1)

        let updatedElements = elements { elements in
            elements.first { $0.accessibleText == disclosureLabel }?.value as? String == expectedValue
        }
        #expect(updatedElements.first { $0.accessibleText == disclosureLabel }?.value as? String == expectedValue)
    }

    func elements(waitingFor text: String) -> [AccessibilityElement] {
        elements { elements in elements.contains { $0.accessibleText == text } }
    }

    func elements(waitingForButton label: String) -> [AccessibilityElement] {
        elements { elements in
            elements.contains { $0.role == .button && $0.accessibleText == label }
        }
    }

    private func performPress(_ button: AccessibilityElement) {
        let pressSelector = NSSelectorFromString("accessibilityPerformPress")
        #expect(button.object.responds(to: pressSelector))
        _ = button.object.perform(pressSelector)
    }

    private func accessibilityFrame(of object: NSObject) -> NSRect? {
        guard object.responds(to: NSSelectorFromString("accessibilityFrame")) else { return nil }
        return (object.value(forKey: "accessibilityFrame") as? NSValue)?.rectValue
    }

    private func sendMouseEvent(type: NSEvent.EventType, at point: NSPoint, clickCount: Int) {
        guard let event = NSEvent.mouseEvent(
            with: type,
            location: point,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: clickCount,
            pressure: type == .leftMouseDown ? 1 : 0
        ) else {
            Issue.record("Failed to create mouse event")
            return
        }
        window.sendEvent(event)
    }

    private func elements(
        timeout: TimeInterval = 1,
        until condition: ([AccessibilityElement]) -> Bool
    ) -> [AccessibilityElement] {
        let deadline = Date().addingTimeInterval(timeout)
        var elements: [AccessibilityElement] = []

        repeat {
            host.layoutSubtreeIfNeeded()
            elements = accessibilityTree(from: host as Any)
            if condition(elements) { return elements }
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
            help: accessibilityAttribute("accessibilityHelp", from: object) as? String,
            identifier: accessibilityAttribute("accessibilityIdentifier", from: object) as? String
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

private final class AccessibilityMessage: ChatMessageInfo, @unchecked Sendable {
    let uuid: UUID
    let id: UUID
    let text: String?
    let toolCalls: [ChatToolCall]
    let childChatMessages: [AccessibilityMessage]
    let isUser: Bool
    let isAssistant: Bool
    let isAgentEvent: Bool
    let objectWillChange = ObservableObjectPublisher()

    init(
        uuid: UUID = UUID(),
        text: String? = nil,
        toolCalls: [ChatToolCall] = [],
        children: [AccessibilityMessage] = [],
        isUser: Bool = false,
        isAssistant: Bool = true,
        isAgentEvent: Bool = false
    ) {
        self.uuid = uuid
        self.id = uuid
        self.text = text
        self.toolCalls = toolCalls
        self.childChatMessages = children
        self.isUser = isUser
        self.isAssistant = isAssistant
        self.isAgentEvent = isAgentEvent
    }

    static func == (lhs: AccessibilityMessage, rhs: AccessibilityMessage) -> Bool {
        lhs.uuid == rhs.uuid
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }
}

private final class AccessibilityMessageService: ChatMessageService, @unchecked Sendable {
    @Published var chatMessages: [AccessibilityMessage]

    init(messages: [AccessibilityMessage]) {
        self.chatMessages = messages
    }

    func send(message: String, stream: Bool) async throws {}
    func handleError(error: any Error) -> ChatAlertInfo? { nil }
    func deleteMessage(id: UUID) {
        chatMessages.removeAll { $0.uuid == id }
    }
}
#endif
