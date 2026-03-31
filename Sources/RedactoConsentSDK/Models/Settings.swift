import Foundation

public struct ConsentSettings {
    public var button: ButtonSettings?
    public var link: String?
    public var borderRadius: String?
    public var backgroundColor: String?
    public var headingColor: String?
    public var textColor: String?
    public var borderColor: String?
    public var font: String?

    public init(
        button: ButtonSettings? = nil,
        link: String? = nil,
        borderRadius: String? = nil,
        backgroundColor: String? = nil,
        headingColor: String? = nil,
        textColor: String? = nil,
        borderColor: String? = nil,
        font: String? = nil
    ) {
        self.button = button
        self.link = link
        self.borderRadius = borderRadius
        self.backgroundColor = backgroundColor
        self.headingColor = headingColor
        self.textColor = textColor
        self.borderColor = borderColor
        self.font = font
    }
}

public struct ButtonSettings {
    public var accept: ButtonStyle?
    public var decline: ButtonStyle?
    public var language: LanguageButtonStyle?

    public init(accept: ButtonStyle? = nil, decline: ButtonStyle? = nil, language: LanguageButtonStyle? = nil) {
        self.accept = accept
        self.decline = decline
        self.language = language
    }
}

public struct ButtonStyle {
    public var backgroundColor: String
    public var textColor: String

    public init(backgroundColor: String, textColor: String) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
    }
}

public struct LanguageButtonStyle {
    public var backgroundColor: String
    public var textColor: String
    public var selectedBackgroundColor: String?
    public var selectedTextColor: String?

    public init(backgroundColor: String, textColor: String, selectedBackgroundColor: String? = nil, selectedTextColor: String? = nil) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.selectedBackgroundColor = selectedBackgroundColor
        self.selectedTextColor = selectedTextColor
    }
}
