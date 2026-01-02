//
//  MessageComposerView.swift
//
//  Created by Reid Chatham on 4/2/23.
//

import SwiftUI

/// Protocol for voice input capability injection
@MainActor
public protocol VoiceInputHandler: AnyObject {
    var isRecording: Bool { get }
    var isProcessing: Bool { get }
    var audioLevel: Float { get }
    var statusDescription: String { get }
    var isEnabled: Bool { get }
    var replaceSendButton: Bool { get }
    /// Partial transcription text (streaming/real-time updates)
    var partialText: String { get }
    /// Pending transcribed text that survives view recreation
    var pendingTranscribedText: String? { get set }

    func toggleRecording() async
    func cancelRecording()  // Synchronous cancel - no transcription
    /// Returns the transcribed text from the most recent voice recording session.
    ///
    /// - Returns: The transcribed text as a `String?`, or `nil` if no transcription is available.
    /// - Note: This method can be called multiple times after recording stops to retrieve the transcribed text.
    ///         It does **not** clear the internal transcribed text after being called; the same value will be returned
    ///         until a new recording session is completed and new transcription is available.
    func getTranscribedText() -> String?
}

struct MessageComposerView: View {
    @ObservedObject var viewModel: ViewModel
    @FocusState var promptTextFieldIsActive: Bool
    @Environment(\.colorScheme) var colorScheme

    // Voice input state
    @State private var isRecording = false
    @State private var isProcessingVoice = false
    @State private var audioLevel: Float = 0.0
    @State private var statusText: String = ""
    @State private var localInput: String = "" // Local state for TextField to bypass binding issues
    @State private var textFieldId = UUID() // Used to force TextField recreation

    var body: some View {
        ZStack(alignment: .bottom) {
            // Status popup overlay
            if isRecording || isProcessingVoice {
                voiceStatusPopup
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }

            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 12) {
                // Microphone button on left (only when NOT replacing send button)
                if let voiceHandler = viewModel.voiceInputHandler,
                   voiceHandler.isEnabled,
                   !voiceHandler.replaceSendButton {
                    microphoneButton(handler: voiceHandler)
                        .padding(.leading, 4)
                }

                textInputField

                if viewModel.isMessageSending || isProcessingVoice {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.trailing, 4)
                        .transition(.opacity)
                } else if let voiceHandler = viewModel.voiceInputHandler,
                          voiceHandler.isEnabled,
                          voiceHandler.replaceSendButton,
                          localInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Show microphone in send button position when input is empty
                    microphoneButton(handler: voiceHandler)
                        .padding(.trailing, 4)
                        .transition(.opacity)
                } else {
                    sendButton
                        .padding(.trailing, 4)
                        .transition(.opacity)
                }
            }
            .padding(8)
            .background(inputBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            .overlay {
                RoundedRectangle(cornerRadius: 30)
                    .stroke(isRecording ? Color.red.opacity(0.8) : (colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.3)), lineWidth: isRecording ? 2 : 1)
            }
            .padding(8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isRecording)
        .animation(.easeInOut(duration: 0.2), value: isProcessingVoice)
        .alert(viewModel.alertInfo?.title ?? "///Missing title///", isPresented: $viewModel.showAlert, actions: {
            if let alertInfo = $viewModel.alertInfo.wrappedValue, let tf = alertInfo.textField, let bt = alertInfo.button {
                TextField(tf.label, text: tf.text)
                Button(bt.text, role: bt.role, action: {
                    do { try bt.action(alertInfo) } catch { viewModel.handleError(error) }
                })
            }
            Button("Cancel", role: .cancel, action: {})
        }, message: {
            if let text = $viewModel.alertInfo.wrappedValue?.message { Text(text) }
        })
        .alert(isPresented: $viewModel.showError, content: {
            Alert(title: Text("Error"), message: Text($viewModel.alertInfo.wrappedValue?.title ?? ""), dismissButton: .default(Text("OK")))
        })
        .onAppear {
            localInput = viewModel.input  // Initialize local state from viewModel
            consumePendingText()
        }
        .onChange(of: viewModel.input) { _, newValue in
            // Sync viewModel → local (for cases where viewModel.input is set externally)
            if localInput != newValue {
                localInput = newValue
            }
        }
        .onChange(of: viewModel.voiceInputHandler?.pendingTranscribedText) { _, _ in
            consumePendingText()
        }
    }

    /// Consume pending transcribed text from voice handler and set to input field
    /// This runs AFTER view renders to avoid race condition with @Published
    private func consumePendingText() {
        guard let handler = viewModel.voiceInputHandler,
              let pending = handler.pendingTranscribedText,
              !pending.isEmpty else { return }

        print("[MessageComposerView] Consuming pending text via .onAppear/.onChange: '\(pending)'")
        // Set LOCAL state first - this reliably updates TextField
        localInput = pending
        // Also sync to viewModel for message sending
        viewModel.input = pending
        handler.pendingTranscribedText = nil
    }

    var textInputField: some View {
        TextField("Enter your prompt", text: $localInput, axis: .vertical)
            .id(textFieldId) // Force TextField recreation when id changes to sync with binding
            .textFieldStyle(.plain)
            .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 0))
            .foregroundColor(.primary)
            .lineLimit(5)
            .multilineTextAlignment(.leading)
            .onKeyPress(keys: .init([.return]), action: handleEnterPress)
            .focused($promptTextFieldIsActive)
            .disabled(viewModel.isMessageSending)
            .onChange(of: localInput) { _, newValue in
                viewModel.input = newValue  // Sync local → viewModel
            }
    }

    var sendButton: some View {
        Button(action: submitButtonTapped) {
            Image(systemName: viewModel.showAlert ? "exclamationmark.triangle.fill" : "arrow.up.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(
                    localInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? .gray.opacity(0.5)
                    : viewModel.showAlert ? .orange : .accentColor
                )
        }
        .buttonStyle(BorderlessButtonStyle())
        .disabled(localInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func microphoneButton(handler: VoiceInputHandler) -> some View {
        Button(action: {
            Task {
                await toggleVoiceRecording(handler: handler)
            }
        }) {
            ZStack {
                // Background pulse animation when recording
                if isRecording {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .scaleEffect(1.0 + CGFloat(audioLevel) * 0.5)
                        .animation(.easeInOut(duration: 0.1), value: audioLevel)
                }

                Image(systemName: isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 20))
                    .foregroundColor(isRecording ? .red : .gray)
            }
            .frame(width: 32, height: 32)
        }
        .buttonStyle(BorderlessButtonStyle())
        .disabled(isProcessingVoice || viewModel.isMessageSending)
    }

    @MainActor
    private func toggleVoiceRecording(handler: VoiceInputHandler) async {
        if isRecording {
            // Stop recording
            isRecording = false
            isProcessingVoice = true

            await handler.toggleRecording()
            isRecording = false

            // Update status during processing
            statusText = handler.statusDescription
            print("[MessageComposerView] toggleRecording completed, status: \(handler.statusDescription)")

            // Get transcribed text and store in handler (survives view recreation)
            // DON'T set viewModel.input here - let consumePendingText handle it via .onChange
            if let text = handler.getTranscribedText(), !text.isEmpty {
                print("[MessageComposerView] Got transcribed text, storing as pending: '\(text)'")
                handler.pendingTranscribedText = text
            } else {
                print("[MessageComposerView] getTranscribedText returned nil or empty")
            }

            isProcessingVoice = false
            statusText = ""

            // Restore focus after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.promptTextFieldIsActive = true
            }
        } else {
            // Start recording
            isRecording = true
            statusText = "Recording..."
            await handler.toggleRecording()

            // Update audio level and status periodically while recording
            Task {
                while isRecording {
                    audioLevel = handler.audioLevel
                    statusText = handler.statusDescription
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                }
            }
        }
    }

    private var inputBackgroundColor: Color {
#if os(iOS)
        return colorScheme == .dark
        ? Color.black.opacity(0.3)
        : Color.white.opacity(0.9)
#else
        return colorScheme == .dark
        ? Color.black.opacity(0.3)
        : Color.black.opacity(0.15)
#endif
    }

    private var popupBackgroundColor: Color {
        colorScheme == .dark
        ? Color.gray.opacity(0.3)
        : Color.gray.opacity(0.15)
    }

    private var voiceStatusPopup: some View {
        HStack(spacing: 12) {
            // Animated indicator
            if isRecording {
                // Recording waveform animation
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.red)
                            .frame(width: 4, height: waveformHeight(for: index))
                            .animation(
                                .easeInOut(duration: 0.3)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.1),
                                value: audioLevel
                            )
                    }
                }
                .frame(width: 32, height: 20)
            } else if isProcessingVoice {
                ProgressView()
                    .controlSize(.small)
            }

            // Show partial transcription or status text
            VStack(alignment: .leading, spacing: 2) {
                if let handler = viewModel.voiceInputHandler,
                   !handler.partialText.isEmpty,
                   isRecording {
                    // Show partial transcription
                    Text(handler.partialText)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    // Listening indicator
                    HStack(spacing: 4) {
                        Text("Listening")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        ProgressView()
                            .controlSize(.mini)
                    }
                } else {
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Cancel button when recording
            if isRecording {
                Button(action: {
                    if let handler = viewModel.voiceInputHandler {
                        isRecording = false
                        isProcessingVoice = false  // Don't show processing state
                        handler.cancelRecording()  // Synchronous - no await needed!
                        statusText = ""
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(popupBackgroundColor)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 80) // Position above the composer
    }

    private func waveformHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 8
        let maxHeight: CGFloat = 20
        let variation = CGFloat(audioLevel) * (maxHeight - baseHeight)
        // Create variation based on index for visual interest
        let offset = sin(Double(index) * .pi / 2.5) * 0.5 + 0.5
        return baseHeight + variation * CGFloat(offset)
    }

    private func handleEnterPress(with press: KeyPress) -> KeyPress.Result {
        if press.modifiers.contains(.shift) {
            // Insert a new line when Shift+Enter is pressed
            Task { @MainActor in
                localInput += "\n"
            }
            return .handled
        } else {
            // Submit only when Enter is pressed without Shift
            submitButtonTapped()
            return .handled
        }
    }

    func submitButtonTapped() {
        if viewModel.isMessageSending || localInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }

        // Ensure viewModel.input is synced before sending (localInput may not have triggered onChange yet)
        viewModel.input = localInput

        Task {
            await viewModel.sendMessage()
            promptTextFieldIsActive = true
        }
    }
}

extension MessageComposerView {
    @MainActor class ViewModel: ObservableObject {
        @Published var input: String = ""

        @Published var showAlert: Bool = false
        @Published var alertInfo: ChatAlertInfo?
        @Published var showError: Bool = false
        @Published var isMessageSending: Bool = false

        nonisolated private let messageService: any ChatMessageService
        let voiceInputHandler: VoiceInputHandler?

        init(messageService: any ChatMessageService, voiceInputHandler: VoiceInputHandler? = nil) {
            self.messageService = messageService
            self.voiceInputHandler = voiceInputHandler
        }

        func sendMessage() async {
            guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            // Send the message completion request
            isMessageSending = true
            let sentText = input
            // Clear the input field
            Task { @MainActor in input = "" }
            do { try await messageService.send(message: sentText, stream: true) }
            catch {
                handleError(error)
                Task { @MainActor in input = sentText }
            }
            isMessageSending = false
        }

        func handleError(_ error: any Error) {
            if let alertInfo = messageService.handleError(error: error) {
                self.alertInfo = alertInfo
                self.showAlert = true
            } else {
                self.alertInfo = ChatAlertInfo(title: "Error!", textField: nil , button: nil, message: "Error sending message completion request: \(error.localizedDescription)")
                self.showError = true
            }
        }
    }
}

// Progress bar for sending message
public struct CircularProgressViewStyle: ProgressViewStyle {
    let size: CGFloat = 24.0
    private let lineWidth: CGFloat = 6.0

    // Make these StateObjects to ensure they're properly tracked across view updates
    @StateObject private var animator = ProgressAnimator()

    public func makeBody(configuration: ProgressViewStyleConfiguration) -> some View {
        ZStack {
            configuration.label
            progressCircleView()
            configuration.currentValueLabel
        }.padding(.trailing, lineWidth)
    }

    private func progressCircleView() -> some View {
        Circle()
            .stroke(.gray, lineWidth: lineWidth)
            .opacity(0.2)
            .overlay(progressFill())
            .frame(width: size - lineWidth, height: size - lineWidth)
            .onAppear { animator.startAnimation() }
            .onDisappear { animator.stopAnimation() }
    }

    private func progressFill() -> some View {
        Circle()
            .trim(from: 0, to: CGFloat(animator.progress))
            .stroke(.gray, lineWidth: lineWidth)
            .opacity(0.6)
            .frame(width: size - lineWidth, height: size - lineWidth)
            .rotationEffect(.degrees(-90))
    }
}

// Separate class to manage animation state
@MainActor class ProgressAnimator: ObservableObject {
    @Published var progress: Double = 0.0
    private var isAnimating: Bool = false
    private var fillDuration: Double = 2.0
    private var emptyDuration: Double = 1.0

    func startAnimation(fillDuration: Double = 2.0, emptyDuration: Double = 1.0) {
        self.fillDuration = fillDuration
        self.emptyDuration = emptyDuration
        isAnimating = true
        animate()
    }

    func stopAnimation() {
        isAnimating = false
    }

    private func animate() {
        guard isAnimating else { return }

        // Animate to full
        withAnimation(.easeInOut(duration: fillDuration)) {
            progress = 1.0
        }

        // Schedule the emptying animation
        DispatchQueue.main.asyncAfter(deadline: .now() + fillDuration) { [emptyDuration] in

            // Animate back to empty
            withAnimation(.easeInOut(duration: emptyDuration)) {
                self.progress = 0.0
            }

            // Schedule the next fill cycle
            DispatchQueue.main.asyncAfter(deadline: .now() + emptyDuration) {
                Task { @MainActor in
                    self.animate()
                }
            }
        }
    }
}
