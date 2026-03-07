import Foundation

enum GitFileStatus: Equatable {
    case modified
    case added
    case deleted
    case renamed
    case copied
    case untracked
    case conflicted

    var badgeText: String {
        switch self {
        case .modified:
            return "M"
        case .added:
            return "A"
        case .deleted:
            return "D"
        case .renamed:
            return "R"
        case .copied:
            return "C"
        case .untracked:
            return "?"
        case .conflicted:
            return "U"
        }
    }

    var priority: Int {
        switch self {
        case .conflicted:
            return 7
        case .deleted:
            return 6
        case .modified:
            return 5
        case .added:
            return 4
        case .renamed:
            return 3
        case .copied:
            return 2
        case .untracked:
            return 1
        }
    }

    static func from(indexStatus: Character, workTreeStatus: Character) -> GitFileStatus? {
        let pair = String([indexStatus, workTreeStatus])
        let conflictPairs: Set<String> = ["DD", "AU", "UD", "UA", "DU", "AA", "UU"]
        if conflictPairs.contains(pair) {
            return .conflicted
        }

        if indexStatus == "?" && workTreeStatus == "?" {
            return .untracked
        }

        if indexStatus == "!" && workTreeStatus == "!" {
            return nil
        }

        if indexStatus == "R" || workTreeStatus == "R" {
            return .renamed
        }

        if indexStatus == "C" || workTreeStatus == "C" {
            return .copied
        }

        if indexStatus == "A" || workTreeStatus == "A" {
            return .added
        }

        if indexStatus == "D" || workTreeStatus == "D" {
            return .deleted
        }

        if indexStatus == "U" || workTreeStatus == "U" {
            return .conflicted
        }

        if indexStatus == "M" || workTreeStatus == "M" || indexStatus == "T" || workTreeStatus == "T" {
            return .modified
        }

        return nil
    }
}
