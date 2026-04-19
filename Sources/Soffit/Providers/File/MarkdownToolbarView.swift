import SwiftUI

struct MarkdownToolbarView: View {
    @ObservedObject var commands: MarkdownEditorCommands
    @State private var showTablePopover = false
    @State private var showHeadingMenu = false

    var body: some View {
        HStack(spacing: 4) {
            headingMenu
            divider
            toolButton("bold", help: "Bold (⌘B)") { commands.wrap(prefix: "**", suffix: "**", placeholder: "bold") }
            toolButton("italic", help: "Italic (⌘I)") { commands.wrap(prefix: "*", suffix: "*", placeholder: "italic") }
            toolButton("chevron.left.forwardslash.chevron.right", help: "Inline code") {
                commands.wrap(prefix: "`", suffix: "`", placeholder: "code")
            }
            toolButton("curlybraces.square", help: "Code block") {
                commands.wrap(prefix: "```\n", suffix: "\n```", placeholder: "code")
            }
            divider
            toolButton("list.bullet", help: "Bulleted list") { commands.prefixLines("- ") }
            toolButton("list.number", help: "Numbered list") { commands.prefixLines("1. ") }
            toolButton("list.bullet.indent", help: "Task list") { commands.prefixLines("- [ ] ") }
            toolButton("text.quote", help: "Quote") { commands.prefixLines("> ") }
            divider
            toolButton("link", help: "Link") {
                commands.wrap(prefix: "[", suffix: "](https://)", placeholder: "text")
            }
            tableButton
            toolButton("minus", help: "Horizontal rule") { commands.insert("\n\n---\n\n") }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(nsColor: .underPageBackgroundColor).opacity(0.5))
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.12))
            .frame(width: 1, height: 14)
            .padding(.horizontal, 2)
    }

    private var headingMenu: some View {
        Menu {
            Button("Heading 1") { commands.prefixLines("# ") }
            Button("Heading 2") { commands.prefixLines("## ") }
            Button("Heading 3") { commands.prefixLines("### ") }
            Button("Heading 4") { commands.prefixLines("#### ") }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "textformat.size")
                    .font(.system(size: 11, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(.secondary)
            .frame(width: 34, height: 22)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.05)))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Heading")
    }

    private func toolButton(_ icon: String, help: String, action: @escaping () -> Void) -> some View {
        Image(systemName: icon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 24, height: 22)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.05)))
            .contentShape(Rectangle())
            .onTapGesture { action() }
            .help(help)
    }

    private var tableButton: some View {
        Image(systemName: "tablecells")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 24, height: 22)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.05)))
            .contentShape(Rectangle())
            .onTapGesture { showTablePopover = true }
            .help("Insert table")
            .popover(isPresented: $showTablePopover, arrowEdge: .bottom) {
                TableInsertPopover { rows, cols in
                    commands.insertTable(rows: rows, cols: cols)
                    showTablePopover = false
                }
            }
    }
}
