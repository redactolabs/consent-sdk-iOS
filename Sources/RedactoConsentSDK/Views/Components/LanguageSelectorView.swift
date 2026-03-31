import SwiftUI

/// Language selector using native iOS Menu for reliable rendering.
/// Prevents clipping issues that occur with custom overlay dropdowns.
struct LanguageSelectorView: View {
    let languages: [String]
    @Binding var selectedLanguage: String
    @Binding var isDropdownOpen: Bool
    let settings: ConsentSettings?

    private var buttonBg: Color {
        if let bg = settings?.button?.language?.backgroundColor {
            return Color(hex: bg)
        }
        return Color(hex: "#f2f4f7")
    }

    private var buttonText: Color {
        if let tc = settings?.button?.language?.textColor {
            return Color(hex: tc)
        }
        return Color(hex: "#344054")
    }

    var body: some View {
        Menu {
            ForEach(languages, id: \.self) { lang in
                Button {
                    selectedLanguage = lang
                } label: {
                    if lang == selectedLanguage {
                        Label(lang, systemImage: "checkmark")
                    } else {
                        Text(lang)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedLanguage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(buttonText)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(buttonText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(buttonBg)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(hex: "#d0d5dd"), lineWidth: 1)
            )
        }
    }
}
