import SwiftUI
import AppKit
import CodeXEditor

struct EditorJumpBarView: View {
    static let height: CGFloat = 26

    @Environment(AppViewModel.self) private var appViewModel
    let document: EditorDocument

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 7, weight: .semibold))
                                .foregroundStyle(.secondary.opacity(0.55))
                                .padding(.horizontal, 4)
                        }
                        JumpBarSegmentView(
                            document: document,
                            segment: segment,
                            menuEntries: menuEntries(for: segment),
                            onActivate: handleActivate,
                            onReveal: revealInFinder,
                            onCopyRelativePath: copyRelativePath,
                            onCopyFullPath: copyFullPath
                        )
                        .id(segment.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
            }
            .scrollDisabled(true)
            .onAppear {
                if let last = segments.last {
                    proxy.scrollTo(last.id, anchor: .trailing)
                }
            }
            .onChange(of: segments.last?.id) {
                if let last = segments.last {
                    proxy.scrollTo(last.id, anchor: .trailing)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Self.height)
    }

    private var segments: [JumpBarSegment] {
        let fileURL = document.url.standardizedFileURL

        guard let rootURL = appViewModel.project?.rootURL.standardizedFileURL else {
            return fallbackSegments(for: fileURL)
        }

        let rootComponents = rootURL.pathComponents
        let fileComponents = fileURL.pathComponents

        guard fileComponents.starts(with: rootComponents) else {
            return fallbackSegments(for: fileURL)
        }

        let relativeComponents = Array(fileComponents.dropFirst(rootComponents.count))
        var currentURL = rootURL
        var builtSegments = [
            JumpBarSegment(
                title: rootURL.lastPathComponent,
                url: rootURL,
                kind: .project,
                isCurrent: false
            )
        ]

        for (index, component) in relativeComponents.enumerated() {
            currentURL.appendPathComponent(component)
            let isFile = index == relativeComponents.count - 1
            builtSegments.append(
                JumpBarSegment(
                    title: component,
                    url: currentURL,
                    kind: isFile ? .file : .folder,
                    isCurrent: isFile && document.currentSymbol == nil
                )
            )
        }
        
        if let symbol = document.currentSymbol {
            builtSegments.append(
                JumpBarSegment(
                    title: symbol.name,
                    url: fileURL,
                    kind: .symbol(symbol),
                    isCurrent: true
                )
            )
        }

        return builtSegments
    }

    private func fallbackSegments(for fileURL: URL) -> [JumpBarSegment] {
        let parentURL = fileURL.deletingLastPathComponent()
        var segments = [
            JumpBarSegment(title: parentURL.lastPathComponent, url: parentURL, kind: .folder, isCurrent: false),
            JumpBarSegment(title: fileURL.lastPathComponent, url: fileURL, kind: .file, isCurrent: document.currentSymbol == nil)
        ]
        if let symbol = document.currentSymbol {
            segments.append(JumpBarSegment(title: symbol.name, url: fileURL, kind: .symbol(symbol), isCurrent: true))
        }
        return segments
    }

    // Trả về mảng Any chứa URL hoặc DocumentSymbol để hiển thị trong Menu
    private func menuEntries(for segment: JumpBarSegment) -> [Any] {
        if case .symbol = segment.kind {
            // Hiển thị toàn bộ symbol ở root file
            return document.symbols
        }

        guard let baseURL = segment.menuDirectoryURL else { return [] }

        let urls = (try? FileManager.default.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return Array(urls.sorted(by: sortMenuEntries).prefix(24))
    }

    private func sortMenuEntries(lhs: URL, rhs: URL) -> Bool {
        let lhsIsDirectory = (try? lhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        let rhsIsDirectory = (try? rhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

        if lhsIsDirectory != rhsIsDirectory {
            return lhsIsDirectory && !rhsIsDirectory
        }

        return lhs.lastPathComponent.localizedCaseInsensitiveCompare(rhs.lastPathComponent) == .orderedAscending
    }

    private func handleActivate(_ entry: Any) {
        if let url = entry as? URL {
            if url.hasDirectoryPath {
                revealInFinder(url)
            } else {
                appViewModel.openFile(at: url, line: 1, column: 1)
            }
        } else if let symbol = entry as? DocumentSymbol {
            document.editorState.cursorPositions = [CursorPosition(line: symbol.range.start.line + 1, column: symbol.range.start.character + 1)]
        }
    }

    private func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func copyRelativePath(_ url: URL) {
        let string: String
        if let rootURL = appViewModel.project?.rootURL.standardizedFileURL,
           url.standardizedFileURL.pathComponents.starts(with: rootURL.pathComponents) {
            let relativeComponents = url.standardizedFileURL.pathComponents.dropFirst(rootURL.pathComponents.count)
            string = relativeComponents.isEmpty ? "." : relativeComponents.joined(separator: "/")
        } else {
            string = url.lastPathComponent
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    private func copyFullPath(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
    }
}

private struct JumpBarSegmentView: View {
    @Environment(AppViewModel.self) private var appViewModel
    let document: EditorDocument
    let segment: JumpBarSegment
    let menuEntries: [Any]
    let onActivate: (Any) -> Void
    let onReveal: (URL) -> Void
    let onCopyRelativePath: (URL) -> Void
    let onCopyFullPath: (URL) -> Void

    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if let url = segment.url {
                Menu {
                    if !menuEntries.isEmpty {
                        Section(segment.kind.isSymbol ? "Symbols" : (segment.kind == .file ? "Open Nearby" : "Browse")) {
                            ForEach(Array(menuEntries.enumerated()), id: \.offset) { _, entry in
                                if let urlEntry = entry as? URL {
                                    Button(action: { onActivate(urlEntry) }) {
                                        Label(urlEntry.lastPathComponent, systemImage: iconName(for: urlEntry))
                                    }
                                } else if let symbolEntry = entry as? DocumentSymbol {
                                    SymbolMenuItem(symbol: symbolEntry, onActivate: onActivate)
                                }
                            }
                        }

                        Divider()
                    }

                    Button("Reveal in Finder") { onReveal(url) }
                    Button("Copy Relative Path") { onCopyRelativePath(url) }
                    Button("Copy Full Path") { onCopyFullPath(url) }
                } label: {
                    label
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
            } else {
                label
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovering = hovering
            }
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    private var label: some View {
        HStack(spacing: 6) {
            Image(systemName: segment.iconName)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(segment.iconColor)
                .fixedSize()

            Text(segment.title)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(minWidth: 0)
                .font(.system(size: 11, weight: segment.isCurrent ? .semibold : .medium))
                .foregroundStyle(segment.isCurrent ? .primary : .secondary)
        }
        .padding(.horizontal, 8)
        .frame(minWidth: 0)
        .padding(.vertical, 3)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(backgroundColor)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.white.opacity(borderOpacity))
                }
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var backgroundColor: Color {
        if segment.isCurrent {
            return colorScheme == .dark ? .white.opacity(0.065) : .black.opacity(0.045)
        }
        if isHovering {
            return colorScheme == .dark ? .white.opacity(0.04) : .black.opacity(0.028)
        }
        return .clear
    }

    private var borderOpacity: Double {
        if segment.isCurrent {
            return colorScheme == .dark ? 0.08 : 0.07
        }
        return isHovering ? (colorScheme == .dark ? 0.05 : 0.045) : 0.0
    }

    private func iconName(for url: URL) -> String {
        url.hasDirectoryPath ? "folder.fill" : FileIcon.iconName(for: url.lastPathComponent)
    }
}

private struct SymbolMenuItem: View {
    let symbol: DocumentSymbol
    let onActivate: (Any) -> Void
    
    var body: some View {
        Button(action: { onActivate(symbol) }) {
            Label {
                Text(symbol.name)
            } icon: {
                Image(systemName: symbol.iconName)
            }
        }
        
        if let children = symbol.children, !children.isEmpty {
            ForEach(children) { child in
                SymbolMenuItem(symbol: child, onActivate: onActivate)
            }
        }
    }
}

private struct JumpBarSegment: Hashable, Identifiable {
    enum Kind: Hashable {
        case project
        case folder
        case file
        case symbol(DocumentSymbol)
        
        var isSymbol: Bool {
            if case .symbol = self { return true }
            return false
        }
    }

    let title: String
    let url: URL?
    let kind: Kind
    let isCurrent: Bool

    var id: String {
        (url?.path ?? title) + "::\(kind)"
    }

    var menuDirectoryURL: URL? {
        switch kind {
        case .project:
            return url
        case .folder, .file:
            return url?.deletingLastPathComponent()
        case .symbol:
            return nil
        }
    }

    var iconName: String {
        switch kind {
        case .project:
            return "shippingbox.fill"
        case .folder:
            return "folder.fill"
        case .file:
            return FileIcon.iconName(for: title)
        case .symbol(let symbol):
            return symbol.iconName
        }
    }

    var iconColor: Color {
        switch kind {
        case .project:
            return .orange
        case .folder:
            return .blue
        case .file:
            return FileIcon.iconColor(for: title)
        case .symbol(let symbol):
            return symbol.iconColor
        }
    }
}
