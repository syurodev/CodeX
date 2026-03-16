import SwiftUI
import AppKit
@_exported import CodeEditLanguages

/// SwiftUI editor component backed by TextKit 2.
/// Drop-in replacement for CodeEditSourceEditor's `SourceEditor`.
public struct CodeXEditorView: NSViewControllerRepresentable {

    // MARK: - Bindings

    @Binding public var text: String
    @Binding public var state: EditorState

    // MARK: - Configuration

    public var language: CodeLanguage
    public var configuration: EditorConfiguration

    // MARK: - Delegates

    public weak var completionDelegate: (any CompletionDelegate)?
    public weak var definitionDelegate: (any DefinitionDelegate)?

    // MARK: - Init

    public init(
        text: Binding<String>,
        language: CodeLanguage,
        configuration: EditorConfiguration = EditorConfiguration(),
        state: Binding<EditorState>,
        completionDelegate: (any CompletionDelegate)? = nil,
        definitionDelegate: (any DefinitionDelegate)? = nil
    ) {
        _text = text
        _state = state
        self.language = language
        self.configuration = configuration
        self.completionDelegate = completionDelegate
        self.definitionDelegate = definitionDelegate
    }

    // MARK: - NSViewControllerRepresentable

    public func makeNSViewController(context: Context) -> CodeXEditorViewController {
        let vc = CodeXEditorViewController()
        let coordinator = context.coordinator
        coordinator.viewController = vc

        // Wire callbacks through the Coordinator (class — safe for weak capture)
        vc.onTextChange = { [weak coordinator] newText in
            coordinator?.handleTextChange(newText)
        }
        vc.onStateChange = { [weak coordinator] newState in
            coordinator?.handleStateChange(newState)
        }
        vc.onDefinitionRequested = { [weak coordinator] range, cursor, text in
            coordinator?.handleDefinitionRequest(range: range, cursor: cursor, text: text)
        }

        return vc
    }

    public func updateNSViewController(_ vc: CodeXEditorViewController, context: Context) {
        let coordinator = context.coordinator

        // Apply configuration first so typography is correct before setting text
        vc.applyConfiguration(configuration)
        vc.setLanguage(language)

        // Push text from SwiftUI → editor (guard inside prevents feedback loop)
        coordinator.isApplyingExternalUpdate = true
        vc.setText(text)
        coordinator.isApplyingExternalUpdate = false

        // Push state (cursor/scroll) from SwiftUI → editor
        coordinator.isApplyingExternalUpdate = true
        vc.applyState(state)
        coordinator.isApplyingExternalUpdate = false

        // Refresh delegate references
        coordinator.completionDelegate = completionDelegate
        coordinator.definitionDelegate = definitionDelegate
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, state: $state)
    }

    // MARK: - Coordinator

    public final class Coordinator {
        weak var viewController: CodeXEditorViewController?
        var completionDelegate: (any CompletionDelegate)?
        var definitionDelegate: (any DefinitionDelegate)?

        /// Set to `true` while SwiftUI is pushing updates down to AppKit,
        /// so that AppKit callbacks don't echo the change back up.
        var isApplyingExternalUpdate = false

        private var textBinding: Binding<String>
        private var stateBinding: Binding<EditorState>

        init(text: Binding<String>, state: Binding<EditorState>) {
            textBinding = text
            stateBinding = state
        }

        func handleTextChange(_ newText: String) {
            guard !isApplyingExternalUpdate else { return }
            DispatchQueue.main.async { [weak self] in
                self?.textBinding.wrappedValue = newText
            }
        }

        func handleStateChange(_ newState: EditorState) {
            guard !isApplyingExternalUpdate else { return }
            DispatchQueue.main.async { [weak self] in
                self?.stateBinding.wrappedValue = newState
            }
        }

        func handleDefinitionRequest(range: NSRange, cursor: CursorPosition, text: String) {
            guard let delegate = definitionDelegate else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let links = await delegate.queryDefinition(
                    forRange: range, cursor: cursor, in: text, url: nil
                ), let first = links.first else { return }
                delegate.openLink(first)
            }
        }
    }
}
