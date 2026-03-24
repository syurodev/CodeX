# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This is a native macOS Xcode project. Open `CodeX.xcodeproj` in Xcode and run with ⌘R, or build from the command line:

```bash
xcodebuild -scheme CodeX -destination 'platform=macOS' build
xcodebuild -scheme CodeXTests -destination 'platform=macOS' test
xcodebuild -scheme CodeXTests -destination 'platform=macOS' -only-testing:CodeXTests/SomeTestClass/testMethod test
```

There is no `make`, `npm`, or other build system — Xcode is the only build tool.

## Architecture Overview

CodeX is a native macOS code editor with integrated AI agents (Claude Code, GitHub Copilot), LSP support, an embedded terminal, and script execution.

### Layer Structure

```
Models/       – Pure data structs (EditorDocument, FileNode, Project, DocumentSymbol, …)
Services/     – Stateful singletons/actors that do I/O (LanguageClientService, GitService, BiomeService, …)
ViewModels/   – @Observable @MainActor classes that own UI state and orchestrate Services
Views/        – SwiftUI views that read from ViewModels and call back into them
Packages/     – Bundled local Swift packages (CodeEditSourceEditor, SwiftTerm, ACPClient)
```

### Central State: `AppViewModel`

`AppViewModel` is the root `@Observable` class. It owns every sub-ViewModel and sub-service:

- `EditorViewModel` – open documents, cursor/scroll state, LSP completions, diagnostics
- `FileNavigatorViewModel` – file tree expand/select
- `GitViewModel` – branch, file statuses
- `AgentPanelViewModel` + `AgentRuntimeViewModel` – ACP chat sessions
- `TerminalPanelViewModel` – terminal sessions + run-output tabs
- `ProjectRunViewModel` – monorepo script detection and execution
- `QuickOpenViewModel`, `SymbolPickerViewModel` – overlays (Cmd+P / Cmd+Shift+O)

`AppViewModel` is injected via `.environment(appViewModel)` at the app root and accessed with `@Environment(AppViewModel.self)` in views.

### Editor Pipeline

```
EditorDocument (model, holds text + LSP state)
  ↕ sync via EditorViewModel (debounced 500 ms)
CESourceEditorView (NSViewControllerRepresentable)
  └── CESourceEditorViewController
        └── TextViewController (from CodeEditSourceEditor package)
              └── CodeEditTextView.TextView (custom NSView, lazy layout)
```

**Important gotcha — lazy layout:** `CodeEditTextView` only lays out visible lines. `scrollSelectionToVisible()` is broken for off-screen selections because `selection.boundingRect` starts at `.zero`. Use `textView.scrollToRange(_:center:)` with a character offset computed from the text string instead.

**Editor state flow:** `EditorDocument.editorState` (cursor + scroll) is bound through `CESourceEditorView`. The `if/else` pattern in `CESourceEditorViewController.updateEditorState` prevents the saved scroll position from overriding a programmatic cursor jump.

### LSP

`LanguageClientService` implements JSON-RPC 2.0 over stdin/stdout. Currently supports TypeScript/JavaScript via `vtsls` (bundled as `deno`). LSP diagnostics merge with Biome diagnostics in `EditorViewModel.mergeDiagnostics()`.

### Agent Integration (ACP)

Agents communicate via the ACP protocol through the local `ACPClient` package. Environment variables configure agent paths:
- `CODEX_CLAUDE_ACP_PATH` – override Claude Code executable
- `CODEX_COPILOT_ACP_PATH` – override Copilot path
- `CODEX_ACP_DEBUG=1` – enable ACP debug logging

### Key Patterns

- **Observable + Bindable:** All ViewModels are `@Observable @MainActor`. Use `.onChange(of:)` in views rather than `didSet` on `@Observable` properties — `didSet` is unreliable when the property is written through a SwiftUI `@Bindable` binding.
- **Debouncing:** Achieved by cancelling a `Task` before scheduling a new one (LSP sync 500 ms, Biome 450 ms, symbol fetch 800 ms).
- **Singletons:** `LSPManager.shared`, `BiomeService.shared`, `CopilotService.shared`, `LocalLLMService.shared`.
- **Notifications for cross-layer decoupling:** E.g., `"CodeX.FlashSymbolRange"` notification decouples `AppViewModel` → `CESourceEditorViewController` without requiring a direct reference.

## Local Packages

| Package | Purpose |
|---|---|
| `Packages/CodeEditSourceEditor` | Syntax highlighting, code completion, EmphasisManager |
| `Packages/SwiftTerm` | Terminal emulator |
| `Packages/ACPClient` | Thin wrapper over `swift-acp` for agent communication |

## Language Support Notes

- **TypeScript/JavaScript** – full LSP (vtsls) + Biome lint/format
- **Swift, Python, Go, Rust, Kotlin, Java, Ruby** – regex-based symbol parsing only (no LSP)
- `SymbolPickerViewModel.patterns(for:)` contains per-extension regex patterns; TS/JS merges LSP symbols + regex to cover methods that LSP may miss

## Bundled Binaries

- `biome` – linting and formatting for JS/TS
- `deno` – used as the vtsls LSP server for TypeScript
