//
//  MessageComposerView.swift
//
//  Created by Reid Chatham on 4/2/23.
//

import SwiftUI

/// Protocol for voice input capability injection
@MainActor
public protocol VoiceInputHandler: AnyObject, ObservableObject {
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

    func toggleRecording() async throws
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

    // Local UI state (not duplicating handler state)
    @State private var localInput: String = "" // Local state for TextField to bypass binding issues
    @State private var textFieldId = UUID() // Used to force TextField recreation

    var body: some View {
        let isRecording = viewModel.voiceInputHandler?.isRecording ?? false
        let isProcessing = viewModel.voiceInputHandler?.isProcessing ?? false
        
        ZStack(alignment: .bottom) {
            // Status popup overlay
            if let voiceHandler = viewModel.voiceInputHandler,
               (voiceHandler.isRecording || voiceHandler.isProcessing) {
                voiceStatusPopup
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }

            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 12) {
                // Keep the microphone in its configured position. While responding,
                // a right-side microphone yields its space to Stop rather than moving.
                if shouldShowLeadingMicrophone,
                   let voiceHandler = viewModel.voiceInputHandler {
                    microphoneButton(handler: voiceHandler)
                        .padding(.leading, 4)
                }

                textInputField

                if viewModel.sendState == .streaming {
                    operationButton
                        .padding(.trailing, 4)
                        .transition(.opacity)
                } else if viewModel.sendState == .establishing ||
                            viewModel.sendState == .stopping ||
                            isProcessing {
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
        .animation(.easeInOut(duration: 0.2), value: isProcessing)
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
            // Only initialise from the ViewModel when the local field is empty
            // (avoids wiping text the user has already typed if the view re-appears
            // due to parent re-renders triggered by VoiceInputHandlerAdapter events).
            if localInput.isEmpty {
                localInput = viewModel.input
            }
            consumePendingText()
        }
        .onChange(of: viewModel.input) { _, newValue in
            // Sync viewModel → local only when the change is meaningful:
            // • newValue is non-empty  → explicit external set (e.g. voice transcription)
            // • newValue is empty AND localInput is also empty → intentional clear after send
            // Never wipe non-empty localInput with an empty viewModel value
            // (guards against spurious resets from view re-mounting).
            if localInput != newValue, !newValue.isEmpty || localInput.isEmpty {
                localInput = newValue
            }
        }
        .onChange(of: viewModel.voiceInputHandler?.pendingTranscribedText) { _, _ in
            consumePendingText()
        }
        .onChange(of: viewModel.sendState) { _, state in
            // A disabled TextField cannot retain first responder during establishment.
            // Focus as soon as editing is available, not when generation finishes.
            if state == .streaming {
                promptTextFieldIsActive = true
            }
        }
    }

    /// Consume pending transcribed text from voice handler and set to input field
    /// This runs AFTER view renders to avoid race condition with @Published
    private func consumePendingText() {
        guard let pending = viewModel.consumePendingVoiceText() else { return }

        print("[MessageComposerView] Consuming pending text via .onAppear/.onChange: '\(pending)'")
        // Set LOCAL state first - this reliably updates TextField
        localInput = pending
    }

    private var editableInput: Binding<String> {
        Binding(
            get: { localInput },
            set: { newValue in
                // Keep the field focused after submission, but reject edits until
                // the provider has established the response stream.
                guard !viewModel.isComposerEditingDisabled else { return }
                localInput = newValue
            }
        )
    }

    var textInputField: some View {
        TextField("Enter your prompt", text: editableInput, axis: .vertical)
            .id(textFieldId) // Force TextField recreation when id changes to sync with binding
            .accessibilityIdentifier("chat.promptInput")
            .textFieldStyle(.plain)
            .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 0))
            .foregroundColor(.primary)
            .lineLimit(5)
            .multilineTextAlignment(.leading)
            .onKeyPress(keys: .init([.return]), action: handleEnterPress)
            .focused($promptTextFieldIsActive)
            .disabled(viewModel.voiceInputHandler?.isProcessing == true)
            .onChange(of: localInput) { _, newValue in
                viewModel.input = newValue  // Sync local → viewModel
            }
    }

    var shouldShowLeadingMicrophone: Bool {
        guard let voiceHandler = viewModel.voiceInputHandler,
              voiceHandler.isEnabled else { return false }
        return !voiceHandler.replaceSendButton
    }

    var operationButton: some View {
        Button(action: viewModel.stopSending) {
            if viewModel.sendState == .stopping {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.accentColor)
            }
        }
        .accessibilityIdentifier("chat.stopButton")
        .buttonStyle(BorderlessButtonStyle())
        .accessibilityLabel("Stop")
        .disabled(viewModel.sendState == .stopping)
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
        .accessibilityIdentifier("chat.sendButton")
        .buttonStyle(BorderlessButtonStyle())
        .accessibilityLabel("Send")
        .disabled(
            viewModel.isMessageSending ||
            localInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
    }

    private func microphoneButton(handler: any VoiceInputHandler) -> some View {
        Button(action: {
            Task {
                await toggleVoiceRecording(handler: handler)
            }
        }) {
            ZStack {
                // Background pulse animation when recording
                if handler.isRecording {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .scaleEffect(1.0 + CGFloat(handler.audioLevel) * 0.5)
                        .animation(.easeInOut(duration: 0.1), value: handler.audioLevel)
                }

                Image(systemName: handler.isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 20))
                    .foregroundColor(handler.isRecording ? .red : .gray)
            }
            .frame(width: 32, height: 32)
        }
        .buttonStyle(BorderlessButtonStyle())
        .disabled(handler.isProcessing || viewModel.isComposerEditingDisabled)
    }

    @MainActor
    private func toggleVoiceRecording(handler: any VoiceInputHandler) async {
        if handler.isRecording {
            // Stop recording - handler will update its state
            do {
                try await handler.toggleRecording()
            } catch {
                // Handle recording stop errors
                viewModel.handleError(error)
            }

            print("[MessageComposerView] toggleRecording completed, status: \(handler.statusDescription)")

            // DIRECT consumption - don't rely on .onChange (SwiftUI doesn't observe protocol existentials well)
            if let text = handler.getTranscribedText(), !text.isEmpty {
                print("[MessageComposerView] Got transcribed text: '\(text)'")
                localInput = text
                viewModel.input = text
                handler.pendingTranscribedText = nil
            } else if let pending = viewModel.consumePendingVoiceText() {
                print("[MessageComposerView] Using pending text: '\(pending)'")
                localInput = pending
            } else {
                print("[MessageComposerView] No transcribed text available")
                handler.pendingTranscribedText = nil
            }

            // Restore focus after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.promptTextFieldIsActive = true
            }
        } else {
            // Start recording - handler will update its state
            do {
                try await handler.toggleRecording()
            } catch {
                // Handle recording start errors (e.g., permission denial)
                viewModel.handleError(error)
                return
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
        let audioLevel = viewModel.voiceInputHandler?.audioLevel ?? 0.0
        
        return HStack(spacing: 12) {
            // Animated indicator
            if viewModel.voiceInputHandler?.isRecording == true {
                // Recording waveform animation
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.red)
                            .frame(width: 4, height: waveformHeight(for: index, audioLevel: audioLevel))
                            .animation(
                                .easeInOut(duration: 0.3)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.1),
                                value: audioLevel
                            )
                    }
                }
                .frame(width: 32, height: 20)
            } else if viewModel.voiceInputHandler?.isProcessing == true {
                ProgressView()
                    .controlSize(.small)
            }

            // Show partial transcription or status text
            VStack(alignment: .leading, spacing: 2) {
                if let handler = viewModel.voiceInputHandler,
                   !handler.partialText.isEmpty,
                   (handler.isRecording || handler.isProcessing) {
                    // Show partial transcription
                    Text(handler.partialText)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    // Status indicator (Listening while recording, Transcribing while processing)
                    HStack(spacing: 4) {
                        Text(handler.isRecording ? "Listening" : "Transcribing")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        ProgressView()
                            .controlSize(.mini)
                    }
                } else if let handler = viewModel.voiceInputHandler {
                    Text(handler.statusDescription)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Cancel button when recording
            if viewModel.voiceInputHandler?.isRecording == true {
                Button(action: {
                    if let handler = viewModel.voiceInputHandler {
                        handler.cancelRecording()  // Synchronous - no await needed!
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

    private func waveformHeight(for index: Int, audioLevel: Float) -> CGFloat {
        let baseHeight: CGFloat = 8
        let maxHeight: CGFloat = 20
        let variation = CGFloat(audioLevel) * (maxHeight - baseHeight)
        // Create variation based on index for visual interest
        let offset = sin(Double(index) * .pi / 2.5) * 0.5 + 0.5
        return baseHeight + variation * CGFloat(offset)
    }

    private func handleEnterPress(with press: KeyPress) -> KeyPress.Result {
        guard !viewModel.isComposerEditingDisabled else { return .handled }
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
        let sentText = localInput
        guard !viewModel.isMessageSending,
              !sentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }

        // Clear and append the transcript synchronously. Editing unlocks once the
        // response stream is established, so subsequent input becomes the next draft.
        localInput = ""
        viewModel.input = ""
        promptTextFieldIsActive = true
        _ = viewModel.startSending(sentText)
    }
}

extension MessageComposerView {
    @MainActor class ViewModel: ObservableObject {
        enum SendState: Equatable {
            case idle
            case establishing
            case streaming
            case stopping
        }

        @Published var input: String = ""
        @Published var showAlert: Bool = false
        @Published var alertInfo: ChatAlertInfo?
        @Published var showError: Bool = false
        @Published private(set) var sendState: SendState = .idle

        var isMessageSending: Bool { sendState != .idle }
        var isComposerEditingDisabled: Bool { sendState == .establishing }

        private let messageService: any ChatMessageService
        private var activeOperation: ChatSendOperation?
        @Published var voiceInputHandler: (any VoiceInputHandler)?

        init(messageService: any ChatMessageService, voiceInputHandler: (any VoiceInputHandler)? = nil) {
            self.messageService = messageService
            self.voiceInputHandler = voiceInputHandler
        }

        func sendMessage(_ message: String? = nil) async {
            let sentText = message ?? input
            if message == nil,
               sendState == .idle,
               !sentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                input = ""
            }
            guard let sendTask = startSending(sentText) else { return }
            await sendTask.value
        }

        @discardableResult
        func consumePendingVoiceText() -> String? {
            guard let handler = voiceInputHandler,
                  let pending = handler.pendingTranscribedText,
                  !pending.isEmpty else { return nil }

            input = pending
            handler.pendingTranscribedText = nil
            return pending
        }

        @discardableResult
        func startSending(_ message: String) -> Task<Void, Never>? {
            guard sendState == .idle,
                  !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return nil }

            let operation = messageService.sendOperation(message: message, stream: true)
            activeOperation = operation
            sendState = .establishing
            return Task { await monitor(operation) }
        }

        func retry(messageID: UUID) async {
            guard sendState == .idle else { return }
            do {
                let operation = try messageService.retryOperation(messageID: messageID, stream: true)
                await run(operation)
            } catch {
                handleError(error)
            }
        }

        func stopSending() {
            guard let activeOperation, sendState == .streaming else { return }
            sendState = .stopping
            if let messageID = activeOperation.messageID {
                messageService.markResponseStopped(messageID: messageID)
            }
            activeOperation.cancel()
        }

        private func run(_ operation: ChatSendOperation) async {
            activeOperation = operation
            sendState = .establishing
            await monitor(operation)
        }

        private func monitor(_ operation: ChatSendOperation) async {
            defer {
                if activeOperation?.id == operation.id {
                    activeOperation = nil
                    sendState = .idle
                }
            }

            do {
                try await operation.waitUntilEstablished()
                if activeOperation?.id == operation.id, sendState != .stopping {
                    sendState = .streaming
                }
                try await operation.waitForCompletion()
            } catch is CancellationError {
                // Stop is an expected terminal state; retain any partial response.
            } catch {
                let hasInlineFailure = operation.messageID.flatMap { messageID in
                    messageService.chatMessages.first(where: { $0.uuid == messageID })?.sendFailure
                } != nil
                if !hasInlineFailure {
                    handleError(error)
                }
            }
        }

        func handleError(_ error: any Error) {
            // If handleError returns nil the service handled the error itself
            // (e.g. posted a notification to show an auth sheet). Don't show
            // a generic fallback alert in that case — it would conflict with
            // whatever the service already did.
            guard let alertInfo = messageService.handleError(error: error) else { return }
            self.alertInfo = alertInfo
            self.showAlert = true
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
