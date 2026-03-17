import SwiftUI
import AppKit

/// SwiftUI wrapper for STTextView-based code editor
struct STCodeEditorView: NSViewControllerRepresentable {
    @Binding var text: String
    @Binding var state: EditorState
    let configuration: EditorConfiguration
    let completionDelegate: (any CompletionDelegate)?
    let definitionDelegate: (any DefinitionDelegate)?
    let diagnostics: [Diagnostic]

    init(
        text: Binding<String>,
        state: Binding<EditorState>,
        configuration: EditorConfiguration,
        completionDelegate: (any CompletionDelegate)? = nil,
        definitionDelegate: (any DefinitionDelegate)? = nil,
        diagnostics: [Diagnostic] = []
    ) {
        self._text = text
        self._state = state
        self.configuration = configuration
        self.completionDelegate = completionDelegate
        self.definitionDelegate = definitionDelegate
        self.diagnostics = diagnostics
    }

    func makeNSViewController(context: Context) -> STCodeEditorViewController {
        let controller = STCodeEditorViewController()
        controller.text = text
        controller.configuration = configuration
        controller.completionDelegate = completionDelegate
        controller.definitionDelegate = definitionDelegate

        // Callback when user edits text
        controller.onTextChange = { newText in
            if text != newText {
                text = newText
            }
        }

        // Callback when cursor/selection changes
        controller.onStateChange = { newState in
            if state != newState {
                state = newState
            }
        }

        return controller
    }

    func updateNSViewController(_ controller: STCodeEditorViewController, context: Context) {
        // Update text if changed from outside
        if controller.text != text {
            controller.updateText(text)
        }

        // Restore scroll position if changed from outside (e.g., switching tabs)
        if state.scrollPosition != .zero {
            controller.updateScrollPosition(state.scrollPosition)
        }

        // Update configuration
        controller.configuration = configuration

        // Update diagnostics
        controller.updateDiagnostics(diagnostics)
    }
}

