import SwiftUI

struct ProfilePickerScreen: View {
    @Environment(\.privacyCenterTheme) private var theme
    @ObservedObject var store: PrivacyCenterStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(PCStrings.chooseYourProfile)
                    .font(theme.font(size: 20, weight: .bold))
                    .foregroundColor(theme.text)
                Text(PCStrings.loginIdentifierLinkedToMultipleProfiles)
                    .font(theme.font(size: 13))
                    .foregroundColor(theme.textSecondary)
                ForEach(PCProfileGate.selectable(store.profileCandidates)) { candidate in
                    row(candidate)
                }
                if let error = store.profileSelectError {
                    Text(error)
                        .font(theme.font(size: 12))
                        .foregroundColor(theme.error)
                }
            }
            .padding(16)
        }
        .background(theme.background)
    }

    @ViewBuilder
    private func row(_ candidate: IdentityCandidate) -> some View {
        let labels = PCProfileGate.labels(for: candidate)
        let isBusy = store.profileBusyUuid == candidate.uuid
        Button(action: {
            Task { await store.selectProfile(candidate) }
        }) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(labels.primary)
                        .font(theme.font(size: 14, weight: .semibold))
                        .foregroundColor(theme.text)
                    ForEach(labels.secondary, id: \.self) { value in
                        Text(value)
                            .font(theme.font(size: 12))
                            .foregroundColor(theme.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                if isBusy {
                    Text(PCStrings.signingInEllipsis)
                        .font(theme.font(size: 12))
                        .foregroundColor(theme.textSecondary)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(theme.textTertiary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surfaceElevated)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(store.profileBusyUuid != nil)
    }
}
