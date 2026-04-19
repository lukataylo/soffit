import SwiftUI

struct TableInsertPopover: View {
    let onInsert: (Int, Int) -> Void
    @State private var rows = 3
    @State private var cols = 3
    private let maxRows = 8
    private let maxCols = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Insert table")
                .font(.system(size: 13, weight: .bold))

            VStack(spacing: 3) {
                ForEach(1...maxRows, id: \.self) { r in
                    HStack(spacing: 3) {
                        ForEach(1...maxCols, id: \.self) { c in
                            Rectangle()
                                .fill(r <= rows && c <= cols
                                      ? Color.accentColor
                                      : Color.primary.opacity(0.08))
                                .overlay(
                                    Rectangle().stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
                                )
                                .frame(width: 22, height: 16)
                                .contentShape(Rectangle())
                                .onHover { hover in
                                    if hover { rows = r; cols = c }
                                }
                                .onTapGesture { onInsert(r, c) }
                        }
                    }
                }
            }

            HStack {
                Text("\(rows) × \(cols)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                Button("Insert") { onInsert(rows, cols) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 260)
    }
}
