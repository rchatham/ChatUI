# ChatUI — Agent Guidelines

## Project Overview

ChatUI is a Swift Package Manager library providing reusable SwiftUI components for building
chat interfaces. It has no third-party dependencies.

- **Language:** Swift 6.0 (strict concurrency enforced)
- **Platforms:** macOS 14+, iOS 17+, watchOS 8+
- **Framework:** SwiftUI, Combine, Foundation
- **Package manager:** Swift Package Manager (SPM)

---

## Build & Test Commands

### Build

```bash
swift build
```

### Run all tests

```bash
swift test
```

### Run a single test by name

The test suite uses **Swift Testing** (`import Testing`), not XCTest. Filter by function name:

```bash
swift test --filter "example"
```

For XCTest-style filter syntax:

```bash
swift test --filter ChatUITests/example
```

### Clean build artifacts

```bash
swift package clean
```

### Resolve dependencies

```bash
swift package resolve
```

### Generate Xcode project

```bash
swift package generate-xcodeproj
```

### Linting

No linting toolchain (SwiftLint, etc.) is currently configured. Follow the style guidelines
below manually.

---

## Repository Structure

```
ChatUI/
├── Package.swift                   # SPM manifest
├── Sources/
│   └── ChatUI/
│       ├── ChatUI.swift            # Module entry point (stub)
│       ├── ChatMessageService.swift # Core protocols and data types
│       ├── ChatView.swift          # Top-level view + ViewModel
│       ├── CollapsibleMessageView.swift
│       ├── MessageComposerView.swift
│       ├── MessageListView.swift
│       └── View+Extensions.swift  # Shared view helpers
└── Tests/
    └── ChatUITests/
        └── ChatUITests.swift
```

---

## Code Style Guidelines

### Formatting

- **Indentation:** 4 spaces (no tabs)
- **Braces:** Opening brace on the same line as the declaration
- **Semicolons:** Never used
- **Line length:** No hard limit, but prefer readable line breaks over long lines
- **File headers:** Every file begins with a comment header:
  ```swift
  //  FileName.swift
  //  ChatUI
  //
  //  Created by Reid Chatham on MM/DD/YY.
  //
  ```

### Imports

- System/Apple frameworks first, then platform-conditional imports in `#if` blocks
- No blank lines between standard imports; platform guards are isolated:
  ```swift
  import SwiftUI
  import Combine
  #if os(iOS)
  import UIKit
  #endif
  ```
- No third-party imports exist; do not add external dependencies without discussion

### Naming Conventions

| Category | Convention | Examples |
|---|---|---|
| Types (struct, class, enum, protocol) | PascalCase | `ChatView`, `MessageComposerView`, `ChatAlertInfo` |
| Functions and methods | camelCase | `sendMessage()`, `scrollToBottom(scrollProxy:)` |
| Properties and variables | camelCase | `isMessageSending`, `voiceInputHandler`, `localInput` |
| Private backing storage | underscore prefix | `_settingsView`, `_messageContent` |
| Generic type parameters | PascalCase | `MessageService`, `Message` |
| File names | PascalCase matching primary type | `ChatView.swift` |
| Extension files | `TypeName+Category.swift` | `View+Extensions.swift` |

### Types

- **Swift 6 strict concurrency is required.** All code must compile without concurrency warnings.
- Annotate all ViewModel classes and UI-mutating functions with `@MainActor`:
  ```swift
  @MainActor public class ViewModel: ObservableObject { ... }
  ```
- Use `nonisolated` for properties that must be accessed off the main actor:
  ```swift
  nonisolated private let messageService: any ChatMessageService
  ```
- Mark protocol types and conforming types `Sendable` where required by the concurrency model.
- Use `any Protocol` (existential syntax) for protocol-typed references — required in Swift 6:
  ```swift
  private var voiceInputHandler: (any VoiceInputHandler)?
  ```
- Prefer `@Published` + `ObservableObject` for state management (not `@Observable` macro).
- Use `AnyView` for injected view closures to avoid unbounded generic propagation:
  ```swift
  private var _messageContent: ((MessageService.ChatMessage) -> AnyView)?
  ```
- Use `@ViewBuilder` for optional view-customization parameters in public initializers.

### Protocol-Oriented Design

- Define public-facing behavior through protocols with associated types:
  ```swift
  public protocol ChatMessageService: Sendable, ObservableObject {
      associatedtype ChatMessage: ChatMessageInfo
  }
  ```
- Expose generic views parameterized on protocol conformances:
  ```swift
  public struct ChatView<MessageService: ChatMessageService>: View { ... }
  ```
- Place ViewModel types as inner classes inside `extension` on their owning view:
  ```swift
  extension ChatView {
      @MainActor public class ViewModel: ObservableObject { ... }
  }
  ```

### Error Handling

- Route errors through a protocol method that returns optional `ChatAlertInfo?`; if nil,
  fall back to a generic error alert:
  ```swift
  func handleError(_ error: any Error) {
      if let alertInfo = messageService.handleError(error: error) {
          self.alertInfo = alertInfo
          self.showAlert = true
      } else {
          self.alertInfo = ChatAlertInfo(title: "Error!", ...)
          self.showError = true
      }
  }
  ```
- Wrap async throwing calls with `do/catch` and route to `handleError`:
  ```swift
  do { try await messageService.send(message: text, stream: true) }
  catch { handleError(error) }
  ```
- Restore UI state on failure (e.g., restore input text if a send fails):
  ```swift
  catch {
      handleError(error)
      Task { @MainActor in input = sentText }
  }
  ```
- Use `try?` only for genuinely non-critical operations (e.g., `Task.sleep`).

### Platform-Conditional Code

- Wrap all platform-specific code in `#if os(iOS)` / `#else` / `#endif` guards.
- Keep conditional blocks focused and minimal — extract to helpers where blocks grow large.

### Logging & Debugging

- Use `print(...)` for debug output. No dedicated logger abstraction currently exists.
- Remove or gate debug prints before merging to main.

---

## Testing Guidelines

- **Framework:** Swift Testing (`import Testing`) — not XCTest.
- Tests live in `Tests/ChatUITests/`.
- Test functions are `async throws` to support async code under test.
- Use `#expect(...)` for assertions (Swift Testing API).
- Import the module under test with `@testable import ChatUI`.
- Name test functions descriptively in camelCase: `@Test func sendsMessageOnSubmit() async throws`.

---

## Git & PR Conventions

- Branch naming: `feature/`, `fix/`, `refactor/` prefixes (e.g., `feature/voice-input-stt`)
- Commit messages: Use conventional commits format (`feat:`, `fix:`, `refactor:`, `test:`, `docs:`)
- Never force-push to `main`
- Ensure `swift build` and `swift test` pass before opening a PR
