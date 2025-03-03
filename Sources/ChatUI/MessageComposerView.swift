//
//  MessageComposerView.swift
//
//  Created by Reid Chatham on 4/2/23.
//

import SwiftUI
import CoreData

struct MessageComposerView: View {
    @ObservedObject var viewModel: ViewModel
    @FocusState var promptTextFieldIsActive: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                // Input field
                TextField("Enter your prompt", text: $viewModel.input, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 0))
                    .foregroundColor(.primary)
                    .lineLimit(5)
                    .multilineTextAlignment(.leading)
                    .submitLabel(.send)
                    .onSubmit(submitButtonTapped)
                    .focused($promptTextFieldIsActive)
                    .disabled(viewModel.isMessageSending)

                // Send button or loading indicator
                if viewModel.isMessageSending {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(width: 24, height: 24)
                        .padding(.trailing, 12)
                        .transition(.opacity)
                } else {
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
                    .padding(.trailing, 12)
                    .transition(.opacity)
                }
            }
            .padding(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 0))
            .background(
                colorScheme == .dark
                ? Color.black.opacity(0.3)
                : Color.white.opacity(0.9)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            .padding(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        }
        .alert(viewModel.alertInfo?.title ?? "///Missing title///", isPresented: $viewModel.showAlert, actions: {
            if let alertInfo = $viewModel.alertInfo.wrappedValue, let tf = alertInfo.textField, let bt = alertInfo.button {
                TextField(tf.label, text: tf.text)
                Button(bt.text, role: bt.role, action: { do { try bt.action(alertInfo) } catch { viewModel.handleError(error) } })
            }
            Button("Cancel", role: .cancel, action: {})
        }, message: {
            if let text = $viewModel.alertInfo.wrappedValue?.message { Text(text) }
        })
        .alert(isPresented: $viewModel.showError, content: {
            Alert(title: Text("Error"), message: Text($viewModel.alertInfo.wrappedValue?.title ?? ""), dismissButton: .default(Text("OK")))
        })
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
