import SwiftUI


struct CodeEditorView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var viewModel: EditorViewModel
    let topContentInset: CGFloat
    let bottomContentInset: CGFloat

    init(viewModel: EditorViewModel, topContentInset: CGFloat = 0, bottomContentInset: CGFloat = 0) {
        self.viewModel = viewModel
        self.topContentInset = topContentInset
        self.bottomContentInset = bottomContentInset
    }

    var body: some View {
        let _ = settingsStore.settings

        if viewModel.openDocuments.isEmpty {
            emptyState
        } else {
            ZStack {
                ForEach(viewModel.openDocuments) { document in
                    let isActive = document.id == viewModel.currentDocumentID

                    SingleCodeEditorView(
                        document: document,
                        viewModel: viewModel,
                        topContentInset: topContentInset,
                        bottomContentInset: bottomContentInset
                    )
                    .opacity(isActive ? 1 : 0)
                    .allowsHitTesting(isActive)
                }
            }
        }
    }
}

struct SingleCodeEditorView: View {
    @Bindable var document: EditorDocument
    var viewModel: EditorViewModel
    let topContentInset: CGFloat
    let bottomContentInset: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let textBinding = Binding<String>(
            get: { document.text },
            set: { newValue in
                document.text = newValue
            }
        )

        let stateBinding = Binding<EditorState>(
            get: { document.editorState },
            set: { newValue in document.editorState = newValue }
        )

        let diagnosticsBinding = Binding<[CodeX.Diagnostic]>(
            get: { document.diagnostics },
            set: { newValue in document.diagnostics = newValue }
        )

        GeometryReader { proxy in
            CESourceEditorView(
                text: textBinding,
                editorState: stateBinding,
                diagnostics: diagnosticsBinding,
                language: document.language,
                configuration: viewModel.editorConfiguration(
                    for: colorScheme,
                    topContentInset: topContentInset,
                    bottomContentInset: bottomContentInset
                ),
                onTextChange: { newText in
                    viewModel.documentTextChanged(id: document.id, newText: newText)
                },
                onStateChange: { newState in
                    document.editorState = newState
                },
                completionDelegate: viewModel,
                definitionDelegate: viewModel
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

extension CodeEditorView {
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text("Open a file to start editing")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
