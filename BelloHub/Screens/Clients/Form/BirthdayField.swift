//
//  BirthdayField.swift
//  BelloHub
//

import SwiftUI

/// "Birthday": a day, a month and an optional year, each a native menu. Nothing to type, so nothing invalid can be
/// entered one piece at a time; only a half-picked date ("day, no month") is a problem, and it is said under the field.
/// A client who does not share her year still has a birthday, so the year can stay empty.
struct BirthdayField: View {
    @Binding var birthday: BirthdayInput
    let problem: BirthdayInput.Problem?
    let currentYear: Int
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("clientForm.birthday")
                    .font(Typography.metaStrong)
                    .foregroundStyle(Palette.ink2)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Spacing.sm)
                if !birthday.isEmpty {
                    Button { birthday = BirthdayInput() } label: { Text("clientForm.birthday.clear") }
                        .font(Typography.metaStrong)
                        .foregroundStyle(Palette.roseText)
                        .frame(minHeight: Spacing.touchTarget)
                        .accessibilityIdentifier("clientEdit.birthdayClearButton")
                }
            }
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.sm))
                : AnyLayout(HStackLayout(spacing: Spacing.sm))
            layout {
                menu(placeholder: "clientForm.birthday.day", selection: $birthday.day, options: Array(1...31)) {
                    Text(verbatim: $0.formatted(.number.locale(locale)))
                }
                .accessibilityIdentifier("clientEdit.birthdayDay")
                menu(placeholder: "clientForm.birthday.month", selection: $birthday.month, options: Array(1...12)) {
                    Text(verbatim: monthName($0))
                }
                .accessibilityIdentifier("clientEdit.birthdayMonth")
                menu(
                    placeholder: "clientForm.birthday.year", selection: $birthday.year,
                    options: BirthdayInput.yearOptions(currentYear: currentYear)
                ) {
                    Text(verbatim: String($0))
                }
                .accessibilityIdentifier("clientEdit.birthdayYear")
            }
            if let problem {
                Text(message(for: problem))
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.coralText)
                    .accessibilityAddTraits(.updatesFrequently)
                    .accessibilityIdentifier("clientEdit.birthdayError")
            }
        }
    }

    /// One menu in the look of a field. Choosing "none" empties just that piece.
    private func menu(
        placeholder: LocalizedStringKey, selection: Binding<Int?>, options: [Int],
        label: @escaping (Int) -> Text
    ) -> some View {
        Menu {
            Picker(selection: selection) {
                Text(placeholder).tag(Int?.none)
                ForEach(options, id: \.self) { option in label(option).tag(Int?.some(option)) }
            } label: { Text(placeholder) }
        } label: {
            HStack {
                if let value = selection.wrappedValue { label(value) } else { Text(placeholder) }
                Spacer(minLength: Spacing.xs)
                Image(icon: .chevronUpDown)
                    .font(.system(size: 12, weight: .semibold))
                    .accessibilityHidden(true)
            }
            .font(Typography.body)
            .foregroundStyle(selection.wrappedValue == nil ? Palette.ink2 : Palette.ink)
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Palette.sunken, in: shape)
            .overlay { shape.strokeBorder(problem == nil ? Palette.fieldBorder : Palette.coralText, lineWidth: 1.5) }
        }
        .accessibilityLabel(placeholder)
        .accessibilityValue(selection.wrappedValue.map { label($0) } ?? Text(placeholder))
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
    }

    private func monthName(_ month: Int) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        return calendar.standaloneMonthSymbols[month - 1]
    }

    private func message(for problem: BirthdayInput.Problem) -> LocalizedStringKey {
        switch problem {
        case .incomplete: "clientForm.birthday.incomplete"
        case .invalidDate: "clientForm.birthday.invalidDate"
        case .invalidYear: "clientForm.birthday.invalidYear"
        }
    }
}
