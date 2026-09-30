import SwiftUI

/// The activity timeline (React ActivitiesList + ActivityTimeline).
public struct ActivityListScreen: View {
    @Environment(\.privacyCenterTheme) private var theme
    @EnvironmentObject private var store: PrivacyCenterStore
    @StateObject private var vm: ActivityListViewModel

    public init(store: PrivacyCenterStore) {
        _vm = StateObject(wrappedValue: ActivityListViewModel(store: store))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                PCPageHeader(title: PCStrings.activities, description: PCStrings.activitiesSubtitle)
                content
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(theme.background)
        .task { await vm.loadInitial() }
        .refreshable { await vm.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .privacyCenterLanguageChanged)) { _ in
            Task { await vm.refresh() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading {
            VStack(spacing: 8) { ForEach(0..<6, id: \.self) { _ in PCSkeletonCard(height: 56) } }
        } else if vm.activities.isEmpty {
            PCEmpty(title: PCStrings.noActivitiesYet, subtitle: PCStrings.noActivitiesDescription, icon: "clock.arrow.circlepath")
        } else {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(vm.dayGroups) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(group.label)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(theme.text)
                                .textCase(.uppercase)
                            Text(PrivacyCenterDateFormatters.timeAgo(group.newest))
                                .font(.system(size: 12))
                                .foregroundColor(theme.textTertiary)
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(group.items) { activity in
                                TimelineRow(activity: activity, isLast: activity.id == group.items.last?.id)
                            }
                        }
                    }
                }
                footer
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        if vm.hasMore {
            ZStack {
                Color.clear.frame(height: 44)
                if vm.isLoadingMore { ProgressView().tint(theme.primary) }
            }
            .onAppear { Task { await vm.loadMore() } }
        } else {
            Text(PCStrings.allCaughtUp)
                .font(.system(size: 12))
                .foregroundColor(theme.textTertiary)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }
}

/// One timeline entry: time, a category marker on the rail, then content.
private struct TimelineRow: View {
    @Environment(\.privacyCenterTheme) private var theme
    let activity: Activity
    let isLast: Bool
    @State private var isExpanded = false

    /// React `getActivityCategory`: colour by category, not by outcome.
    private var category: (variant: PCBadgeVariant, icon: String, color: Color) {
        let type = activity.activityType.lowercased()
        if type.contains("consent") || type.contains("grant") { return (.success, "checkmark.shield", theme.success) }
        if type.contains("case") { return (.info, "doc.text", theme.info) }
        if type.contains("access") || type.contains("view") { return (.info, "eye", theme.info) }
        if type.contains("grievance") || type.contains("request") { return (.warning, "exclamationmark.bubble", theme.warning) }
        return (.secondary, "waveform.path.ecg", theme.textSecondary)
    }

    var body: some View {
        let cat = category
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(PrivacyCenterDateFormatters.formatTime(activity.timestamp))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
                Text(PrivacyCenterDateFormatters.timeAgo(activity.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(theme.textTertiary)
                    .lineLimit(1)
            }
            .frame(width: 64, alignment: .trailing)
            .padding(.top, 8)
            ZStack(alignment: .top) {
                if !isLast {
                    Rectangle().fill(theme.border).frame(width: 2).padding(.top, 30)
                }
                Circle()
                    .fill(theme.background)
                    .overlay(Circle().fill(cat.color.opacity(0.12)))
                    .frame(width: 30, height: 30)
                    .overlay(Image(systemName: cat.icon).font(.system(size: 13, weight: .semibold)).foregroundColor(cat.color))
                    .padding(.top, 8)
            }
            .frame(width: 34)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(activity.displayTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.text)
                        .lineLimit(1)
                    PCBadge(activity.displayType, variant: cat.variant)
                }
                if !activity.displayDescription.isEmpty {
                    Text(activity.displayDescription)
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(isExpanded ? nil : 2)
                        .onTapGesture { isExpanded.toggle() }
                }
            }
            .padding(.vertical, 8)
            .padding(.bottom, 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(PrivacyCenterDateFormatters.formatDateTime(activity.timestamp))
    }
}
