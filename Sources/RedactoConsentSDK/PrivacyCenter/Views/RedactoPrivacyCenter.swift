import SwiftUI

public struct RedactoPrivacyCenter: View {
    public typealias InternalPage = PrivacyCenterStore.InternalPage
    public typealias OnBackBehavior = PrivacyCenterStore.OnBackBehavior

    @StateObject private var store: PrivacyCenterStore

    public init(
        baseUrl: String,
        slug: String,
        accessToken: String,
        refreshToken: String,
        theme: PrivacyCenterThemeMode = .light,
        initialPage: InternalPage = .consentManager,
        onBack: OnBackBehavior? = nil,
        onError: @escaping @Sendable (Error) -> Bool,
        onDismiss: (() -> Void)? = nil,
        language: String? = nil,
        contact: String? = nil
    ) {
        let store = PrivacyCenterStore(
            baseUrl: baseUrl,
            slug: slug,
            accessToken: accessToken,
            refreshToken: refreshToken,
            themeMode: theme,
            initialPage: initialPage,
            onBack: onBack,
            onError: onError,
            onDismiss: onDismiss,
            language: language,
            contact: contact
        )
        _store = StateObject(wrappedValue: store)
    }

    public var body: some View {
        PrivacyCenterContent()
            .environmentObject(store)
            .environment(\.privacyCenterTheme, store.theme)
            .preferredColorScheme(store.themeMode == .dark ? .dark : .light)
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .ignoresSafeArea(.keyboard)
    }
}

struct PrivacyCenterContent: View {
    @Environment(\.privacyCenterTheme) private var theme
    @EnvironmentObject private var store: PrivacyCenterStore

    var body: some View {
        VStack(spacing: 0) {
            navbar
            ZStack {
                theme.background.ignoresSafeArea()
                // Gate on data availability so the tab bar never flashes before
                // the backend responds: a loader while checking, then either the
                // empty state or the current page.
                switch store.dataStatus {
                case .checking:
                    PCLoader()
                case .empty:
                    PCEmpty(
                        title: PCStrings.noDataTitle,
                        subtitle: PCStrings.noDataDescription,
                        icon: "tray"
                    )
                case .hasData:
                    screenForCurrentPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if store.dataStatus == .hasData && store.currentPage != .caseDetails {
                PCBottomTabBar(selectedPage: Binding(
                    get: { store.currentPage },
                    set: { store.navigate(to: $0) }
                ))
            }
            PCFooter()
        }
        .background(theme.background.ignoresSafeArea())
        .task { await store.checkDataAvailability() }
    }

    private struct NavbarConfig {
        let title: String
        let subtitle: String?
        let onBack: (() -> Void)?
    }

    private func navbarConfig() -> NavbarConfig {
        switch store.currentPage {
        case .consentManager:
            return NavbarConfig(title: PCStrings.yourPrivacyCenter, subtitle: store.contact, onBack: nil)
        case .form:
            return NavbarConfig(title: PCStrings.dataRequests, subtitle: nil, onBack: nil)
        case .activity:
            return NavbarConfig(title: PCStrings.activities, subtitle: nil, onBack: nil)
        case .receipts:
            return NavbarConfig(title: PCStrings.myReceipt, subtitle: nil, onBack: nil)
        case .caseDetails:
            return NavbarConfig(
                title: PCStrings.caseDetails,
                subtitle: store.selectedCase?.caseId,
                onBack: { store.navigate(to: .form) }
            )
        }
    }

    @ViewBuilder
    private var navbar: some View {
        let config = navbarConfig()
        PCNavbar(
            title: config.title,
            subtitle: config.subtitle,
            onBack: config.onBack,
            onClose: { store.handleBackOrSignout() }
        ) {
            HStack(spacing: 8) {
                PCLanguagePickerButton(
                    selectedCode: Binding(
                        get: { store.language },
                        set: { _ in }
                    ),
                    onSelect: { code in store.setLanguage(code) }
                )
                PCIconButton(
                    systemName: store.themeMode == .light ? "moon.fill" : "sun.max.fill"
                ) {
                    store.toggleTheme()
                }
            }
        }
    }

    @ViewBuilder
    private var screenForCurrentPage: some View {
        switch store.currentPage {
        case .consentManager:
            ConsentManagerScreen(store: store)
        case .form:
            CaseAndFormSwitcher(store: store)
        case .activity:
            ActivityListScreen(store: store)
        case .receipts:
            ReceiptListScreen(store: store)
        case .caseDetails:
            if let caseRequest = store.selectedCase {
                CaseDetailsScreen(store: store, caseRequest: caseRequest)
            } else {
                PCEmpty(title: PCStrings.error, subtitle: nil, icon: "exclamationmark.triangle")
            }
        }
    }
}

struct CaseAndFormSwitcher: View {
    enum Mode { case loading, list, form }

    @EnvironmentObject private var store: PrivacyCenterStore
    @StateObject private var vm: CaseHistoryViewModel
    @State private var mode: Mode = .loading

    init(store: PrivacyCenterStore) {
        _vm = StateObject(wrappedValue: CaseHistoryViewModel(store: store))
    }

    var body: some View {
        Group {
            switch mode {
            case .loading:
                PCLoader()
            case .list:
                CaseHistoryScreen(store: store, vm: vm, onNewRequest: { mode = .form })
            case .form:
                DSRFormScreen(store: store)
            }
        }
        .task {
            // Only run once on initial mount.
            guard mode == .loading else { return }
            await vm.loadInitial()
            mode = vm.cases.isEmpty ? .form : .list
        }
    }
}
