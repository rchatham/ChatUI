//
//  RealtimeConversationView.swift
//  ChatUI
//
//  Created by Reid Chatham on 11/6/26.
//

import SwiftUI

/// Live voice conversation screen: connection status, streaming
/// transcript, mic level, interrupt, and typed input. Driven entirely by a
/// `RealtimeConversationHandler`, so any realtime provider can back it.
///
/// Present it in a navigation container (`ChatView` does this for its
/// live-voice button). The conversation disconnects when the view goes away.
public struct RealtimeConversationView<Handler: RealtimeConversationHandler>: View {
    @ObservedObject private var handler: Handler
    private let title: String
    @State private var textInput = ""
    @Environment(\.dismiss) private var dismiss

    public init(handler: Handler, title: String = "Live Voice") {
        _handler = ObservedObject(wrappedValue: handler)
        self.title = title
    }

    public var body: some View {
        VStack(spacing: 0) {
            statusBar
            Divider()
            transcriptList
            Divider()
            controls
        }
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    Task {
                        await handler.disconnect()
                        dismiss()
                    }
                }
                .accessibilityIdentifier("realtime.doneButton")
            }
        }
        .onDisappear {
            Task { await handler.disconnect() }
        }
    }

    // MARK: - Status

    private var statusBar: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            Text(handler.connectionState.rawValue)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("realtime.connectionState")

            Spacer()

            if handler.isUserSpeaking {
                Label("Listening", systemImage: "waveform")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            if handler.isModelSpeaking {
                Label("Speaking", systemImage: "speaker.wave.2.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var statusColor: Color {
        switch handler.connectionState {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }

    // MARK: - Transcript

    private var transcriptList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if handler.transcript.isEmpty {
                        emptyState
                    }
                    ForEach(handler.transcript) { entry in
                        transcriptRow(entry)
                            .id(entry.id)
                    }
                }
                .padding()
            }
            .onChange(of: handler.transcript) { _, entries in
                if let last = entries.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(handler.connectionState == .connected
                 ? "Start talking — the assistant is listening."
                 : "Start a session to have a live voice conversation.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func transcriptRow(_ entry: RealtimeTranscriptEntry) -> some View {
        HStack {
            if entry.role == .user { Spacer(minLength: 40) }
            VStack(alignment: entry.role == .user ? .trailing : .leading, spacing: 2) {
                Text(entry.role == .user ? "You" : "Assistant")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(entry.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        entry.role == .user
                        ? AnyShapeStyle(Color.accentColor.opacity(0.15))
                        : AnyShapeStyle(.quaternary),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .opacity(entry.isFinal ? 1 : 0.6)
            }
            if entry.role == .assistant { Spacer(minLength: 40) }
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 12) {
            if let error = handler.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("realtime.error")
            }

            if handler.connectionState == .connected {
                AudioVisualizerView(
                    audioLevel: handler.audioLevel,
                    barCount: 30,
                    barColor: handler.isUserSpeaking ? .green : .accentColor,
                    maxBarHeight: 28
                )
                .frame(height: 28)

                HStack(spacing: 10) {
                    TextField("Type a message…", text: $textInput)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("realtime.textInput")
                        .onSubmit(sendTypedText)
                    Button(action: sendTypedText) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .accessibilityIdentifier("realtime.sendButton")
                    .accessibilityLabel("Send")
                    .disabled(trimmedInput.isEmpty)
                }
            }

            HStack(spacing: 16) {
                connectButton
                if handler.connectionState == .connected && handler.isModelSpeaking {
                    Button(role: .destructive) {
                        Task { await handler.interrupt() }
                    } label: {
                        Label("Interrupt", systemImage: "stop.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("realtime.interruptButton")
                }
            }
        }
        .padding()
    }

    private var connectButton: some View {
        let isConnected = handler.connectionState == .connected
        return Button {
            Task {
                if isConnected {
                    await handler.disconnect()
                } else {
                    await handler.connect()
                }
            }
        } label: {
            Label(
                isConnected ? "End Session" : "Start Session",
                systemImage: isConnected ? "phone.down.fill" : "phone.fill"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(isConnected ? .red : .accentColor)
        .disabled(handler.connectionState == .connecting)
        .accessibilityIdentifier("realtime.sessionButton")
    }

    private var trimmedInput: String {
        textInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sendTypedText() {
        let text = trimmedInput
        guard !text.isEmpty else { return }
        textInput = ""
        Task { await handler.sendText(text) }
    }
}
