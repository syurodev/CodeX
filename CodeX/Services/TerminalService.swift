import Foundation

struct TerminalSessionConfig {
    let shell: String
    let arguments: [String]
    let environment: [String]
    let initialWorkingDirectory: URL
}

class TerminalService {

    func makeConfig(workingDirectory: URL?) -> TerminalSessionConfig {
        let shell = Self.userShell()
        return TerminalSessionConfig(
            shell: shell,
            arguments: Self.loginArguments(for: shell),
            environment: Self.buildEnvironment(),
            initialWorkingDirectory: workingDirectory ?? FileManager.default.homeDirectoryForCurrentUser
        )
    }

    static func userShell() -> String {
        if let shell = ProcessInfo.processInfo.environment["SHELL"], !shell.isEmpty {
            return shell
        }
        if let pw = getpwuid(getuid()), let shell = String(validatingUTF8: pw.pointee.pw_shell), !shell.isEmpty {
            return shell
        }
        return "/bin/zsh"
    }

    static func buildEnvironment() -> [String] {
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        if env["LANG"] == nil {
            env["LANG"] = "en_US.UTF-8"
        }
        return env.map { "\($0.key)=\($0.value)" }
    }

    private static func loginArguments(for shell: String) -> [String] {
        let name = URL(fileURLWithPath: shell).lastPathComponent
        switch name {
        case "bash":
            return ["-l", "-i"]
        default:
            return ["-l"]
        }
    }
}
