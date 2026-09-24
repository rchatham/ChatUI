//
//  ToolCallView.swift
//  ChatUI
//
//  Created by Reid Chatham on 9/14/25.
//

import SwiftUI

struct ToolCallView: View {
    let toolCall: ChatToolCall
    @State private var isExpanded: Bool

    init(toolCall: ChatToolCall, isExpanded: Bool = false) {
        self.toolCall = toolCall
        self._isExpanded = State(initialValue: isExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if hasDisclosureContent {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    header
                }
                .buttonStyle(.plain)
                .touchTarget(minHeight: 44)
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
                if let details = toolCall.details, !details.isEmpty {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if toolCall.kind == .tool,
                   let arguments = toolCall.arguments,
                   !arguments.isEmpty {
                    detail(title: "Input", value: arguments)
                }
                if let result = toolCall.result, !result.isEmpty {
                    detail(title: toolCall.status == .failure ? "Error" : "Output", value: result)
                }
                if !toolCall.children.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(toolCall.children) { child in
                            ToolCallView(toolCall: child)
                        }
                    }
                    .padding(.leading, 12)
                    .overlay(
                        Rectangle().frame(width: 2).foregroundStyle(Color.secondary.opacity(0.2)),
                        alignment: .leading
                    )
                }
            }
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
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private extension View {
    /// Guarantees a minimum tap target on touch platforms; macOS keeps its
    /// intrinsic compact layout.
    @ViewBuilder
    func touchTarget(minHeight: CGFloat) -> some View {
        #if os(iOS) || os(watchOS)
        frame(minHeight: minHeight)
            .contentShape(Rectangle())
        #else
        self
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