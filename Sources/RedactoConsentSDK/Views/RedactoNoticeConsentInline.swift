import SwiftUI

/// Inline consent view for embedding within a parent container.
/// Does not present as a modal — renders directly in the view hierarchy.
/// Auto-submits consent when all required elements are checked and a token is provided.
///
/// Port of the React `RedactoNoticeConsentInline` component: the purposes only,
/// painted with the console appearance under the host's `settings`.
public struct RedactoNoticeConsentInline: View {
    @StateObject private var viewModel: ConsentInlineViewModel
    private let accessToken: String?
    private let identity: InlineNoticeIdentity

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        orgUuid: String,
        workspaceUuid: String,
        noticeUuid: String,
        accessToken: String? = nil,
        baseUrl: String,
        ledgerBaseUrl: String? = nil,
        settings: ConsentSettings? = nil,
        language: String = "en",
        onAccept: (() -> Void)? = nil,
        onDecline: (() -> Void)? = nil,
        onError: ((Error) -> Void)? = nil,
        onValidationChange: ((Bool) -> Void)? = nil,
        applicationId: String? = nil
    ) {
        self.accessToken = accessToken
        self.identity = InlineNoticeIdentity(
            orgUuid: orgUuid,
            workspaceUuid: workspaceUuid,
            noticeUuid: noticeUuid,
            language: language,
            applicationId: applicationId
        )
        _viewModel = StateObject(wrappedValue: ConsentInlineViewModel(
            orgUuid: orgUuid,
            workspaceUuid: workspaceUuid,
            noticeUuid: noticeUuid,
            accessToken: accessToken,
            baseUrl: baseUrl,
            ledgerBaseUrl: ledgerBaseUrl,
            language: language,
            onAccept: onAccept,
            onDecline: onDecline,
            onError: onError,
            onValidationChange: onValidationChange,
            settings: settings,
            applicationId: applicationId
        ))
    }

    public var body: some View {
        let appearance = viewModel.appearance(colorScheme: colorScheme)
        Group {
            if viewModel.hasAlreadyConsented || viewModel.fetchError != nil {
                EmptyView()
            } else if viewModel.isLoading {
                loading(appearance)
            } else if let config = viewModel.activeConfig {
                inlineContent(config, appearance)
            } else {
                EmptyView()
            }
        }
        .environment(\.noticeFontFamily, viewModel.noticeFontFamily)
        .onAppear {
            viewModel.fetchNoticeIfNeeded()
        }
        .onChange(of: accessToken) { token in
            viewModel.updateAccessToken(token)
        }
        .onChange(of: identity) { identity in
            viewModel.updateIdentity(identity)
        }
    }

    private var isMobile: Bool {
        horizontalSizeClass == .compact
    }

    private func headingColor(_ appearance: ResolvedNoticeAppearance) -> Color {
        appearance.color(.heading) ?? Color(hex: "#101828")
    }

    private func textColor(_ appearance: ResolvedNoticeAppearance) -> Color {
        appearance.color(.text) ?? Color(hex: "#344054")
    }

    private func loading(_ appearance: ResolvedNoticeAppearance) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#3498db")))
                .scaleEffect(1.5)
            Text("Loading...")
                .noticeFont(size: appearance.scaled(16))
                .foregroundColor(textColor(appearance))
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding(32)
    }

    // MARK: - Inline Content

    private func inlineContent(_ config: ActiveConfig, _ appearance: ResolvedNoticeAppearance) -> some View {
        let painted = appearance.color(.background)
        return VStack(alignment: .leading, spacing: 16) {
            if let errorMessage = viewModel.errorMessage {
                InlineErrorBanner(message: errorMessage)
            }

            if ProductMatrix.isMultiProduct(config.products) {
                ForEach(InlineSelection.productGroups(config), id: \.product.uuid) { group in
                    // React stacks a group's purposes flush under the heading.
                    VStack(alignment: .leading, spacing: 0) {
                        productHeading(group.product, appearance)
                        ForEach(group.purposes, id: \.uuid) { purpose in
                            purposeRow(purpose, productUuid: group.product.uuid, appearance)
                        }
                    }
                }
            } else {
                ForEach(viewModel.purposeRows, id: \.purpose.uuid) { row in
                    purposeRow(row.purpose, productUuid: nil, appearance)
                }
            }
        }
        .padding(painted == nil ? 0 : 16)
        .background(
            RoundedRectangle(cornerRadius: appearance.modalRadius)
                .fill(painted ?? Color.clear)
        )
    }

    private func productHeading(_ product: NoticeProduct, _ appearance: ResolvedNoticeAppearance) -> some View {
        let name = Text(viewModel.getTranslatedText("products.name", defaultText: product.name, itemId: product.uuid))
        return (product.mandatory == true ? name + Text(" *").foregroundColor(.red) : name)
            .noticeFont(size: appearance.scaled(16), weight: .medium)
            .foregroundColor(headingColor(appearance))
            .padding(.bottom, 8)
    }

    private func purposeRow(_ purpose: ActiveConfigPurpose, productUuid: String?, _ appearance: ResolvedNoticeAppearance) -> some View {
        let key = ProductMatrix.productPurposeKey(productUuid, purpose.uuid)
        return PairPurposeRowView(
            purpose: purpose,
            dataElements: purpose.dataElements,
            isCollapsed: viewModel.collapsedPurposes[key] ?? true,
            isSelected: viewModel.selectedPurposes[key] ?? false,
            isElementSelected: { viewModel.selectedDataElements[InlineSelection.inlineElementKey(productUuid, purpose.uuid, $0)] ?? false },
            translate: { viewModel.getTranslatedText($0, defaultText: $1, itemId: $2) },
            headingColor: headingColor(appearance),
            textColor: textColor(appearance),
            accentColor: InlineAppearance.accent(appearance),
            onToggleCollapse: { viewModel.handlePurposeCollapse(purpose.uuid, productUuid: productUuid) },
            onTogglePurpose: { viewModel.handlePurposeToggle(purpose.uuid, productUuid: productUuid) },
            onToggleElement: { viewModel.handleDataElementToggle($0, purposeUuid: purpose.uuid, productUuid: productUuid) },
            style: InlineAppearance.rowStyle(appearance, isMobile: isMobile),
            motion: NoticeMotion.isEnabled(appearance.layout, reduceMotion: reduceMotion)
        )
    }
}

/// How the inline notice paints its rows, from the resolved appearance
/// (React inline tsx ~105-142, ~626-670).
enum InlineAppearance {
    /// `toggle_on`, then `accept_all_bg`; the notice's `primary_color` is not
    /// the inline accent in React, so it is not read here.
    static func accent(_ appearance: ResolvedNoticeAppearance) -> String {
        appearance.colors[.toggleOn] ?? appearance.colors[.acceptAllBg] ?? NoticeAppearanceDefaults.accentColor
    }

    static func rowStyle(_ appearance: ResolvedNoticeAppearance, isMobile: Bool) -> PairRowStyle {
        var style = PairRowStyle()
        style.titleSize = appearance.scaled(isMobile ? 14 : 16)
        style.descriptionSize = appearance.scaled(isMobile ? 11 : 12)
        style.elementSize = appearance.scaled(isMobile ? 12 : 14)
        style.descriptionColor = appearance.color(.mutedText)
        style.chevronColor = appearance.color(.heading) ?? Color(hex: "#323B4B")
        style.selectionControl = appearance.effectiveSelectionControl
        style.switchControl = appearance.layout.switchControl
        style.purposeBoxSize = 17
        style.elementBoxSize = 16
        style.controlOffColor = appearance.color(.toggleOff) ?? Color(hex: "#d0d5dd")
        style.knobColor = appearance.color(.toggleKnob) ?? .white
        style.collapseLabel = { collapsed, name in "\(collapsed ? "Expand" : "Collapse") \(name) details" }
        return style
    }
}

/// The submit failure React's inline notice shows above the purposes.
private struct InlineErrorBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .noticeFont(size: 14)
            .foregroundColor(Color(hex: "#DC2626"))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(hex: "#FEE2E2"))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#FCA5A5"), lineWidth: 1))
            .accessibilityAddTraits(.isStaticText)
    }
}
