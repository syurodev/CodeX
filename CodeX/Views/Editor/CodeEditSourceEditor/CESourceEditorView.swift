//
//  CESourceEditorView.swift
//  CodeX
//
//  SwiftUI wrapper for CodeEditSourceEditor
//

import SwiftUI
import AppKit
import CodeEditSourceEditor

/// SwiftUI wrapper for CodeEditSourceEditor TextViewController
struct CESourceEditorView: NSViewControllerRepresentable {
    // MARK: - Bindings
    
    /// The text content of the editor
    @Binding var text: String
    
    /// The editor state (cursor position, scroll position)
    @Binding var editorState: EditorState
    
    /// The diagnostics (errors, warnings)
    @Binding var diagnostics: [CodeX.Diagnostic]
    
    // MARK: - Configuration
    
    /// The language for syntax highlighting
    let language: CodeLanguage
    
    /// Editor configuration (theme, font, etc.)
    let configuration: EditorConfiguration
    
    // MARK: - Callbacks
    
    /// Called when text changes
    var onTextChange: ((String) -> Void)?
    
    /// Called when editor state changes (cursor, scroll)
    var onStateChange: ((EditorState) -> Void)?
    
    // MARK: - Delegates

    var completionDelegate: (any CodeSuggestionDelegate)?
    var definitionDelegate: (any JumpToDefinitionDelegate)?
    
    // MARK: - NSViewControllerRepresentable
    
    func makeNSViewController(context: Context) -> CESourceEditorViewController {
        let controller = CESourceEditorViewController(
            text: text,
            language: language,
            configuration: configuration,
            editorState: editorState,
            diagnostics: diagnostics
        )
        
        // Set callbacks
        let coordinator = context.coordinator
        controller.onTextChange = { newText in
            coordinator.updateText(newText)
        }

        controller.onStateChange = { newState in
            coordinator.updateState(newState)
        }

        // Set delegates
        controller.completionDelegate = completionDelegate
        controller.definitionDelegate = definitionDelegate

        return controller
    }
    
    func updateNSViewController(_ controller: CESourceEditorViewController, context: Context) {
        // Update text if changed externally
        if controller.text != text {
            print("⚠️ [updateNSVC] text mismatch — controller.text.count=\(controller.text.count) binding.count=\(text.count)")
            print("⚠️ [updateNSVC] controller.text prefix: \(String(controller.text.prefix(80)).debugDescription)")
            print("⚠️ [updateNSVC] binding.text prefix: \(String(text.prefix(80)).debugDescription)")
            controller.setText(text)
        }

        // Update configuration if changed
        if controller.configuration != configuration {
            controller.updateConfiguration(configuration)
        }

        // Update language if changed
        if controller.language != language {
            controller.updateLanguage(language)
        }

        // Update editor state
        controller.updateEditorState(editorState)

        // Update diagnostics
        controller.updateDiagnostics(diagnostics)
        
        // Update delegates
        controller.completionDelegate = completionDelegate
        controller.definitionDelegate = definitionDelegate
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, editorState: $editorState, onTextChange: onTextChange, onStateChange: onStateChange)
    }
    
    // MARK: - Coordinator
    
    class Coordinator {
        var text: Binding<String>
        var editorState: Binding<EditorState>
        var onTextChange: ((String) -> Void)?
        var onStateChange: ((EditorState) -> Void)?
        
        init(
            text: Binding<String>,
            editorState: Binding<EditorState>,
            onTextChange: ((String) -> Void)?,
            onStateChange: ((EditorState) -> Void)?
        ) {
            self.text = text
            self.editorState = editorState
            self.onTextChange = onTextChange
            self.onStateChange = onStateChange
        }
        
        func updateText(_ newText: String) {
            text.wrappedValue = newText
            onTextChange?(newText)
        }
        
        func updateState(_ newState: EditorState) {
            editorState.wrappedValue = newState
            onStateChange?(newState)
        }
    }
}

