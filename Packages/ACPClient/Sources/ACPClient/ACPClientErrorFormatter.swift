import ACPModel
import Foundation

public enum ACPClientErrorFormatter {
    public static func debugDescription(for error: Error) -> String {
        if let clientError = error as? ClientError {
            return debugDescription(for: clientError)
        }

        let nsError = error as NSError
        var components = [
            "type=\(String(describing: type(of: error)))",
            "message=\(error.localizedDescription)"
        ]

        if !(nsError.domain == NSCocoaErrorDomain && nsError.code == 0) {
            components.append("nsError=\(nsError.domain)(\(nsError.code))")
        }

        if !nsError.userInfo.isEmpty {
            components.append("userInfo=\(nsError.userInfo)")
        }

        return components.joined(separator: " | ")
    }

    private static func debugDescription(for error: ClientError) -> String {
        switch error {
        case .processNotRunning:
            return "ClientError.processNotRunning"
        case .processFailed(let code):
            return "ClientError.processFailed | exitCode=\(code)"
        case .invalidResponse:
            return "ClientError.invalidResponse"
        case .requestTimeout:
            return "ClientError.requestTimeout"
        case .encodingError:
            return "ClientError.encodingError"
        case .decodingError(let underlying):
            return "ClientError.decodingError | underlying=\(debugDescription(for: underlying))"
        case .agentError(let jsonError):
            var components = [
                "ClientError.agentError",
                "code=\(jsonError.code)",
                "message=\(jsonError.message)"
            ]

            if let data = jsonError.data?.value {
                components.append("data=\(String(describing: data))")
            }

            return components.joined(separator: " | ")
        case .delegateNotSet:
            return "ClientError.delegateNotSet"
        case .fileNotFound(let path):
            return "ClientError.fileNotFound | path=\(path)"
        case .fileOperationFailed(let message):
            return "ClientError.fileOperationFailed | message=\(message)"
        case .transportError(let message):
            return "ClientError.transportError | message=\(message)"
        case .connectionClosed:
            return "ClientError.connectionClosed"
        }
    }
}