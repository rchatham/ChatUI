//  ChatUI.swift
//  ChatUI
//
//  Reusable SwiftUI chat interface components.
//
//  ## Rich Tool / Agent Results
//
//  Host apps can supply custom typed views beneath individual tool and agent
//  call cards by providing a `toolCallContent` closure to `ChatView`:
//
//  ```swift
//  // 1. Define a typed display payload conforming to Codable, Sendable, Hashable.
//  let displayContent = ChatToolCall.DisplayContent(
//      type: "search_results",
//      json: #"{"items":[{"title":"Flight A"}]}"#,
//      summary: "1 flight found",
//      itemCount: 1
//  )
//
//  // 2. Attach it to a successful ChatToolCall.
//  let call = ChatToolCall(
//      id: "t1", name: "search", status: .success,
//      result: "3 results",
//      displayContent: displayContent
//  )
//
//  // 3. Supply a rendering closure to ChatView.
//  ChatView(
//      title: "Chat",
//      messageService: myService,
//      toolCallContent: { call in
//          guard let dc = call.displayContent else { return nil }
//          switch dc.type {
//          case "search_results":
//              return AnyView(MySearchResultsView(json: dc.json))
//          default:
//              return nil  // fall back to raw output
//          }
//      }
//  )
//  ```
//
//  - Custom views render **below** the tool/agent card, independent of its
//    collapsed/expanded disclosure.
//  - Only calls with `status == .success` trigger the closure; pending or
//    failed calls never render rich content.
//  - Returning `nil` preserves the existing raw-text disclosure behavior.
//  - Nested child calls inherit the same `toolCallContent` closure.
//  - `DisplayContent` is backward-compatible Codable — old payloads without
//    the `displayContent` key decode to `nil`.
