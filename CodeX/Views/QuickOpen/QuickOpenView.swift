import SwiftUI
import AppKit

struct QuickOpenView: View {
    @Bindable var viewModel: QuickOpenViewModel
    let onSelect: (URL) -> Void
    let onDismiss: () -> Void

    @State private var eventMonitor: Any?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            // Dim backdrop — tap outside to dismiss
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Spotlight card
            VStack(spacing: 0) {
                searchField
                if !viewModel.results.isEmpty || viewModel.isLoading {
                    Divider()
                        .opacity(0.3)
                    resultsList
                }
            }
            .glassEffect(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 32, x: 0, y: 12)
            .frame(width: 640)
            .padding(.top, 120)
            .padding(.horizontal)
        }
        .onAppear {
            setupKeyMonitor()
            // Cần delay nhỏ để overlay render xong trước khi set focus
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFocused = true
            }
        }
        .onDisappear {
            removeKeyMonitor()
        }
        .onChange(of: viewModel.searchText) {
            viewModel.updateResults()
        }
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.secondary)

            TextField("Open file...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 20))
                .foregroundStyle(.primary)
                .tint(.accentColor)
                .autocorrectionDisabled()
                .focused($isSearchFocused)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Results list

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if viewModel.isLoading {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 16, height: 16)
                            Text("Indexing files…")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 14)
                    } else {
                        ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, result in
                            ResultRow(
                                result: result,
                                isSelected: index == viewModel.selectedIndex
                            )
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect(result.url)
                                onDismiss()
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(maxHeight: 380)
            .onChange(of: viewModel.selectedIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.1)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    // MARK: - Keyboard monitor

    private func setupKeyMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 125: // ↓ arrow
                viewModel.selectNext()
                return nil
            case 126: // ↑ arrow
                viewModel.selectPrevious()
                return nil
            case 36, 76: // Return / Enter
                if let result = viewModel.selectedResult {
                    onSelect(result.url)
                    onDismiss()
                }
                return nil
            case 53: // Escape
                onDismiss()
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

// MARK: - Result Row

private struct ResultRow: View {
    let result: QuickOpenViewModel.FileResult
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: result.url.path))
                .resizable()
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)

                if !result.displayPath.isEmpty {
                    Text(result.displayPath)
                        .font(.system(size: 11))
                        .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.accentColor : Color.clear)
                .padding(.horizontal, 6)
        )
    }
}

