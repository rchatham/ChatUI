//
//  ToolCallView.swift
//  ChatUI
//
//  Created by Reid Chatham on 9/14/25.
//

import SwiftUI

struct ToolCallView: View {
    let toolCall: ChatToolCall
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    statusIcon
                    Text(toolCall.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(toolCall.status.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                if let arguments = toolCall.arguments, !arguments.isEmpty {
                    detail(title: "Input", value: arguments)
                }
                if let result = toolCall.result, !result.isEmpty {
                    detail(title: toolCall.status == .failure ? "Error" : "Output", value: result)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tool \(toolCall.name), \(toolCall.status.label)")
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

private extension ChatToolCall.Status {
    var label: String {
        switch self {
        case .pending:
            "Running"
        case .success:
            "Completed"
        case .failure:
            "Failed"
        }
    }

    var symbolName: String {
        switch self {
        case .pending:
            "wrench.and.screwdriver"
        case .success:
            "checkmark.circle.fill"
        case .failure:
            "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .pending:
            .secondary
        case .success:
            .green
        case .failure:
            .red
        }
    }
}