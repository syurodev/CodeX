import SwiftUI
import CodeEditLanguages

struct StatusBarView: View {
    @Environment(\.colorScheme) private var colorScheme

    static let height: CGFloat = 28

    let document: EditorDocument?
    let cursorPosition: (line: Int, column: Int)

    var body: some View {
        HStack(spacing: 12) {
            if let doc = document {
                Spacer(minLength: 0)

                Text(doc.language.tsName.uppercased())
                    .foregroundStyle(.secondary)

                Divider()
                    .frame(height: 12)

                Text("Ln \(cursorPosition.line), Col \(cursorPosition.column)")
                    .foregroundStyle(.secondary)

                if doc.isModified {
                    Divider()
                        .frame(height: 12)

                    Circle()
                        .fill(.orange)
                        .frame(width: 8, height: 8)
                    Text("Modified")
                        .foregroundStyle(.orange)
                }
            } else {
                Text("No file open")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .font(.system(size: 11, weight: .medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Self.height)
        .background(.bar)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(colorScheme == .dark ? 0.08 : 0.14))
                .frame(height: 1)
        }
    }
}
