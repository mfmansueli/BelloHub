//
//  ReuseVisitSheet.swift
//  BelloHub
//

import SwiftUI

/// "Use as the base for a new visit": she ticks which parts of this visit to copy (technique, products and her own
/// fields are ticked; notes, aftercare and what to remember are not), then reviews everything in the new visit before
/// finalizing. Photos, the result, the reaction, the visit day and signed documents are never copied, and the sheet
/// says so.
struct ReuseVisitSheet: View {
    let record: TreatmentRecord
    let onStart: (Set<VisitReuse.Part>) -> Void

    @State private var parts: Set<VisitReuse.Part>
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(record: TreatmentRecord, onStart: @escaping (Set<VisitReuse.Part>) -> Void) {
        self.record = record
        self.onStart = onStart
        _parts = State(initialValue: VisitReuse.defaultParts(of: record))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text("reuseVisit.intro")
                        .font(Typography.meta)
                        .foregroundStyle(Palette.ink2)
                    let offered = VisitReuse.offeredParts(of: record)
                    if offered.isEmpty {
                        Text("reuseVisit.nothing")
                            .font(Typography.body)
                            .foregroundStyle(Palette.ink)
                    } else {
                        ListCard(dividerInset: Spacing.md) {
                            ForEach(offered, id: \.self) { part in
                                ToggleRow(title: title(of: part), subtitle: preview(of: part), isOn: binding(for: part),
                                          identifier: "reuseVisit.part.\(identifier(of: part))")
                            }
                        }
                    }
                    FooterNote(text: "reuseVisit.neverCopied", icon: .info)
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.vertical, Spacing.md)
            }
            .background(Palette.bg)
            .navigationTitle(Text("reuseVisit.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.cancel") }
                        .accessibilityIdentifier("reuseVisit.cancel")
                }
            }
            .safeAreaInset(edge: .bottom) {
                FlowBottomBar {
                    Button { onStart(parts) } label: { Text("reuseVisit.start") }
                        .buttonStyle(.belloPrimary)
                        .accessibilityIdentifier("reuseVisit.start")
                }
            }
        }
        .presentationBackground(Palette.bg)
    }

    // MARK: - Parts

    private func binding(for part: VisitReuse.Part) -> Binding<Bool> {
        Binding(
            get: { parts.contains(part) },
            set: { isOn in
                if isOn { parts.insert(part) } else { parts.remove(part) }
            }
        )
    }

    private func title(of part: VisitReuse.Part) -> String {
        switch part {
        case .technique: RecordCorrectableField.technique.title.resolved(in: locale)
        case .products: RecordCorrectableField.productsUsed.title.resolved(in: locale)
        case .aftercare: RecordCorrectableField.aftercare.title.resolved(in: locale)
        case .notes: RecordCorrectableField.notes.title.resolved(in: locale)
        case .nextVisitReminder: RecordCorrectableField.nextVisitReminder.title.resolved(in: locale)
        case .entry(let key): record.fieldEntries?.first { $0.key == key }?.name ?? key
        }
    }

    /// The first words of what would be copied, so she knows what she is ticking.
    private func preview(of part: VisitReuse.Part) -> String? {
        let text: String? = switch part {
        case .technique: record.technique
        case .products: record.productsUsed.joined(separator: ", ")
        case .aftercare: record.aftercare
        case .notes: record.notes
        case .nextVisitReminder: record.nextVisitReminder
        case .entry(let key):
            record.fieldEntries?.first { $0.key == key }?.value.replacingOccurrences(of: "\n", with: ", ")
        }
        guard let text, !text.isEmpty else { return nil }
        return text.count > 80 ? String(text.prefix(80)) + "…" : text
    }

    private func identifier(of part: VisitReuse.Part) -> String {
        switch part {
        case .technique: "technique"
        case .products: "products"
        case .aftercare: "aftercare"
        case .notes: "notes"
        case .nextVisitReminder: "nextVisitReminder"
        case .entry(let key): "field.\(key)"
        }
    }
}
