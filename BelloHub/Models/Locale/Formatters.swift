//
//  Formatters.swift
//  BelloHub
//

import Foundation

/// The one place dates, times, money, lists and durations are turned into text (D25, docs/07 section 2.4).
/// Always Foundation format styles with an explicit locale: never string concatenation. Dates and times
/// follow the reader's locale in the *business* time zone; money follows the business currency but is
/// written with the reader's number style. Views call this and build nothing by hand.
struct Formatters: Sendable {
    let locale: Locale
    let timeZone: TimeZone
    let currencyCode: String
    let calendar: Calendar

    init(locale: Locale, timeZone: TimeZone, currencyCode: String, firstWeekday: Int? = nil) {
        var calendar = Calendar(identifier: .gregorian) // Gregorian everywhere in v1, also for ar and hi
        calendar.locale = locale
        calendar.timeZone = timeZone
        if let firstWeekday { calendar.firstWeekday = firstWeekday }
        self.locale = locale
        self.timeZone = timeZone
        self.currencyCode = currencyCode
        self.calendar = calendar
    }

    /// "Thursday, October 1" without the year, as in message templates (`{date}`).
    func weekdayDayMonth(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone)
            .weekday(.wide).day().month(.wide))
    }

    /// "Oct 1, 2026".
    func shortDate(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone)
            .year().month(.abbreviated).day())
    }

    /// "14:30" or "2:30 PM". By default the locale's own clock; `use24Hour` forces one (the professional's
    /// override). Forced clocks use an explicit format because `.hour(.twoDigits(amPM: .omitted))` still
    /// follows the locale's 12-hour cycle. Digits and AM/PM names still come from the locale.
    func time(_ date: Date, use24Hour: Bool? = nil) -> String {
        switch use24Hour {
        case nil:
            let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone).hour().minute()
            return date.formatted(style)
        case true?:
            let format: Date.FormatString = """
            \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)
            """
            return date.formatted(Date.VerbatimFormatStyle(format: format, locale: locale, timeZone: timeZone,
                                                           calendar: calendar))
        case false?:
            let format: Date.FormatString = """
            \(hour: .defaultDigits(clock: .twelveHour, hourCycle: .oneBased)):\(minute: .twoDigits) \
            \(dayPeriod: .standard(.abbreviated))
            """
            return date.formatted(Date.VerbatimFormatStyle(format: format, locale: locale, timeZone: timeZone,
                                                           calendar: calendar))
        }
    }

    /// Date and time together, for a deadline.
    func dateTime(_ date: Date, use24Hour: Bool? = nil) -> String {
        "\(weekdayDayMonth(date)), \(time(date, use24Hour: use24Hour))"
    }

    /// "R$ 1.234,50": the business currency in the reader's number style.
    func money(_ amount: Decimal) -> String {
        amount.formatted(Decimal.FormatStyle.Currency(code: currencyCode).locale(locale))
    }

    /// "Ana, Bia and Carla", with the locale's conjunction and punctuation.
    func list(_ items: [String]) -> String {
        items.formatted(.list(type: .and, width: .standard).locale(locale))
    }

    /// "1 h 30 min" from a number of minutes, abbreviated.
    func duration(minutes: Int) -> String {
        Duration.seconds(minutes * 60).formatted(
            Duration.UnitsFormatStyle(allowedUnits: [.hours, .minutes], width: .abbreviated).locale(locale)
        )
    }

    /// "90 min": minutes only, never turned into hours, because a list of services reads better when every duration
    /// is in the same unit.
    func minutes(_ value: Int) -> String {
        Duration.seconds(value * 60).formatted(
            Duration.UnitsFormatStyle(allowedUnits: [.minutes], width: .abbreviated).locale(locale)
        )
    }

    /// "4 wk": a number of weeks, abbreviated.
    func weeks(_ value: Int) -> String {
        Duration.seconds(value * 7 * 86_400).formatted(
            Duration.UnitsFormatStyle(allowedUnits: [.weeks], width: .abbreviated).locale(locale)
        )
    }

    /// A count in the locale's digits ("٣" in Arabic regions that use Arabic-Indic digits).
    func number(_ value: Int) -> String {
        value.formatted(.number.locale(locale))
    }
}
