//
//  View+Extensions.swift
//  LangTools_Example
//
//  Created by Reid Chatham on 2/16/25.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

extension View {
    func invalidInputAlert(isPresented: Binding<Bool>) -> some View {
        return alert(Text("Invalid Input"), isPresented: isPresented, actions: {
            Button("OK", role: .cancel, action: {})
        }, message: { Text("Please enter a valid prompt") })
    }

    #if os(iOS)
    /// Adds a drag gesture to dismiss the keyboard when swiping down
    func dismissKeyboardOnSwipe() -> some View {
        self.gesture(
            DragGesture()
                .onChanged { _ in
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        )
    }
    #endif
}
