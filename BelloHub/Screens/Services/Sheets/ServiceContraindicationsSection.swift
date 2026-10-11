//
//  ServiceContraindicationsSection.swift
//  BelloHub
//

import SwiftUI

/// "Not suitable if the client has": what she chose, as chips, and a row that opens the picker. It only ever warns
/// (D16), and the line under the title says so. A token the catalog does not know (written by a newer version of the
/// app) is listed as it is, so saving never drops it.
struct ServiceContraindicationsSection: View {
    @Binding var draft: ServiceDraft
    let groups: [ContraindicationGroup]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("services.contra.title").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                .accessibilityAddTraits(.isHeader)
            Text("services.contra.hint").font(Typography.footnote).foregroundStyle(Palette.ink2)
            if !chosen.isEmpty {
                FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm, wrapsLongChildren: true) {
                    ForEach(chosen, id: \.self) { token in
                        ServiceBadge(text: Text(verbatim: ContraindicationOptions.summary(for: token, in: groups)),
                                     style: .caution)
                            .accessibilityIdentifier("serviceEditor.contraindication.\(token)")
                    }
                }
            }
            NavigationLink {
                ContraindicationPickerView(selected: $draft.contraindications, groups: groups)
            } label: {
                HStack(spacing: Spacing.row) {
                    Text(chosen.isEmpty ? "services.contra.choose" : "services.contra.change")
                        .font(Typography.bodyStrong).foregroundStyle(Palette.roseText)
                    Spacer(minLength: 0)
                    Image(icon: .forward)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.ink3)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, Spacing.md)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("serviceEditor.contraindicationsButton")
        }
    }

    private var chosen: [String] {
        ContraindicationOptions.ordered(draft.contraindications, in: groups)
    }
}
