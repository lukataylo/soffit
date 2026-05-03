import SwiftUI

/// Floating toolbar pill: mode toggle (Preview / Source / Split) + formatting tools
/// for the markdown file that's active in the pane. Rendered above the unified card.
struct MarkdownToolbarPill: View {
    @ObservedObject var state: MarkdownActiveState
    let fileName: String

    var body: some View {
        HStack(spacing: 10) {
            modeSegment
            divider
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    formattingTools
                    divider
                    Text(fileName)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
    }

    private var divider: some View {
        Rectangle().fill(Color.primary.opacity(0.12)).frame(width: 1, height: 14)
    }

    private var modeSegment: some View {
        HStack(spacing: 3) {
            ForEach(MarkdownPanelMode.allCases) { m in
                modePill(m)
            }
        }
    }

    private func modePill(_ m: MarkdownPanelMode) -> some View {
        let active = state.mode == m
        return HStack(spacing: 4) {
            Image(systemName: m.icon)
                .font(.system(size: 10, weight: .semibold))
            Text(m.label)
                .font(.system(size: 11, weight: active ? .semibold : .medium))
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: true)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(active ? Color.accentColor.opacity(0.16) : Color.clear)
        )
        .foregroundStyle(active ? Color.accentColor : Color.secondary)
        .contentShape(Capsule())
        .onTapGesture { state.mode = m }
    }

    private var formattingTools: some View {
        HStack(spacing: 2) {
            headingMenu
            toolButton("bold", help: "Bold") { state.commands.wrap(prefix: "**", suffix: "**", placeholder: "bold") }
            toolButton("italic", help: "Italic") { state.commands.wrap(prefix: "*", suffix: "*", placeholder: "italic") }
            toolButton("chevron.left.forwardslash.chevron.right", help: "Inline code") { state.commands.wrap(prefix: "`", suffix: "`", placeholder: "code") }
            toolButton("list.bullet", help: "Bulleted list") { state.commands.prefixLines("- ") }
            toolButton("list.number", help: "Numbered list") { state.commands.prefixLines("1. ") }
            toolButton("list.bullet.indent", help: "Task list") { state.commands.prefixLines("- [ ] ") }
            toolButton("text.quote", help: "Quote") { state.commands.prefixLines("> ") }
            toolButton("link", help: "Link") { state.commands.wrap(prefix: "[", suffix: "](https://)", placeholder: "text") }
            tableButton
        }
    }

    private var headingMenu: some View {
        Menu {
            Button("Heading 1") { state.commands.prefixLines("# ") }
            Button("Heading 2") { state.commands.prefixLines("## ") }
            Button("Heading 3") { state.commands.prefixLines("### ") }
            Button("Heading 4") { state.commands.prefixLines("#### ") }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "textformat.size")
                    .font(.system(size: 11, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
            }
            .foregroundStyle(.secondary)
            .frame(width: 32, height: 22)
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

    @State private var showTable = false

    private var tableButton: some View {
        Image(systemName: "tablecells")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 24, height: 22)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.05)))
            .contentShape(Rectangle())
            .onTapGesture { showTable = true }
            .help("Insert table")
            .popover(isPresented: $showTable, arrowEdge: .bottom) {
                TableInsertPopover { rows, cols in
                    state.commands.insertTable(rows: rows, cols: cols)
                    showTable = false
                }
            }
    }
}
