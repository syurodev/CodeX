import SwiftUI
import AppKit

struct SymbolPickerView: View {
    @Bindable var viewModel: SymbolPickerViewModel
    let onSelect: (SymbolPickerViewModel.SymbolItem) -> Void
    let onDismiss: () -> Void

    @State private var eventMonitor: Any?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                searchField
                if !viewModel.results.isEmpty {
                    Divider().opacity(0.3)
                    resultsList
                } else if !viewModel.searchText.isEmpty {
                    emptyState
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
            Image(systemName: "function")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Go to symbol...", text: $viewModel.searchText)
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
                    ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, item in
                        SymbolRow(item: item, isSelected: index == viewModel.selectedIndex)
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect(item)
                                onDismiss()
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

    // MARK: - Empty state

    private var emptyState: some View {
        Text("No symbols found")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .padding(.vertical, 20)
    }

    // MARK: - Keyboard monitor

    private func setupKeyMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 125: viewModel.selectNext();     return nil
            case 126: viewModel.selectPrevious(); return nil
            case 36, 76:
                if let item = viewModel.selectedItem {
                    onSelect(item)
                    onDismiss()
                }
                return nil
            case 53:
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

// MARK: - Symbol Row

private struct SymbolRow: View {
    let item: SymbolPickerViewModel.SymbolItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Indent for nested symbols
            if item.depth > 0 {
                Spacer().frame(width: CGFloat(item.depth) * 12)
            }

            Image(systemName: item.iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? .white : item.iconColor)
                .frame(width: 18, height: 18)

            Text(item.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .lineLimit(1)

            if let detail = item.detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? .white.opacity(0.6) : .secondary)
                    .lineLimit(1)
            }

            Spacer()

            if !item.kindLabel.isEmpty {
                Text(item.kindLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? .white.opacity(0.6) : .secondary.opacity(0.6))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isSelected ? .white.opacity(0.15) : .primary.opacity(0.07))
                    )
            }

            Text(":\(item.line + 1)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(isSelected ? .white.opacity(0.5) : .secondary.opacity(0.5))
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
