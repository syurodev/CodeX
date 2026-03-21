import Foundation

struct AgentSlashCommand: Identifiable, Hashable {
    let name: String
    let description: String

    var id: String { name }
}

extension AgentProvider {
    var knownSlashCommands: [AgentSlashCommand] {
        switch id {
        case .claudeCode:    return .claudeCodeCommands
        case .githubCopilot: return .copilotCommands
        }
    }
}

extension [AgentSlashCommand] {
    static let claudeCodeCommands: [AgentSlashCommand] = [
        .init(name: "add-dir",           description: "Add a new working directory to the session"),
        .init(name: "agents",            description: "Manage agent configurations"),
        .init(name: "branch",            description: "Create a fork of the conversation at this point"),
        .init(name: "btw",               description: "Ask a quick side question without affecting history"),
        .init(name: "chrome",            description: "Configure Claude in Chrome settings"),
        .init(name: "clear",             description: "Clear conversation history and free up context"),
        .init(name: "color",             description: "Set prompt bar color for the session"),
        .init(name: "compact",           description: "Compact conversation with optional focus instructions"),
        .init(name: "config",            description: "Open the Settings interface"),
        .init(name: "context",           description: "Visualize current context usage"),
        .init(name: "copy",              description: "Copy the last assistant response to clipboard"),
        .init(name: "cost",              description: "Show token usage statistics"),
        .init(name: "desktop",           description: "Continue current session in Claude Code Desktop"),
        .init(name: "diff",              description: "Open interactive diff viewer for uncommitted changes"),
        .init(name: "doctor",            description: "Diagnose and verify Claude Code installation"),
        .init(name: "effort",            description: "Set model effort level (low / medium / high / max / auto)"),
        .init(name: "exit",              description: "Exit the CLI"),
        .init(name: "export",            description: "Export conversation as plain text"),
        .init(name: "extra-usage",       description: "Configure extra usage to continue past rate limits"),
        .init(name: "fast",              description: "Toggle fast mode on or off"),
        .init(name: "feedback",          description: "Submit feedback about Claude Code"),
        .init(name: "help",              description: "Show help and available commands"),
        .init(name: "hooks",             description: "View hook configurations for tool events"),
        .init(name: "ide",               description: "Manage IDE integrations and show status"),
        .init(name: "init",              description: "Initialize project with a CLAUDE.md guide"),
        .init(name: "insights",          description: "Generate a report analyzing Claude Code sessions"),
        .init(name: "install-github-app", description: "Set up the Claude GitHub Actions app"),
        .init(name: "install-slack-app", description: "Install the Claude Slack app"),
        .init(name: "keybindings",       description: "Open or create keybindings configuration file"),
        .init(name: "login",             description: "Sign in to your Anthropic account"),
        .init(name: "logout",            description: "Sign out from your Anthropic account"),
        .init(name: "mcp",               description: "Manage MCP server connections"),
        .init(name: "memory",            description: "Edit CLAUDE.md memory files"),
        .init(name: "mobile",            description: "Show QR code to download the Claude mobile app"),
        .init(name: "model",             description: "Select or change the AI model"),
        .init(name: "passes",            description: "Share a free week of Claude Code with friends"),
        .init(name: "permissions",       description: "View or update permissions"),
        .init(name: "plan",              description: "Enter plan mode"),
        .init(name: "plugin",            description: "Manage Claude Code plugins"),
        .init(name: "pr-comments",       description: "Fetch and display GitHub pull request comments"),
        .init(name: "privacy-settings",  description: "View and update privacy settings"),
        .init(name: "release-notes",     description: "View the full changelog"),
        .init(name: "reload-plugins",    description: "Reload all active plugins without restarting"),
        .init(name: "remote-control",    description: "Make session available for remote control from claude.ai"),
        .init(name: "remote-env",        description: "Configure the default remote environment"),
        .init(name: "rename",            description: "Rename the current session"),
        .init(name: "resume",            description: "Resume a previous conversation"),
        .init(name: "rewind",            description: "Rewind conversation to a previous point"),
        .init(name: "sandbox",           description: "Toggle sandbox mode"),
        .init(name: "security-review",   description: "Analyze pending changes for security vulnerabilities"),
        .init(name: "skills",            description: "List available skills"),
        .init(name: "stats",             description: "Visualize daily usage, session history, and streaks"),
        .init(name: "status",            description: "Open Settings interface (Status tab)"),
        .init(name: "statusline",        description: "Configure Claude Code's status line"),
        .init(name: "stickers",          description: "Order Claude Code stickers"),
        .init(name: "tasks",             description: "List and manage background tasks"),
        .init(name: "terminal-setup",    description: "Configure terminal keybindings"),
        .init(name: "theme",             description: "Change color theme"),
        .init(name: "upgrade",           description: "Open upgrade page to switch to a higher plan tier"),
        .init(name: "usage",             description: "Show plan usage limits and rate limit status"),
        .init(name: "vim",               description: "Toggle Vim editing mode"),
        .init(name: "voice",             description: "Toggle push-to-talk voice dictation"),
    ]

    static let copilotCommands: [AgentSlashCommand] = [
        .init(name: "add-dir",  description: "Add directory to file access allowlist"),
        .init(name: "agent",    description: "Browse available agents"),
        .init(name: "allow-all", description: "Enable all permissions for this session"),
        .init(name: "cd",       description: "Change working directory"),
        .init(name: "clear",    description: "Clear the conversation"),
        .init(name: "context",  description: "Show token usage"),
        .init(name: "cwd",      description: "Show current working directory"),
        .init(name: "delegate", description: "Create an AI-generated pull request"),
        .init(name: "mcp",      description: "Manage MCP servers"),
        .init(name: "model",    description: "Select AI model"),
        .init(name: "models",   description: "List available AI models"),
        .init(name: "new",      description: "Start a new conversation"),
        .init(name: "plan",     description: "Create an implementation plan"),
        .init(name: "review",   description: "Run the code review agent"),
        .init(name: "session",  description: "Show session info and checkpoints"),
        .init(name: "skills",   description: "Manage skills"),
        .init(name: "yolo",     description: "Enable all permissions for this session"),
    ]
}
