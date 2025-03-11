//
//  MessageComposerView.swift
//
//  Created by Reid Chatham on 4/2/23.
//

import SwiftUI

struct MessageComposerView: View {
    @ObservedObject var viewModel: ViewModel
    @FocusState var promptTextFieldIsActive: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                textInputField
                if viewModel.isMessageSending {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
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
                    .stroke(colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.3), lineWidth: 1)
            }
            .padding(8)
        }
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
    }

    var textInputField: some View {
        TextField("Enter your prompt", text: $viewModel.input, axis: .vertical)
            .textFieldStyle(.plain)
            .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 0))
            .foregroundColor(.primary)
            .lineLimit(5)
            .multilineTextAlignment(.leading)
            .onKeyPress(keys: .init([.return]), action: handleEnterPress)
            .focused($promptTextFieldIsActive)
            .disabled(viewModel.isMessageSending)
    }

    var sendButton: some View {
        Button(action: submitButtonTapped) {
            Image(systemName: viewModel.showAlert ? "exclamationmark.triangle.fill" : "arrow.up.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(
                    viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? .gray.opacity(0.5)
                    : viewModel.showAlert ? .orange : .accentColor
                )
        }
        .buttonStyle(BorderlessButtonStyle())
        .disabled(viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

    private func handleEnterPress(with press: KeyPress) -> KeyPress.Result {
        if press.modifiers.contains(.shift) {
            // Insert a new line when Shift+Enter is pressed
            Task { @MainActor in
                viewModel.input += "\n"
            }
            return .handled
        } else {
            // Submit only when Enter is pressed without Shift
            submitButtonTapped()
            return .handled
        }
    }

    func submitButtonTapped() {
        if viewModel.isMessageSending || viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }

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

        init(messageService: any ChatMessageService) {
            self.messageService = messageService
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
                self.alertInfo = ChatAlertInfo(title: "Error!", textField: nil , button: nil, message: "Error sending message completion request: \(error)")
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
