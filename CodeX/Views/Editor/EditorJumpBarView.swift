import SwiftUI
import AppKit

struct EditorJumpBarView: View {
    static let height: CGFloat = 26

    @Environment(AppViewModel.self) private var appViewModel
    let document: EditorDocument

    var body: some View {
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
                        segment: segment,
                        menuEntries: menuEntries(for: segment),
                        onActivate: handleActivate,
                        onReveal: revealInFinder,
                        onCopyRelativePath: copyRelativePath,
                        onCopyFullPath: copyFullPath
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
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
                    isCurrent: isFile
                )
            )
        }

        return builtSegments
    }

    private func fallbackSegments(for fileURL: URL) -> [JumpBarSegment] {
        let parentURL = fileURL.deletingLastPathComponent()
        return [
            JumpBarSegment(title: parentURL.lastPathComponent, url: parentURL, kind: .folder, isCurrent: false),
            JumpBarSegment(title: fileURL.lastPathComponent, url: fileURL, kind: .file, isCurrent: true)
        ]
    }

    private func menuEntries(for segment: JumpBarSegment) -> [URL] {
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

    private func handleActivate(_ url: URL) {
        if url.hasDirectoryPath {
            revealInFinder(url)
        } else {
            appViewModel.openFile(at: url, line: 1, column: 1)
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
    let segment: JumpBarSegment
    let menuEntries: [URL]
    let onActivate: (URL) -> Void
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
                        Section(segment.kind == .file ? "Open Nearby" : "Browse") {
                            ForEach(menuEntries, id: \.self) { entry in
                                Button(action: { onActivate(entry) }) {
                                    Label(entry.lastPathComponent, systemImage: iconName(for: entry))
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

            Text(segment.title)
                .lineLimit(1)
                .font(.system(size: 11, weight: segment.isCurrent ? .semibold : .medium))
                .foregroundStyle(segment.isCurrent ? .primary : .secondary)

            Image(systemName: "chevron.down")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.secondary.opacity(0.75))
        }
        .padding(.horizontal, 8)
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

private struct JumpBarSegment: Hashable, Identifiable {
    enum Kind {
        case project
        case folder
        case file
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
        }
    }
}