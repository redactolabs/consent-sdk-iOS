import SwiftUI

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
                header
                content
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(theme.background)
        .task { await vm.loadInitial() }
        .refreshable { await vm.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .privacyCenterLanguageChanged)) { _ in
            Task { await vm.refresh() }
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(PCStrings.activities)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(theme.text)
            Text(PCStrings.activitiesSubtitle)
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading {
            VStack(spacing: 8) { ForEach(0..<5, id: \.self) { _ in PCSkeletonCard(height: 72) } }
        } else if vm.activities.isEmpty {
            PCEmpty(title: PCStrings.noActivities, icon: "clock.arrow.circlepath")
        } else {
            VStack(spacing: 8) {
                ForEach(vm.activities) { activity in
                    activityRow(activity)
                }
                if vm.hasMore {
                    Button(action: { Task { await vm.loadMore() } }) {
                        Text(vm.isLoadingMore ? PCStrings.loading : PCStrings.loadMore)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(theme.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(theme.surface)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isLoadingMore)
                }
            }
        }
    }

    @ViewBuilder
    private func activityRow(_ activity: Activity) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(activityColor(activity).opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: activityIcon(activity))
                    .font(.system(size: 14))
                    .foregroundColor(activityColor(activity))
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(activity.titleDisplay ?? activity.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.text)
                    Spacer()
                    if let status = activity.statusDisplay ?? activity.status {
                        PCCaseStatusBadge(status: status)
                    }
                }
                if !activity.description.isEmpty {
                    Text(activity.descriptionDisplay ?? activity.description)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(2)
                }
                Text(PrivacyCenterDateFormatters.formatDateTime(activity.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(theme.textTertiary)
            }
        }
        .padding(12)
        .background(theme.surface)
        .cornerRadius(10)
    }

    private func activityIcon(_ a: Activity) -> String {
        let t = a.activityType.lowercased()
        if t.contains("consent_given") || t.contains("granted") { return "checkmark" }
        if t.contains("revoke") { return "xmark" }
        if t.contains("renew") { return "arrow.clockwise" }
        if t.contains("case_created") { return "doc.text" }
        if t.contains("complete") { return "checkmark.seal" }
        return "info.circle"
    }

    private func activityColor(_ a: Activity) -> Color {
        let s = (a.statusDisplay ?? a.status ?? "").lowercased()
        if s.contains("complete") { return theme.success }
        if s.contains("reject") { return theme.error }
        if s.contains("process") || s.contains("pending") { return theme.warning }
        return theme.primary
    }
}
