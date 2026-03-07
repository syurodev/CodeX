import SwiftUI

extension Color {
    // MARK: - Editor UI Colors

    static let editorBackground = Color(nsColor: .textBackgroundColor)
    static let gutterBackground = Color(red: 0.95, green: 0.95, blue: 0.96)
    static let gutterText = Color.secondary
    static let statusBarBackground = Color(nsColor: .windowBackgroundColor)

    // MARK: - Agent Panel Colors

    static let agentPanelBackground = Color(nsColor: .windowBackgroundColor)
    static let agentPanelSecondaryBackground = Color(nsColor: .underPageBackgroundColor)
    static let agentPanelSurface = Color(nsColor: .controlBackgroundColor)
    static let agentPanelElevatedSurface = Color(nsColor: .textBackgroundColor)
    static let agentPanelSeparator = Color(nsColor: .separatorColor)
}
