import SwiftUI
import CodeEditLanguages

struct StatusBarView: View {
    let document: EditorDocument?
    let cursorPosition: (line: Int, column: Int)

    var body: some View {
        HStack(spacing: 16) {
            if let doc = document {
                Text(doc.fileName)
                    .fontWeight(.medium)

                Divider()
                    .frame(height: 12)

                Text(doc.language.tsName.uppercased())
                    .foregroundStyle(.secondary)

                Divider()
                    .frame(height: 12)

                Text("Ln \(cursorPosition.line), Col \(cursorPosition.column)")
                    .foregroundStyle(.secondary)

                Spacer()

                if doc.isModified {
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
        .font(.system(size: 11))
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.statusBarBackground)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
