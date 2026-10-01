//
//  ToolCallView.swift
//  ChatUI
//
//  Created by Reid Chatham on 9/14/25.
//

import SwiftUI

struct ToolCallExpansionRoute: Hashable {
    struct Segment: Hashable {
        let index: Int
        let id: String
    }

    let messageID: UUID
    let segments: [Segment]

    init(messageID: UUID, index: Int, toolCallID: String) {
        self.messageID = messageID
        self.segments = [Segment(index: index, id: toolCallID)]
    }

    private init(messageID: UUID, segments: [Segment]) {
        self.messageID = messageID
        self.segments = segments
    }

    func appending(index: Int, toolCallID: String) -> ToolCallExpansionRoute {
        ToolCallExpansionRoute(
            messageID: messageID,
            segments: segments + [Segment(index: index, id: toolCallID)]
        )
    }

    var parent: ToolCallExpansionRoute? {
        guard segments.count > 1 else { return nil }
        return ToolCallExpansionRoute(messageID: messageID, segments: Array(segments.dropLast()))
    }

    func contains(_ route: ToolCallExpansionRoute) -> Bool {
        messageID == route.messageID
            && segments.count <= route.segments.count
            && zip(segments, route.segments).allSatisfy(==)
    }

    var accessibilityIdentifier: String {
        let path = segments.map { "\($0.index)-\($0.id)" }.joined(separator: "/")
        return "tool-call-\(messageID.uuidString)-\(path)"
    }
}

struct ToolCallView: View {
    let toolCall: ChatToolCall
    @State private var standaloneIsExpanded: Bool
    private let route: ToolCallExpansionRoute?
    private let expandedRoute: Binding<ToolCallExpansionRoute?>?

    init(toolCall: ChatToolCall, isExpanded: Bool = false) {
        self.toolCall = toolCall
        self._standaloneIsExpanded = State(initialValue: isExpanded)
        self.route = nil
        self.expandedRoute = nil
    }

    init(
        toolCall: ChatToolCall,
        route: ToolCallExpansionRoute,
        expandedRoute: Binding<ToolCallExpansionRoute?>
    ) {
        self.toolCall = toolCall
        self._standaloneIsExpanded = State(initialValue: false)
        self.route = route
        self.expandedRoute = expandedRoute
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if hasDisclosureContent {
                Button(action: toggleExpansionWithAnimation) {
                    header
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .disclosureLabelTouchTarget(minHeight: 44)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier(accessibilityIdentifier)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
                .accessibilityHint(isExpanded ? "Collapse details" : "Expand details")
            } else {
                header
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(accessibilityLabel)
            }

            if hasDisclosureContent && isExpanded {
                Divider()
                    .allowsHitTesting(false)
                if let details = toolCall.details, !details.isEmpty {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .allowsHitTesting(false)
                }
                if toolCall.kind == .tool,
                   let arguments = toolCall.arguments,
                   !arguments.isEmpty {
                    detail(title: "Input", value: arguments)
                }
                if !toolCall.children.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(toolCall.children.enumerated()), id: \.offset) { index, child in
                            childView(child, index: index)
                        }
                    }
                    .padding(.leading, 12)
                    .overlay(
                        Rectangle()
                            .frame(width: 2)
                            .foregroundStyle(Color.secondary.opacity(0.2))
                            .allowsHitTesting(false),
                        alignment: .leading
                    )
                }
                if let result = toolCall.result, !result.isEmpty {
                    detail(title: toolCall.status == .failure ? "Error" : "Output", value: result)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if hasDisclosureContent && isExpanded {
                Button(action: toggleExpansionWithAnimation) {
                    Color.clear
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHidden(true)
            }
        }
    }

    private var isExpanded: Bool {
        guard let route, let expandedRoute else { return standaloneIsExpanded }
        guard let currentRoute = expandedRoute.wrappedValue else { return false }
        return route.contains(currentRoute)
    }

    private var accessibilityIdentifier: String {
        route?.accessibilityIdentifier ?? "tool-call-\(toolCall.id)"
    }

    private func toggleExpansionWithAnimation() {
        withAnimation(.easeInOut(duration: 0.2)) {
            toggleExpansion()
        }
    }

    private func toggleExpansion() {
        guard let route, let expandedRoute else {
            standaloneIsExpanded.toggle()
            return
        }

        expandedRoute.wrappedValue = isExpanded ? route.parent : route
    }

    @ViewBuilder
    private func childView(_ child: ChatToolCall, index: Int) -> some View {
        if let route, let expandedRoute {
            ToolCallView(
                toolCall: child,
                route: route.appending(index: index, toolCallID: child.id),
                expandedRoute: expandedRoute
            )
        } else {
            ToolCallView(toolCall: child)
        }
    }

    private var hasDisclosureContent: Bool {
        !(toolCall.details?.isEmpty ?? true)
            || (toolCall.kind == .tool && !(toolCall.arguments?.isEmpty ?? true))
            || !(toolCall.result?.isEmpty ?? true)
            || !toolCall.children.isEmpty
    }

    private var accessibilityLabel: String {
        "\(toolCall.kind.accessibilityLabel) \(toolCall.name), \(toolCall.status.label)"
    }

    private var header: some View {
        HStack(spacing: 6) {
            statusIcon
                .accessibilityHidden(true)
            Image(systemName: toolCall.kind.iconName)
                .font(.subheadline)
                .foregroundStyle(toolCall.kind.iconTint)
            Text(toolCall.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(toolCall.status.label)
                .font(.caption)
                .foregroundStyle(.secondary)
            if hasDisclosureContent {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        if toolCall.status == .pending {
            ProgressView()
                .controlSize(.small)
                .tint(toolCall.status.tint)
        } else {
            Image(systemName: toolCall.status.symbolName)
                .font(.subheadline)
                .foregroundStyle(toolCall.status.tint)
        }
    }

    private func detail(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .allowsHitTesting(false)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private extension View {
    /// Keeps the full-width disclosure shape inside the button label and adds
    /// the minimum touch height only on touch platforms.
    @ViewBuilder
    func disclosureLabelTouchTarget(minHeight: CGFloat) -> some View {
        #if os(iOS) || os(watchOS)
        frame(minHeight: minHeight, alignment: .leading)
            .contentShape(Rectangle())
        #else
        contentShape(Rectangle())
        #endif
    }
}

private extension ChatToolCall.Status {
    var label: String {
        switch self {
        case .pending: "Running"
        case .success: "Completed"
        case .failure: "Failed"
        }
    }
    var symbolName: String {
        switch self {
        case .pending: "wrench.and.screwdriver"
        case .success: "checkmark.circle.fill"
        case .failure: "exclamationmark.triangle.fill"
        }
    }
    var tint: Color {
        switch self {
        case .pending: .secondary
        case .success: .green
        case .failure: .red
        }
    }
}

private extension ChatToolCall.Kind {
    var iconName: String {
        switch self {
        case .tool: "wrench.and.screwdriver"
        case .agent: "person.crop.circle.badge.checkmark"
        }
    }
    var iconTint: Color {
        switch self {
        case .tool: .secondary
        case .agent: .accentColor
        }
    }
    var accessibilityLabel: String {
        switch self {
        case .tool: "Tool"
        case .agent: "Agent"
        }
    }
}