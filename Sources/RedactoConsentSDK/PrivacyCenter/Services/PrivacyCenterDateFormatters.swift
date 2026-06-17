import Foundation

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

    static let displayDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static let displayDateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    static let displayTime: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    static func parse(_ iso: String?) -> Date? {
        guard let iso, !iso.isEmpty else { return nil }
        return iso8601.date(from: iso) ?? iso8601NoFraction.date(from: iso)
    }

    static func formatDate(_ iso: String?) -> String {
        guard let date = parse(iso) else { return iso ?? "" }
        return displayDate.string(from: date)
    }

    static func formatDateTime(_ iso: String?) -> String {
        guard let date = parse(iso) else { return iso ?? "" }
        return displayDateTime.string(from: date)
    }

    static func formatTime(_ iso: String?) -> String {
        guard let date = parse(iso) else { return iso ?? "" }
        return displayTime.string(from: date)
    }

    static func dayBucketLabel(_ iso: String?) -> String {
        guard let date = parse(iso) else { return iso ?? "" }
        let cal = Calendar.current
        if cal.isDateInToday(date) { return PCStrings.today }
        if cal.isDateInYesterday(date) { return PCStrings.yesterday }
        return displayDate.string(from: date)
    }

    static func relativeTime(_ iso: String?) -> String {
        guard let date = parse(iso) else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
