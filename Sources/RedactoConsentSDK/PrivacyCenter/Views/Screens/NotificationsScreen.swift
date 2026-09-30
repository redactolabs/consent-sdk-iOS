import SwiftUI

/// The notification hub page (React NotificationsPage.tsx).
struct NotificationsScreen: View {
    @Environment(\.privacyCenterTheme) private var theme
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var store: PrivacyCenterStore
    @ObservedObject var vm: NotificationsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PCPageHeader(title: PCStrings.notificationHub, description: PCStrings.notificationHubSubtitle)
                Button(action: { store.navigate(to: .consentManager) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                        Text(PCStrings.backToManageConsent).font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(theme.textSecondary)
                }
                .buttonStyle(.plain)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    stat(vm.summary.total, PCStrings.total)
                    stat(vm.summary.unread, PCStrings.unread)
                    stat(vm.summary.actionNeeded, PCStrings.actionNeeded)
                    stat(vm.summary.acknowledged, PCStrings.acknowledged)
                }

                panel
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(theme.background)
        .refreshable { await vm.refreshPage() }
        .task {
            await vm.load(includeSummary: true)
            vm.startPagePolling()
        }
        .onDisappear {
            vm.stopPolling()
            vm.startBellPolling()
        }
        .onReceive(NotificationCenter.default.publisher(for: .privacyCenterLanguageChanged)) { _ in
            Task { await vm.load(includeSummary: true) }
        }
    }

    private func stat(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(theme.text)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(theme.panelFill)
        .overlay(RoundedRectangle(cornerRadius: theme.panelRadius).stroke(theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: theme.panelRadius))
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(PCStrings.notifications) (\(vm.totalCount))")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.text)
                Spacer()
                NotificationRefreshButton(isRefreshing: vm.isRefreshing) { Task { await vm.refreshPage() } }
                Button(PCStrings.markAllAsRead) { Task { await vm.markAllRead() } }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.primary)
            }
            PCSegmentedTabs(
                options: NotificationsViewModel.FilterTab.allCases.map { ($0, $0.label) },
                selection: vm.activeTab,
                onSelect: { vm.setTab($0) }
            )
            if vm.isLoading && !vm.isRefreshing {
                Text(PCStrings.loadingNotifications)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if vm.notifications.isEmpty {
                Text(PCStrings.noNotificationsInCategory)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(vm.notifications) { notification in
                        NotificationRowView(notification: notification, large: true, onTap: {
                            Task { await vm.open(notification, fromPage: true) }
                        }, onCTA: { cta in
                            Task { await runCTA(cta, notification) }
                        })
                        Divider()
                    }
                }
            }
            if vm.totalCount > NotificationsViewModel.pageSize {
                HStack {
                    PCButton(PCStrings.previous, variant: .outline, size: .compact, isDisabled: vm.skip == 0) {
                        vm.setSkip(vm.skip - NotificationsViewModel.pageSize)
                    }
                    Spacer()
                    Text(PCStrings.paginationRange(vm.skip + 1, end: min(vm.skip + NotificationsViewModel.pageSize, vm.totalCount), total: vm.totalCount))
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                    Spacer()
                    PCButton(PCStrings.next, variant: .outline, size: .compact, isDisabled: !vm.hasMore) {
                        vm.setSkip(vm.skip + NotificationsViewModel.pageSize)
                    }
                }
            }
        }
        .padding(14)
        .background(theme.panelFill)
        .overlay(RoundedRectangle(cornerRadius: theme.panelRadius).stroke(theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: theme.panelRadius))
    }

    private func runCTA(_ cta: PrivacyNotificationCTA, _ notification: PrivacyNotification) async {
        let result = await vm.performCTA(cta, on: notification, fromPage: true)
        if case .opened(let url) = result { openURL(url) }
    }
}

/// The bell's recent notifications (React NotificationDropdown), as a sheet.
struct NotificationDropdown: View {
    @Environment(\.privacyCenterTheme) private var theme
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vm: NotificationsViewModel
    let onViewAll: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(PCStrings.notifications)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.text)
                Spacer()
                NotificationRefreshButton(isRefreshing: vm.isRefreshing) { Task { await vm.refreshRecent() } }
                Button(PCStrings.markAllAsRead) { Task { await vm.markAllRead() } }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.primary)
            }
            .padding(16)
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    if vm.recent.isEmpty {
                        Text(PCStrings.noNotificationsYet)
                            .font(.system(size: 13))
                            .foregroundColor(theme.textSecondary)
                            .padding(.vertical, 32)
                    } else {
                        ForEach(vm.recent) { notification in
                            NotificationRowView(notification: notification, large: false, onTap: {
                                Task { await vm.open(notification, fromPage: false) }
                            }, onCTA: { cta in
                                Task {
                                    let result = await vm.performCTA(cta, on: notification, fromPage: false)
                                    switch result {
                                    case .opened(let url): openURL(url)
                                    case .navigated: dismiss()
                                    default: break
                                    }
                                }
                            })
                            Divider()
                        }
                    }
                }
            }
            Divider()
            Button(action: onViewAll) {
                Text("\(PCStrings.viewAllNotifications) →")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(14)
            }
            .buttonStyle(.plain)
        }
        .background(theme.background)
    }
}

struct NotificationRefreshButton: View {
    @Environment(\.privacyCenterTheme) private var theme
    let isRefreshing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textSecondary)
                .rotationEffect(.degrees(isRefreshing ? 180 : 0))
                .animation(isRefreshing ? .linear(duration: 0.6).repeatForever(autoreverses: false) : .default, value: isRefreshing)
        }
        .buttonStyle(.plain)
        .disabled(isRefreshing)
        .accessibilityLabel(PCStrings.refreshNotifications)
    }
}

struct NotificationRowView: View {
    @Environment(\.privacyCenterTheme) private var theme
    let notification: PrivacyNotification
    let large: Bool
    let onTap: () -> Void
    let onCTA: (PrivacyNotificationCTA) -> Void

    var body: some View {
        let category = PrivacyNotificationIconCategory(notificationType: notification.notificationType)
        let color = Color(hex: category.hex)
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(color.opacity(0.08))
                    .frame(width: large ? 40 : 34, height: large ? 40 : 34)
                    .overlay(Image(systemName: category.systemImage).font(.system(size: large ? 16 : 14)).foregroundColor(color))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(notification.title)
                            .font(.system(size: 14, weight: notification.isRead ? .medium : .semibold))
                            .foregroundColor(theme.text)
                            .multilineTextAlignment(.leading)
                        if !notification.isRead {
                            Circle().fill(theme.primary).frame(width: 7, height: 7)
                        }
                        Spacer(minLength: 0)
                        if large {
                            Text(PrivacyCenterDateFormatters.timeAgo(notification.createdAt))
                                .font(.system(size: 11))
                                .foregroundColor(theme.textTertiary)
                        }
                    }
                    if let status = notification.displayStatusLabel {
                        PCBadge(status, variant: .secondary)
                    }
                    if !notification.description.isEmpty {
                        Text(notification.description)
                            .font(.system(size: 13))
                            .foregroundColor(theme.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                    if !large {
                        Text(PrivacyCenterDateFormatters.timeAgo(notification.createdAt))
                            .font(.system(size: 11))
                            .foregroundColor(theme.textTertiary)
                    }
                    let ctas = notification.ctas.filter(NotificationsViewModel.isActionable)
                    if !ctas.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(ctas, id: \.self) { cta in
                                PCButton(
                                    cta.label,
                                    variant: cta.style == .primary ? .primary : (cta.style == .danger ? .destructive : .outline),
                                    size: .compact,
                                    fullWidth: false
                                ) { onCTA(cta) }
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }
            .padding(.horizontal, large ? 0 : 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(notification.isRead ? Color.clear : theme.primary.opacity(0.03))
        }
        .buttonStyle(.plain)
    }
}
