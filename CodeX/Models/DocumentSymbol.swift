import Foundation
import SwiftUI

/// Represents a symbol extracted from a document via LSP (Language Server Protocol)
public struct DocumentSymbol: Codable, Identifiable, Hashable, Sendable {
    public let name: String
    public let detail: String?
    public let kind: Int
    public let range: LSPRange
    public let selectionRange: LSPRange
    public let children: [DocumentSymbol]?

    public var id: String {
        "\(name)-\(range.start.line)-\(range.start.character)"
    }
    
    // LSP SymbolKind Mapping (https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#symbolKind)
    public var iconName: String {
        switch kind {
        case 1: return "doc.text.fill" // File
        case 2: return "shippingbox.fill" // Module
        case 3: return "building.columns.fill" // Namespace
        case 4: return "cube.box.fill" // Package
        case 5: return "c.square.fill" // Class
        case 6: return "m.square.fill" // Method
        case 7: return "p.square.fill" // Property
        case 8: return "f.square.fill" // Field
        case 9: return "c.circle.fill" // Constructor
        case 10: return "e.square.fill" // Enum
        case 11: return "i.square.fill" // Interface
        case 12: return "f.cursive.circle.fill" // Function
        case 13: return "v.square.fill" // Variable
        case 14: return "c.square" // Constant
        case 15: return "t.square.fill" // String
        case 16: return "number.square.fill" // Number
        case 17: return "checkmark.square.fill" // Boolean
        case 18: return "list.bullet.rectangle.fill" // Array
        case 19: return "curlybraces.square.fill" // Object
        case 20: return "key.fill" // Key
        case 21: return "n.square.fill" // Null
        case 22: return "e.circle.fill" // EnumMember
        case 23: return "s.square.fill" // Struct
        case 24: return "e.square" // Event
        case 25: return "op.square.fill" // Operator
        case 26: return "t.circle.fill" // TypeParameter
        default: return "circle.fill"
        }
    }
    
    public var iconColor: Color {
        switch kind {
        case 5, 11, 23: return .purple // Class, Interface, Struct
        case 6, 12: return .orange // Method, Function
        case 7, 8, 13, 14: return .blue // Property, Field, Variable, Constant
        case 10, 22: return .green // Enum, EnumMember
        case 2: return .red // Module
        default: return .gray
        }
    }
}

public struct LSPRange: Codable, Hashable, Sendable {
    public let start: LSPPosition
    public let end: LSPPosition
}

public struct LSPPosition: Codable, Hashable, Sendable {
    public let line: Int
    public let character: Int
}
