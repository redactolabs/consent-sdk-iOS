import SwiftUI

/// Language selector using native iOS Menu for reliable rendering.
/// Prevents clipping issues that occur with custom overlay dropdowns.
struct LanguageSelectorView: View {
    let languages: [String]
    @Binding var selectedLanguage: String
    @Binding var isDropdownOpen: Bool
    let settings: ConsentSettings?
    /// How a language is named in the chip and the menu.
    var label: (String) -> String = { $0 }
    /// The modal notice's themed chip; nil keeps the settings-driven look.
    var chip: NoticeChipPaint?
    var fontSize: CGFloat = 13

    private var buttonBg: Color {
        if let chip { return chip.background }
        if let bg = settings?.button?.language?.backgroundColor {
            return Color(hex: bg)
        }
        return Color(hex: "#f2f4f7")
    }

    private var buttonText: Color {
        if let chip { return chip.foreground }
        if let tc = settings?.button?.language?.textColor {
            return Color(hex: tc)
        }
        return Color(hex: "#344054")
    }

    private var borderColor: Color { chip?.border ?? Color(hex: "#d0d5dd") }
    private var radius: CGFloat { chip?.radius ?? 6 }

    var body: some View {
        Menu {
            ForEach(languages, id: \.self) { lang in
                Button {
                    selectedLanguage = lang
                } label: {
                    if lang == selectedLanguage {
                        Label(label(lang), systemImage: "checkmark")
                    } else {
                        Text(label(lang))
                    }
                }
                .accessibilityLabel("Select \(label(lang)) language")
            }
        } label: {
            HStack(spacing: 4) {
                Text(label(selectedLanguage))
                    .noticeFont(size: fontSize, weight: chip == nil ? .medium : .regular)
                    .foregroundColor(buttonText)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(buttonText)
            }
            .padding(.horizontal, chip == nil ? 10 : 9)
            .padding(.vertical, chip == nil ? 6 : 3)
            .frame(minHeight: chip?.height)
            .background(buttonBg)
            .cornerRadius(radius)
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .accessibilityLabel(NoticeCopy.languageChip(label(selectedLanguage)))
    }
}
