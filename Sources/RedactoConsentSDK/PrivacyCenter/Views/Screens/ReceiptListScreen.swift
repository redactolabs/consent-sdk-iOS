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
        PCPageHeader(title: PCStrings.myReceipt, description: PCStrings.myReceiptSubtitle)
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
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(theme.font(size: 13, weight: .medium))
                        Text(PCStrings.filterReceipts)
                            .font(theme.font(size: 13, weight: .semibold))
                    }
                    .foregroundColor(theme.text)
                    Text(PCStrings.receiptFiltersHint)
                        .font(theme.font(size: 12))
                        .foregroundColor(theme.textSecondary)
                }
                Spacer()
                Button(action: { vm.clearFilters() }) {
                    Text(PCStrings.clearFilters)
                        .font(theme.font(size: 12, weight: .medium))
                        .foregroundColor(theme.primary)
                }
                .buttonStyle(.plain)
                .disabled(!vm.hasActiveFilters)
                .opacity(vm.hasActiveFilters ? 1 : 0.4)
            }

            PCSelect(
                selection: $vm.eventType,
                options: eventOptions,
                placeholder: PCStrings.all,
                label: PCStrings.event,
                allOptionLabel: PCStrings.all
            )
            PCSelect(
                selection: $vm.datePreset,
                options: dateOptions,
                placeholder: PCStrings.allTime,
                label: PCStrings.dateRange,
                allOptionLabel: PCStrings.allTime
            )

            if vm.datePreset == .custom {
                customRange
            }
            HStack(alignment: .top) {
                Text(PCStrings.totalRecords(vm.pagination.totalCount))
                    .font(theme.font(size: 12))
                    .foregroundColor(theme.textSecondary)
                Spacer()
            }
            let chips = vm.activeFilterLabels
            if !chips.isEmpty {
                FlowLayoutCompat(spacing: 6) {
                    ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                        (Text("\(chip.label): ").fontWeight(.semibold) + Text(chip.value))
                            .font(theme.font(size: 11))
                            .foregroundColor(theme.text)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.background)
                            .overlay(Capsule().stroke(theme.border, lineWidth: 1))
                            .clipShape(Capsule())
                    }
                }
                .accessibilityLabel(PCStrings.filtersApplied)
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
                        .font(theme.font(size: 12, weight: .medium))
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
                        .font(theme.font(size: 12, weight: .medium))
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
                Text(PCStrings.receiptDateRangeInvalid)
                    .font(theme.font(size: 11))
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
                PCPaginationBar(
                    currentPage: vm.currentPage,
                    totalPages: vm.totalPages,
                    pageSize: vm.pageSize,
                    pageSizeOptions: ReceiptListViewModel.pageSizeOptions,
                    onPage: { vm.goToPage($0) },
                    onPageSize: { vm.setPageSize($0) }
                )
            }
        }
    }

    // MARK: - Row
    @ViewBuilder
    private func receiptRow(_ receipt: Receipt) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(eventLabel(receipt))
                    .font(theme.font(size: 14, weight: .semibold))
                    .foregroundColor(theme.text)
                Text(productName(receipt))
                    .font(theme.font(size: 13))
                    .foregroundColor(theme.textSecondary)
                Text(PrivacyCenterDateFormatters.formatDateTimeShort(receipt.createdAt))
                    .font(theme.font(size: 13))
                    .foregroundColor(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            downloadButton(receipt)
                .fixedSize()
        }
        .padding(14)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func downloadButton(_ receipt: Receipt) -> some View {
        let isDownloading = vm.downloadingUuid == receipt.uuid
        PCButton(
            PCStrings.download,
            variant: .outline,
            isLoading: isDownloading,
            isDisabled: vm.downloadingUuid != nil
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
        receipt.productNameDisplay.pcNonEmpty ?? receipt.productName.pcNonEmpty ?? "-"
    }

    /// Android `receiptEventLabel`: our translation for the four known events, then the server's display, then the raw value.
    private func eventLabel(_ receipt: Receipt) -> String {
        switch receipt.eventType.uppercased() {
        case "GRANTED": return PCStrings.consentGranted
        case "WITHDRAWN", "WITHDRAW", "REVOKED": return PCStrings.consentRevoked
        case "DECLINED": return PCStrings.consentDeclined
        case "EXPIRED": return PCStrings.consentExpired
        default: return receipt.eventTypeDisplay.pcNonEmpty ?? (receipt.eventType.isEmpty ? PCStrings.noData : receipt.eventType)
        }
    }
}
