import Foundation

enum PurposeRevocability {
    static func isRevocable(_ revocable: Bool?) -> Bool {
        revocable ?? true
    }

    static func locksGrantedSelection(revocable: Bool?, isAlreadyGranted: Bool) -> Bool {
        isAlreadyGranted && !isRevocable(revocable)
    }

    static func reasonText(purposeWarning: String?, fallback: String) -> String {
        let authored = purposeWarning?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return authored.isEmpty ? fallback : authored
    }
}
