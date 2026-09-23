//
//  ToolCallViewSnapshotTests.swift
//  ChatUITests
//
//  Renders ToolCallView in representative states to PNG files for visual review.
//

import SwiftUI
import Testing
@testable import ChatUI

@MainActor
struct ToolCallViewSnapshotTests {

    private let outputDir = "/tmp/chatui-toolcall-screenshots"

    init() {
        try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
    }

    @Test func renderToolPending() async throws {
        let view = ToolCallView(toolCall: ChatToolCall(id: "t1", name: "calculate", kind: .tool, arguments: #"{"expression":"1+1"}"#, status: .pending))
        try render(view, name: "tool-pending", width: 420)
    }

    @Test func renderToolSuccess() async throws {
        let view = ToolCallView(toolCall: ChatToolCall(id: "t1", name: "calculate", kind: .tool, arguments: #"{"expression":"(2+3)*4"}"#, status: .success, result: "20"))
        try render(view, name: "tool-success", width: 420)
    }

    @Test func renderToolFailure() async throws {
        let view = ToolCallView(toolCall: ChatToolCall(id: "t1", name: "calculate", kind: .tool, arguments: #"{"expression":"1/0"}"#, status: .failure, result: "division by zero"))
        try render(view, name: "tool-failure", width: 420)
    }

    @Test func renderAgentWithChildren() async throws {
        let agent = ChatToolCall(
            id: "a1", name: "CalendarAgent", kind: .agent, status: .success, details: "started: list today's events",
            children: [
                ChatToolCall(id: "c1", name: "list_events", kind: .tool, arguments: #"{"calendar":"primary"}"#, status: .success, result: "3 events"),
                ChatToolCall(id: "c2", name: "create_event", kind: .tool, arguments: #"{"title":"Lunch"}"#, status: .success, result: "created")
            ]
        )
        let view = ToolCallView(toolCall: agent)
        try render(view, name: "agent-with-children", width: 460)
    }

    @Test func renderAgentDelegation() async throws {
        let main = ChatToolCall(
            id: "m1", name: "Main", kind: .agent, status: .success, details: "started: plan the trip",
            children: [
                ChatToolCall(id: "d1", name: "Research", kind: .agent, status: .success, details: "delegated: find flights",
                              children: [
                                ChatToolCall(id: "t1", name: "search", kind: .tool, arguments: #"{"q":"flights"}"#, status: .success, result: "5 results")
                              ])
            ]
        )
        let view = ToolCallView(toolCall: main)
        try render(view, name: "agent-delegation", width: 480)
    }

    @Test func renderAgentPendingRunningChild() async throws {
        let agent = ChatToolCall(
            id: "a1", name: "CalendarAgent", kind: .agent, status: .pending, details: "started: list events",
            children: [
                ChatToolCall(id: "c1", name: "list_events", kind: .tool, arguments: #"{"calendar":"primary"}"#, status: .pending)
            ]
        )
        let view = ToolCallView(toolCall: agent)
        try render(view, name: "agent-pending-running-child", width: 460)
    }

    @MainActor
    private func render(_ view: ToolCallView, name: String, width: CGFloat) throws {
        let host = view
            .frame(width: width, alignment: .leading)
            .padding(16)
            .background(Color.white)
        let renderer = ImageRenderer(content: host)
        renderer.scale = 2
        #if canImport(AppKit)
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            Issue.record("Failed to render \(name)")
            return
        }
        let url = URL(fileURLWithPath: "\(outputDir)/\(name).png")
        try png.write(to: url)
        print("📸 wrote \(url.path)")
        #else
        Issue.record("Screenshot rendering requires macOS/AppKit host")
        #endif
    }
}

#if canImport(AppKit)
import AppKit
#endif