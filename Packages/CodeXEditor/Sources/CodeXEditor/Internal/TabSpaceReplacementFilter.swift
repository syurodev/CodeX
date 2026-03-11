import Foundation
import TextFormation
import TextStory

/// Replaces a Tab keystroke with spaces according to `tabWidth`.
/// Equivalent to CodeEditSourceEditor's `TabReplacementFilter`, which lives
/// inside that package and is not exported by TextFormation itself.
struct TabSpaceReplacementFilter: Filter {
    let tabWidth: Int

    func processMutation(
        _ mutation: TextMutation,
        in interface: TextInterface,
        with providers: WhitespaceProviders
    ) -> FilterAction {
        guard mutation.string == "\t", mutation.delta > 0 else { return .none }
        let spaces = String(repeating: " ", count: tabWidth)
        interface.applyMutation(
            TextMutation(string: spaces, range: mutation.range, limit: mutation.limit)
        )
        return .discard
    }
}
