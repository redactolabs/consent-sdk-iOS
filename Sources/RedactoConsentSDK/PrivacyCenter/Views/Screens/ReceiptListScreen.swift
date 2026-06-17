import SwiftUI

public struct ReceiptListScreen: View {
    @Environment(\.privacyCenterTheme) private var theme
    @EnvironmentObject private var store: PrivacyCenterStore
    @StateObject private var vm: ReceiptListViewModel

    @State private var shareURL: URL?
    @State private var showShareSheet = false

    public init(store: PrivacyCenterStore) {
        _vm = StateObject(wrappedValue: ReceiptListViewModel(store: store))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                filterBar
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
        .sheet(isPresented: $showShareSheet) {
            if let shareURL {
                ShareSheet(items: [shareURL])
            }
        }
    }

    // MARK: - Header
    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(PCStrings.myReceipt)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(theme.text)
            Text(PCStrings.myReceiptSubtitle)
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
        }
    }

    // MARK: - Filter bar
    private var eventOptions: [PCSelectOption<ReceiptEventFilter>] {
        [
            PCSelectOption(value: .granted, label: PCStrings.consentGranted),
            PCSelectOption(value: .withdrawn, label: PCStrings.consentRevoked),
            PCSelectOption(value: .declined, label: PCStrings.consentDeclined),
            PCSelectOption(value: .expired, label: PCStrings.consentExpired),
        ]
    }

    private var dateOptions: [PCSelectOption<ReceiptDateFilter>] {
        [
            PCSelectOption(value: .today, label: PCStrings.today),
            PCSelectOption(value: .last7Days, label: PCStrings.last7Days),
            PCSelectOption(value: .last30Days, label: PCStrings.last30Days),
            PCSelectOption(value: .last3Months, label: PCStrings.last3Months),
            PCSelectOption(value: .custom, label: PCStrings.customRange),
        ]
    }

    @ViewBuilder
    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                    Text(PCStrings.filter)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.text)
                }
                Spacer()
                if vm.hasActiveFilters {
                    Button(action: { vm.clearFilters() }) {
                        Text(PCStrings.clearFilters)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            PCSelect(
                selection: $vm.eventType,
                options: eventOptions,
                placeholder: PCStrings.all,
                label: PCStrings.event
            )
            PCSelect(
                selection: $vm.datePreset,
                options: dateOptions,
                placeholder: PCStrings.allTime,
                label: PCStrings.dateRange
            )

            if vm.datePreset == .custom {
                customRange
            }
        }
        .padding(12)
        .background(theme.surface)
        .cornerRadius(10)
    }

    @ViewBuilder
    private var customRange: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(PCStrings.from)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { vm.customFrom ?? Date() },
                            set: { vm.customFrom = $0; Task { await vm.applyCustomRange() } }
                        ),
                        displayedComponents: [.date]
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(PCStrings.to)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { vm.customTo ?? Date() },
                            set: { vm.customTo = $0; Task { await vm.applyCustomRange() } }
                        ),
                        displayedComponents: [.date]
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                }
                Spacer()
            }
            if vm.isCustomRangeInvalid {
                Text(PCStrings.someThingWentWrong)
                    .font(.system(size: 11))
                    .foregroundColor(theme.error)
            }
        }
    }

    // MARK: - Content
    @ViewBuilder
    private var content: some View {
        if vm.isLoading {
            VStack(spacing: 8) { ForEach(0..<5, id: \.self) { _ in PCSkeletonCard(height: 84) } }
        } else if let errorMessage = vm.errorMessage {
            PCEmpty(title: errorMessage, icon: "exclamationmark.triangle")
        } else if vm.receipts.isEmpty {
            PCEmpty(title: PCStrings.noData, icon: "doc.text.magnifyingglass")
        } else {
            VStack(spacing: 8) {
                ForEach(vm.receipts) { receipt in
                    receiptRow(receipt)
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

    // MARK: - Row
    @ViewBuilder
    private func receiptRow(_ receipt: Receipt) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                PCAvatar(initial: productInitials(receipt), size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(productName(receipt))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.text)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(PrivacyCenterDateFormatters.formatDate(receipt.createdAt))
                        Text("•")
                        Text(PrivacyCenterDateFormatters.formatTime(receipt.createdAt))
                    }
                    .font(.system(size: 11))
                    .foregroundColor(theme.textTertiary)
                }
                Spacer()
                eventBadge(receipt)
            }
            HStack {
                Spacer()
                downloadButton(receipt)
            }
        }
        .padding(12)
        .background(theme.surface)
        .cornerRadius(10)
    }

    @ViewBuilder
    private func eventBadge(_ receipt: Receipt) -> some View {
        let raw = receipt.eventType.uppercased()
        let label = receipt.eventTypeDisplay ?? eventFallbackLabel(raw)
        PCBadge(label, variant: eventVariant(raw))
    }

    @ViewBuilder
    private func downloadButton(_ receipt: Receipt) -> some View {
        let isDownloading = vm.downloadingUuid == receipt.uuid
        PCButton(
            PCStrings.download,
            variant: .outline,
            isLoading: isDownloading,
            isDisabled: vm.downloadingUuid != nil,
            leadingIcon: "arrow.down.circle"
        ) {
            Task {
                if let url = await vm.downloadReceipt(receipt) {
                    shareURL = url
                    showShareSheet = true
                }
            }
        }
    }

    // MARK: - Helpers
    private func productName(_ receipt: Receipt) -> String {
        receipt.productNameDisplay ?? receipt.productName ?? "—"
    }

    private func productInitials(_ receipt: Receipt) -> String {
        let name = productName(receipt)
        let cleaned = name.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        let str = String(String.UnicodeScalarView(cleaned))
        let prefix = String(str.prefix(2))
        return prefix.isEmpty ? "?" : prefix
    }

    private func eventFallbackLabel(_ raw: String) -> String {
        switch raw {
        case "GRANTED": return PCStrings.consentGranted
        case "WITHDRAWN": return PCStrings.consentRevoked
        case "DECLINED": return PCStrings.consentDeclined
        case "EXPIRED": return PCStrings.consentExpired
        default: return raw.isEmpty ? "—" : PCFormatting.humanize(raw)
        }
    }

    private func eventVariant(_ raw: String) -> PCBadgeVariant {
        switch raw {
        case "GRANTED": return .success
        case "WITHDRAWN", "EXPIRED": return .warning
        case "DECLINED": return .error
        default: return .info
        }
    }
}
