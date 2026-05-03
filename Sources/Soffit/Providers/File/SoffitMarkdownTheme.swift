import MarkdownUI
import SwiftUI

/// Soffit's markdown theme. Wraps MarkdownUI's `.gitHub` theme but overrides
/// the colours that broke in dark mode — table cells, code backgrounds, link
/// hue, and dividers all needed dark-aware values.
func soffitMarkdownTheme(dark: Bool) -> Theme {
    let textColor: Color           = dark ? Color(white: 0.93)  : Color(white: 0.10)
    let secondaryTextColor: Color  = dark ? Color(white: 0.72)  : Color(white: 0.30)
    let linkColor: Color           = dark ? Color(red: 0.45, green: 0.78, blue: 1.00)
                                          : Color(red: 0.05, green: 0.42, blue: 0.85)
    let codeBackground: Color      = dark ? Color(white: 0.18)  : Color(white: 0.95)
    let codeBlockBackground: Color = dark ? Color(white: 0.13)  : Color(white: 0.97)
    let tableBorder: Color         = dark ? Color(white: 0.30)  : Color(white: 0.85)
    let tableHeaderBg: Color       = dark ? Color(white: 0.18)  : Color(white: 0.96)
    let tableRowAltBg: Color       = dark ? Color(white: 0.10)  : Color(white: 0.99)
    let blockquoteRule: Color      = dark ? Color(white: 0.40)  : Color(white: 0.75)
    let dividerColor: Color        = dark ? Color(white: 0.25)  : Color(white: 0.85)

    return Theme.gitHub
        .text {
            ForegroundColor(textColor)
            FontSize(14)
        }
        .link {
            ForegroundColor(linkColor)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.9))
            BackgroundColor(codeBackground)
            ForegroundColor(textColor)
        }
        .codeBlock { configuration in
            configuration.label
                .markdownTextStyle {
                    FontFamilyVariant(.monospaced)
                    FontSize(.em(0.92))
                    ForegroundColor(textColor)
                }
                .padding(12)
                .background(codeBlockBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .markdownMargin(top: .em(0.5), bottom: .em(0.8))
        }
        .blockquote { configuration in
            configuration.label
                .padding(.leading, 14)
                .padding(.vertical, 2)
                .overlay(alignment: .leading) {
                    Rectangle().fill(blockquoteRule).frame(width: 3)
                }
                .markdownTextStyle { ForegroundColor(secondaryTextColor) }
        }
        .table { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .markdownTableBorderStyle(.init(color: tableBorder))
                .markdownTableBackgroundStyle(
                    .alternatingRows(tableHeaderBg.opacity(dark ? 0.6 : 1.0),
                                     tableRowAltBg)
                )
        }
        .tableCell { configuration in
            configuration.label
                .markdownTextStyle { ForegroundColor(textColor) }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .thematicBreak {
            Divider().background(dividerColor)
        }
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle { FontWeight(.bold); FontSize(28); ForegroundColor(textColor) }
                .markdownMargin(top: .em(0.0), bottom: .em(0.4))
                .padding(.bottom, 6)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(dividerColor).frame(height: 0.5)
                }
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle { FontWeight(.bold); FontSize(22); ForegroundColor(textColor) }
                .markdownMargin(top: .em(0.8), bottom: .em(0.3))
                .padding(.bottom, 4)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(dividerColor).frame(height: 0.5)
                }
        }
        .heading3 { configuration in
            configuration.label
                .markdownTextStyle { FontWeight(.semibold); FontSize(18); ForegroundColor(textColor) }
                .markdownMargin(top: .em(0.7), bottom: .em(0.2))
        }
        .heading4 { configuration in
            configuration.label
                .markdownTextStyle { FontWeight(.semibold); FontSize(15.5); ForegroundColor(textColor) }
                .markdownMargin(top: .em(0.6), bottom: .em(0.2))
        }
}
