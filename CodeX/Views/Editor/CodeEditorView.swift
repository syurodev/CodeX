import SwiftUI
import CodeEditSourceEditor
import CodeEditLanguages

struct CodeEditorView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var viewModel: EditorViewModel
    let bottomContentInset: CGFloat

    init(viewModel: EditorViewModel, bottomContentInset: CGFloat = 0) {
        self.viewModel = viewModel
        self.bottomContentInset = bottomContentInset
    }

    var body: some View {
        if viewModel.openDocuments.isEmpty {
            emptyState
        } else {
            ZStack {
                ForEach(viewModel.openDocuments) { document in
                    let isActive = document.id == viewModel.currentDocumentID
                    
                    SingleCodeEditorView(
                        document: document,
                        viewModel: viewModel,
                        bottomContentInset: bottomContentInset
                    )
                        .opacity(isActive ? 1 : 0)
                        .allowsHitTesting(isActive)
                }
            }
        }
    }
    
    // ... (rest of the existing properties)
}

struct SingleCodeEditorView: View {
    @Bindable var document: EditorDocument
    var viewModel: EditorViewModel
    let bottomContentInset: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let textBinding = Binding<String>(
            get: { document.text },
            set: { newValue in
                document.text = newValue
                // Sync text với LSP and trigger linting via viewModel
                viewModel.documentTextChanged(id: document.id, newText: newValue)
            }
        )
        
        let stateBinding = Binding<SourceEditorState>(
            get: { document.editorState },
            set: { newValue in
                document.editorState = newValue
            }
        )

        GeometryReader { proxy in
            SourceEditor(
                textBinding,
                language: document.language,
                configuration: viewModel.editorConfiguration(
                    for: colorScheme,
                    topContentInset: proxy.safeAreaInsets.top + 8,
                    bottomContentInset: proxy.safeAreaInsets.bottom + bottomContentInset
                ),
                state: stateBinding,
                completionDelegate: viewModel,
                jumpToDefinitionDelegate: viewModel
            )
            .ignoresSafeArea(.container, edges: .top)
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
