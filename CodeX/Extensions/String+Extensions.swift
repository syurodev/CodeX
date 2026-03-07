import Foundation

extension String {
    var lineCount: Int {
        var count = 0
        self.enumerateLines { _, _ in
            count += 1
        }
        return max(count, 1)
    }

    func lineAndColumn(for offset: Int) -> (line: Int, column: Int) {
        let clampedOffset = min(offset, self.count)
        var line = 1
        var column = 1
        var currentOffset = 0

        for char in self {
            if currentOffset >= clampedOffset { break }
            if char == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
            currentOffset += 1
        }

        return (line, column)
    }
}
