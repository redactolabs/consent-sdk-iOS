import SwiftUI

/// Guardian verification form for minors.
/// Port of the GuardianForm component from RedactoNoticeConsent.tsx.
struct GuardianFormView: View {
    @ObservedObject var viewModel: ConsentNoticeViewModel

    private let relationshipOptions = ["Father", "Mother", "Legal Guardian", "Grandparent"]

    @Environment(\.noticeTheme) private var environmentTheme

    private var theme: NoticeTheme { environmentTheme ?? .classic }
    private var headingColor: Color { theme.heading }
    private var textColor: Color { theme.text }
    private var borderColor: Color { theme.border ?? Color(hex: "#d0d5dd") }

    var body: some View {
        VStack(spacing: 0) {
            topSection

            FittedScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Since you are under the age of consent, a legal guardian must verify their identity via DigiLocker before you can proceed.")
                        .noticeFont(size: 13)
                        .foregroundColor(textColor)
                        .lineSpacing(2)

                    // Info banner
                    infoBanner

                    // Name field
                    formField(
                        label: "Guardian's Full Name",
                        value: Binding(
                            get: { viewModel.guardianFormData.guardianName },
                            set: { viewModel.handleGuardianFormChange("guardianName", $0) }
                        ),
                        placeholder: "e.g. Rajesh Kumar",
                        error: viewModel.guardianFormErrors["guardianName"],
                        hint: "Enter the full name as per government ID (Aadhaar, PAN, etc.)"
                    )

                    // Phone field
                    formField(
                        label: "Guardian's Phone Number",
                        value: Binding(
                            get: { viewModel.guardianFormData.guardianContact },
                            set: { viewModel.handleGuardianFormChange("guardianContact", $0) }
                        ),
                        placeholder: "e.g. 9876543210",
                        error: viewModel.guardianFormErrors["guardianContact"],
                        hint: "Mobile number linked to guardian's Aadhaar",
                        keyboardType: .phonePad
                    )

                    // Relationship dropdown
                    relationshipField

                    if let generalError = viewModel.guardianFormErrors["general"] {
                        Text(generalError)
                            .noticeFont(size: 13)
                            .foregroundColor(Color(hex: "#DC2626"))
                            .padding(12)
                            .background(Color(hex: "#FEF2F2"))
                            .cornerRadius(8)
                    }
                }
            }

            bottomSection
        }
    }

    // MARK: - Info Banner

    private var infoBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(Color(hex: "#2563EB"))
                .font(.system(size: 14))
                .padding(.top, 1)

            Text("The guardian's name will be matched against their DigiLocker identity document (e.g. Aadhaar). Please enter the name exactly as it appears on the document.")
                .noticeFont(size: 12)
                .foregroundColor(Color(hex: "#1E40AF"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#EFF6FF"))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: "#BFDBFE"), lineWidth: 1)
        )
    }

    // MARK: - Relationship Dropdown

    private var relationshipField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                Text("Relationship ")
                    .noticeFont(size: 13, weight: .medium)
                    .foregroundColor(textColor)
                Text("*")
                    .noticeFont(size: 13, weight: .medium)
                    .foregroundColor(Color(hex: "#DC2626"))
            }

            Menu {
                ForEach(relationshipOptions, id: \.self) { option in
                    Button(option) {
                        viewModel.handleGuardianFormChange("guardianRelationship", option)
                    }
                }
            } label: {
                HStack {
                    Text(viewModel.guardianFormData.guardianRelationship.isEmpty
                        ? "Select relationship"
                        : viewModel.guardianFormData.guardianRelationship)
                        .noticeFont(size: 14)
                        .foregroundColor(viewModel.guardianFormData.guardianRelationship.isEmpty
                            ? Color(hex: "#9CA3AF")
                            : Color(hex: "#344054"))

                    Spacer()

                    Image(systemName: "chevron.down")
                        .foregroundColor(Color(hex: "#667085"))
                        .font(.system(size: 12))
                }
                .padding(10)
                .background(Color.white)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(viewModel.guardianFormErrors["guardianRelationship"] != nil
                            ? Color(hex: "#DC2626") : borderColor, lineWidth: 1)
                )
            }

            if let error = viewModel.guardianFormErrors["guardianRelationship"] {
                Text(error)
                    .noticeFont(size: 12)
                    .foregroundColor(Color(hex: "#DC2626"))
            }
        }
    }

    // MARK: - Top Section

    private var topSection: some View {
        HStack(spacing: 10) {
            if let logoUrl = viewModel.logoUrl {
                RemoteLogoView(
                    url: logoUrl,
                    size: theme.appearance.logoHeight(isPhone: theme.isPhone),
                    maxWidth: theme.appearance.logoMaxWidth(isPhone: theme.isPhone)
                )
            }
            Text(GuardianCopy.title)
                .noticeFont(size: 16, weight: .semibold)
                .foregroundColor(headingColor)
            Spacer(minLength: 0)
        }
        .padding(.bottom, 15)
    }

    // MARK: - Bottom Section

    @ViewBuilder
    private var bottomSection: some View {
        let verify = NoticeActionButton(
            title: viewModel.isSubmittingGuardian ? GuardianCopy.verifying : GuardianCopy.verify,
            paint: theme.acceptAll,
            theme: theme,
            disabled: viewModel.isSubmittingGuardian,
            action: { viewModel.handleGuardianFormNext() }
        )
        .accessibilityLabel(viewModel.isSubmittingGuardian ? "Verifying guardian identity" : "Proceed to guardian verification")
        let cancel = NoticeActionButton(title: GuardianCopy.cancel, paint: theme.decline, theme: theme, action: viewModel.handleDecline)
        Group {
            if theme.isPhone {
                VStack(spacing: 12) { verify; cancel }
            } else {
                HStack(spacing: 16) { verify; cancel }
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Form Field Builder

    @ViewBuilder
    private func formField(
        label: String,
        value: Binding<String>,
        placeholder: String,
        error: String?,
        hint: String? = nil,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                Text("\(label) ")
                    .noticeFont(size: 13, weight: .medium)
                    .foregroundColor(textColor)
                Text("*")
                    .noticeFont(size: 13, weight: .medium)
                    .foregroundColor(Color(hex: "#DC2626"))
            }

            TextField(placeholder, text: value)
                .noticeFont(size: 14)
                .foregroundColor(Color(hex: "#344054"))
                .padding(10)
                .background(Color.white)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(error != nil ? Color(hex: "#DC2626") : borderColor, lineWidth: 1)
                )
                .keyboardType(keyboardType)
                .autocapitalization(keyboardType == .phonePad ? .none : .words)

            if let hint {
                Text(hint)
                    .noticeFont(size: 11)
                    .foregroundColor(Color(hex: "#667085"))
            }

            if let error {
                Text(error)
                    .noticeFont(size: 12)
                    .foregroundColor(Color(hex: "#DC2626"))
            }
        }
    }
}
