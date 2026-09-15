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
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    if toolCall.status == .pending {
                        ProgressView()
                            .controlSize(.small)
                            .tint(toolCall.status.tint)
                    } else {
                        Image(systemName: toolCall.status.symbolName)
                            .foregroundStyle(toolCall.status.tint)
                    }
                    Text(toolCall.name)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(toolCall.status.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                if let arguments = toolCall.arguments, !arguments.isEmpty {
                    detail(title: "Input", value: arguments)
                }
                if let result = toolCall.result, !result.isEmpty {
                    detail(title: toolCall.status == .failure ? "Error" : "Output", value: result)
                }
            }
        }
        .padding(10)
        .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tool \(toolCall.name), \(toolCall.status.label)")
    }

    private func detail(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
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
