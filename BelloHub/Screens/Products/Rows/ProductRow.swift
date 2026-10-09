//
//  ProductRow.swift
//  BelloHub
//

import SwiftUI

/// One product in the list: its name, brand and kind, and the chip that says whether clients see it ("Shared" or
/// "Private"). Tapping the chip flips it at once; tapping the rest opens the form. Two controls in one row, so the
/// row is not one combined element; each says what it does.
struct ProductRow: View {
    let product: Product
    let onEdit: () -> Void
    let onToggleShared: (Bool) -> Void

    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                editArea
                sharedChip
            }
        } else {
            HStack(spacing: Spacing.row) {
                editArea
                sharedChip
            }
        }
    }

    // MARK: - Parts

    private var editArea: some View {
        Button(action: onEdit) {
            HStack(spacing: Spacing.row) {
                Image(icon: .box)
                    .foregroundStyle(Palette.neutralText)
                    .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                    .background(
                        Palette.neutralWash, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: product.name).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    Text(verbatim: details).font(Typography.meta).foregroundStyle(Palette.ink2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, Spacing.sm)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("products.row.hint"))
        .accessibilityIdentifier("products.row.\(product.id.uuidString)")
    }

    private var sharedChip: some View {
        let style = product.sharedWithClient ? StatusPalette.confirmed : StatusPalette.completed
        return Button { onToggleShared(!product.sharedWithClient) } label: {
            Text(product.sharedWithClient ? "products.chip.shared" : "products.chip.private")
                .font(Typography.metaStrong)
                .foregroundStyle(style.foreground)
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: Spacing.touchTarget)
                .background(style.background, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text(product.sharedWithClient ? "products.chip.hint.shared" : "products.chip.hint.private"))
        .accessibilityIdentifier("products.share.\(product.id.uuidString)")
    }

    /// "Acme · Serum", or just the kind when there is no brand.
    private var details: String {
        let category = String(localized: product.category.label.localized(in: locale))
        return ProductRules.details(brand: product.brand, category: category)
    }
}
