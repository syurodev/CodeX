import AppKit
import SwiftUI

struct WindowTitlebarContent<Content: View>: NSViewRepresentable {
    let id: String
    let onLeadingSafeAreaChange: ((CGFloat) -> Void)?
    let content: Content

    init(
        id: String,
        onLeadingSafeAreaChange: ((CGFloat) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.id = id
        self.onLeadingSafeAreaChange = onLeadingSafeAreaChange
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(id: id, onLeadingSafeAreaChange: onLeadingSafeAreaChange)
    }

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(rootView: AnyView(content))

        DispatchQueue.main.async {
            context.coordinator.attachIfNeeded(to: nsView.window)
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator {
        private let id: String
        private let onLeadingSafeAreaChange: ((CGFloat) -> Void)?
        private let hostingView = PassthroughHostingView(rootView: AnyView(EmptyView()))

        private weak var attachedWindow: NSWindow?
        private weak var titlebarContainer: NSView?
        private var activeConstraints: [NSLayoutConstraint] = []
        private var lastReportedLeadingSafeArea: CGFloat = .nan

        init(
            id: String,
            onLeadingSafeAreaChange: ((CGFloat) -> Void)?
        ) {
            self.id = id
            self.onLeadingSafeAreaChange = onLeadingSafeAreaChange
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            hostingView.identifier = NSUserInterfaceItemIdentifier(id)
        }

        func update(rootView: AnyView) {
            hostingView.rootView = rootView
            hostingView.invalidateIntrinsicContentSize()
            hostingView.needsLayout = true
        }

        func attachIfNeeded(to window: NSWindow?) {
            guard
                let window,
                let anchorView = window.standardWindowButton(.closeButton),
                let titlebarContainer = anchorView.superview
            else {
                detach()
                return
            }

            configureWindowAppearance(window)

            let needsReattach =
                attachedWindow !== window ||
                self.titlebarContainer !== titlebarContainer ||
                hostingView.superview !== titlebarContainer

            if needsReattach {
                detach()
                attachedWindow = window
                self.titlebarContainer = titlebarContainer
                titlebarContainer.addSubview(hostingView, positioned: .below, relativeTo: nil)
                installConstraints(in: titlebarContainer)
            }

            reportLeadingSafeArea(
                in: titlebarContainer,
                anchorView: anchorView
            )
        }

        private func configureWindowAppearance(_ window: NSWindow) {
            window.titleVisibility = .hidden
            window.titlebarSeparatorStyle = .none
        }

        func detach() {
            NSLayoutConstraint.deactivate(activeConstraints)
            activeConstraints.removeAll()
            hostingView.removeFromSuperview()
            attachedWindow = nil
            titlebarContainer = nil
        }

        private func installConstraints(in titlebarContainer: NSView) {
            NSLayoutConstraint.deactivate(activeConstraints)

            let leading = hostingView.leadingAnchor.constraint(equalTo: titlebarContainer.leadingAnchor)
            let trailing = hostingView.trailingAnchor.constraint(equalTo: titlebarContainer.trailingAnchor)
            let top = hostingView.topAnchor.constraint(equalTo: titlebarContainer.topAnchor)
            let bottom = hostingView.bottomAnchor.constraint(equalTo: titlebarContainer.bottomAnchor)

            activeConstraints = [leading, trailing, top, bottom]
            NSLayoutConstraint.activate(activeConstraints)
        }

        private func reportLeadingSafeArea(
            in titlebarContainer: NSView,
            anchorView: NSView
        ) {
            guard let onLeadingSafeAreaChange else { return }

            let nativeMaxX = maxNativeLeadingControlMaxX(
                in: titlebarContainer,
                anchorView: anchorView
            ) ?? anchorView.frame.maxX
            let safeLeadingArea = max(78, nativeMaxX + 12)

            guard abs(safeLeadingArea - lastReportedLeadingSafeArea) > 0.5 else {
                return
            }

            lastReportedLeadingSafeArea = safeLeadingArea

            DispatchQueue.main.async {
                onLeadingSafeAreaChange(safeLeadingArea)
            }
        }

        private func maxNativeLeadingControlMaxX(
            in titlebarContainer: NSView,
            anchorView: NSView
        ) -> CGFloat? {
            let anchorMidY = titlebarContainer.convert(anchorView.bounds, from: anchorView).midY
            var result: CGFloat?

            func visit(_ view: NSView) {
                for subview in view.subviews {
                    guard
                        subview !== hostingView,
                        !subview.isDescendant(of: hostingView),
                        !subview.isHidden,
                        subview.alphaValue > 0.01
                    else {
                        continue
                    }

                    if let control = subview as? NSControl {
                        let frame = titlebarContainer.convert(control.bounds, from: control)
                        let isInLeadingRegion = frame.maxX <= titlebarContainer.bounds.midX
                        let isNearTitlebarCenter = abs(frame.midY - anchorMidY) <= 24
                        let looksLikeCompactControl = frame.width > 0 && frame.width <= 240

                        if isInLeadingRegion && isNearTitlebarCenter && looksLikeCompactControl {
                            result = max(result ?? 0, frame.maxX)
                        }
                    }

                    visit(subview)
                }
            }

            visit(titlebarContainer)
            return result
        }
    }
}

private final class PassthroughHostingView: NSHostingView<AnyView> {
    // Placed at z-index 0 (behind native titlebar controls) so native controls
    // are hit-tested first. Allow window dragging from non-interactive background areas.
    override var mouseDownCanMoveWindow: Bool { true }
}