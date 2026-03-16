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
                viewModel.documentTextChanged(id: document.id, newText: newValue)
            }
        )

        let stateBinding = Binding<EditorState>(
            get: { document.editorState },
            set: { newValue in document.editorState = newValue }
        )

        GeometryReader { proxy in
            // TODO: Re-enable editor after rebuilding
            Text("Editor temporarily disabled")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
            /*
            CodeXEditorView(
                text: textBinding,
                language: document.language,
                configuration: viewModel.editorConfiguration(
                    for: colorScheme,
                    topContentInset: proxy.safeAreaInsets.top + topContentInset + 2,
                    bottomContentInset: proxy.safeAreaInsets.bottom + bottomContentInset
                ),
                state: stateBinding,
                completionDelegate: viewModel,
                definitionDelegate: viewModel,
                inlineCompletionDelegate: viewModel
            )
            .ignoresSafeArea(.container, edges: .top)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            */
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
