//
//  CalendarSettingsTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("CalendarSettings")
struct CalendarSettingsTests {
    private func profile(region: String, zone: String, firstWeekday: Int? = nil) -> ProfessionalProfile {
        var profile = makeHealthProfile()
        profile.regionCode = region
        profile.timeZoneID = zone
        profile.firstWeekday = firstWeekday
        return profile
    }

    @Test("The calendar reads days in her business zone, never the phone's")
    func businessZone() {
        let settings = CalendarSettings(
            profile: profile(region: "BR", zone: "America/Sao_Paulo"), fallbackTimeZoneID: "Asia/Tokyo"
        )
        #expect(settings.timeZoneID == "America/Sao_Paulo")
        #expect(settings.formatters(locale: Locale(identifier: "pt_BR")).timeZone.identifier == "America/Sao_Paulo")
    }

    @Test("The week starts on her region's day: Sunday in Brazil, Monday in Portugal")
    func regionWeekStart() {
        #expect(CalendarSettings(profile: profile(region: "BR", zone: "America/Sao_Paulo")).firstWeekday == 1)
        #expect(CalendarSettings(profile: profile(region: "PT", zone: "Europe/Lisbon")).firstWeekday == 2)
    }

    @Test("Her own week start, chosen in Language and region, wins over her region's")
    func ownWeekStart() {
        let monday = CalendarSettings(profile: profile(region: "BR", zone: "America/Sao_Paulo", firstWeekday: 2))
        #expect(monday.firstWeekday == 2)
        let sunday = CalendarSettings(profile: profile(region: "PT", zone: "Europe/Lisbon", firstWeekday: 1))
        #expect(sunday.firstWeekday == 1)
    }

    @Test("Before her profile is read the settings are another value, so a screen built on them is built again")
    func fallbackIsAnotherValue() {
        let before = CalendarSettings(profile: nil, fallbackTimeZoneID: "Europe/Rome")
        let after = CalendarSettings(profile: profile(region: "BR", zone: "America/Sao_Paulo"))
        #expect(before != after)
        #expect(Set([before, after]).count == 2)
        #expect(CalendarSettings(profile: nil, fallbackTimeZoneID: "Europe/Rome") == before)
    }

    @Test("The week strip and its labels follow the data, Sunday-first and Monday-first", arguments: [1, 2])
    func weekLabels(firstWeekday: Int) {
        let zone = TestClock.saoPaulo
        let days = CalendarDays(timeZone: zone, firstWeekday: firstWeekday)
        let formatters = Formatters(
            locale: Locale(identifier: "en_US"), timeZone: zone, currencyCode: "BRL", firstWeekday: firstWeekday
        )
        let week = days.week(containing: TestClock.now)
        let weekdays = week.map(days.weekday(of:))
        #expect(weekdays == (0..<7).map { (firstWeekday - 1 + $0) % 7 + 1 })
        // Each label is written from its own date, so it names the day the column holds.
        #expect(formatters.weekdayDayMonth(week[0]).hasPrefix(firstWeekday == 1 ? "Sunday" : "Monday"))
        for (day, number) in zip(week, weekdays) {
            #expect(formatters.weekdayDayMonth(day).hasPrefix(formatters.weekdayName(number)))
        }
    }
}
