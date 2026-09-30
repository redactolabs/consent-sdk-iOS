import Foundation

/// Every date the Privacy Center prints. React formats with dayjs under the
/// picker language (`dayjs.locale(lng)`), so these follow `PCStrings.currentLanguage`
/// rather than the device locale; a language dayjs has no locale for prints
/// English, as it does there.
enum PrivacyCenterDateFormatters {
    static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static let iso8601NoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// dayjs locale ids React loads (lib/i18n.ts); anything else prints English.
    private static let dayjsLocales: [String: String] = [
        "hi": "hi", "te": "te", "mr": "mr", "ta": "ta", "ur": "ur", "gu": "gu",
        "kn": "kn", "ml": "ml", "pa": "pa_IN", "ne": "ne", "sd": "sd", "bn": "bn",
        "gom": "kok",
    ]

    /// dayjs prints Latin digits in every locale it ships; ICU would switch to
    /// the script's own digits for several of these.
    static func locale(for language: String = PCStrings.currentLanguage) -> Locale {
        let base = language == "en" ? "en_US" : (dayjsLocales[language] ?? "en_US")
        return Locale(identifier: "\(base)@numbers=latn")
    }

    private static let cacheLock = NSLock()
    private static var cache: [String: DateFormatter] = [:]

    private static func formatter(template: String, language: String, fixedEnglish: String? = nil) -> DateFormatter {
        let key = "\(language)|\(template)"
        cacheLock.lock(); defer { cacheLock.unlock() }
        if let cached = cache[key] { return cached }
        let f = DateFormatter()
        f.locale = locale(for: language)
        if let fixedEnglish, f.locale.identifier.hasPrefix("en_US") {
            f.dateFormat = fixedEnglish
        } else {
            f.setLocalizedDateFormatFromTemplate(template)
        }
        cache[key] = f
        return f
    }

    // MARK: - Parsing

    private static let fractionPattern = try? NSRegularExpression(pattern: #"(\.\d{3})\d+"#)
    private static let zonePattern = try? NSRegularExpression(pattern: #"(Z|[+-]\d{2}:?\d{2})$"#)

    private static let naive: [DateFormatter] = [
        "yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm",
        "yyyy-MM-dd HH:mm:ss.SSS", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd",
    ].map { format in
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = format
        return f
    }

    /// Accepts what the servers actually send: offsets or `Z`, microsecond
    /// fractions (Python's default), and naive timestamps, which read as local
    /// time the way `new Date()`/dayjs read them.
    static func parse(_ iso: String?) -> Date? {
        guard var value = iso?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        let full = NSRange(value.startIndex..., in: value)
        if let fractionPattern {
            value = fractionPattern.stringByReplacingMatches(in: value, range: full, withTemplate: "$1")
        }
        let range = NSRange(value.startIndex..., in: value)
        if zonePattern?.firstMatch(in: value, range: range) != nil {
            return iso8601.date(from: value) ?? iso8601NoFraction.date(from: value)
        }
        for f in naive {
            if let date = f.date(from: value) { return date }
        }
        return nil
    }

    // MARK: - Formats

    /// "Jan 15, 2025" (React `formatDateTime`, valid-till and receipts).
    static func formatDate(_ iso: String?) -> String {
        guard let date = parse(iso) else { return iso ?? "" }
        return formatter(template: "MMMdyyyy", language: PCStrings.currentLanguage, fixedEnglish: "MMM d, yyyy").string(from: date)
    }

    /// "15 Jan 2025" (React `formatDateShort`, case dates); "-" when absent.
    static func formatDateShort(_ iso: String?) -> String {
        guard let iso, !iso.isEmpty else { return "-" }
        guard let date = parse(iso) else { return iso }
        return formatter(template: "dMMMyyyy", language: PCStrings.currentLanguage, fixedEnglish: "d MMM yyyy").string(from: date)
    }

    /// "Jan 15, 2025 at 2:30 PM" (React `getGivenDateLabel`); "-" when absent.
    static func formatDateTime(_ iso: String?) -> String {
        guard let iso, !iso.isEmpty else { return "-" }
        guard let date = parse(iso) else { return iso }
        return formatter(template: "MMMdyyyyhmma", language: PCStrings.currentLanguage, fixedEnglish: "MMM d, yyyy 'at' h:mm a").string(from: date)
    }

    /// "Jan 15, 2025 • 2:30 PM" (product card latest activity).
    static func formatDateBulletTime(_ iso: String?) -> String {
        guard let date = parse(iso) else { return iso ?? "" }
        let day = formatter(template: "MMMdyyyy", language: PCStrings.currentLanguage, fixedEnglish: "MMM d, yyyy").string(from: date)
        return "\(day) • \(formatTime(iso))"
    }

    /// "2:30 PM".
    static func formatTime(_ iso: String?) -> String {
        guard let date = parse(iso) else { return iso ?? "" }
        return formatter(template: "hmma", language: PCStrings.currentLanguage, fixedEnglish: "h:mm a").string(from: date)
    }

    /// "Mar 24, 2:14 PM" (React `formatMessageTime`).
    static func formatMessageTime(_ iso: String?) -> String {
        guard let date = parse(iso) else { return iso ?? "" }
        let day = formatter(template: "MMMd", language: PCStrings.currentLanguage, fixedEnglish: "MMM d").string(from: date)
        return "\(day), \(formatTime(iso))"
    }

    /// Timeline group key, one per calendar day.
    static func dayKey(_ iso: String?) -> String {
        guard let date = parse(iso) else { return iso ?? "" }
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func dayBucketLabel(_ iso: String?) -> String {
        guard let date = parse(iso) else { return iso ?? "" }
        let cal = Calendar.current
        if cal.isDateInToday(date) { return PCStrings.today }
        if cal.isDateInYesterday(date) { return PCStrings.yesterday }
        return formatDate(iso)
    }

    /// dayjs `fromNow()`: "2 days ago" under the picker language.
    static func relativeTime(_ iso: String?, now: Date = Date()) -> String {
        guard let date = parse(iso) else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }

    /// React `formatTimeAgo`: the translated "Just now / 5m ago / 3h ago / 2d ago / 1w ago".
    static func timeAgo(_ iso: String?, now: Date = Date()) -> String {
        guard let date = parse(iso) else { return PCStrings.justNow }
        let minutes = Int(now.timeIntervalSince(date) / 60)
        if minutes < 1 { return PCStrings.justNow }
        if minutes < 60 { return PCStrings.minutesAgo(minutes) }
        let hours = minutes / 60
        if hours < 24 { return PCStrings.hoursAgo(hours) }
        let days = hours / 24
        if days < 7 { return PCStrings.daysAgo(days) }
        return PCStrings.weeksAgo(days / 7)
    }

    static func isPast(_ iso: String?, now: Date = Date()) -> Bool {
        guard let date = parse(iso) else { return false }
        return date < now
    }
}
