//
//  PolicyRuleTextTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The sentences a client reads, produced from the policy values in every localization (exit criterion of S5): the
/// app and the booking page publish the same strings, so every language is checked for a real sentence with the
/// number and the name in it and no placeholder or catalog key left over.
@Suite("PolicyRuleText")
struct PolicyRuleTextTests {
    private func text(_ localization: AppLocalization, name: String = "Maria") -> PolicyRuleText {
        PolicyRuleText(localization: localization, professionalName: name)
    }

    private func policies() -> [(CancellationPolicy, NoShowPolicy)] {
        var allowAndCount = CancellationPolicy.standard
        allowAndCount.freeWindowHours = 48
        var messageOnly = CancellationPolicy.standard
        messageOnly.afterWindowCancel = .message
        messageOnly.afterWindowReschedule = .message
        messageOnly.maxReschedules = nil
        var noReschedule = CancellationPolicy.standard
        noReschedule.clientCanReschedule = false
        noReschedule.graceMinutes = 5
        var counts = NoShowPolicy.standard
        counts.lateCancelCounts = true
        var approve = NoShowPolicy.standard
        approve.action = .approveNewBookings
        approve.limit = 1
        var pause = NoShowPolicy.standard
        pause.action = .pauseOnline
        pause.limit = 5
        var off = NoShowPolicy.standard
        off.isOn = false
        return [
            (.standard, .standard), (allowAndCount, counts), (messageOnly, approve), (noReschedule, pause),
            (.standard, off)
        ]
    }

    // MARK: - English, exactly

    @Test("The standard policy reads as the prototype's rule text, with the personal link line first")
    func standardEnglish() {
        let lines = text(.en).lines(cancellation: .standard, noShow: .standard)
        #expect(lines.count == 5)
        #expect(lines[0] == """
            After you book, you get a personal link on the confirmation page, and by email if you share one. \
            Use it any time to cancel or reschedule. No app or password.
            """)
        #expect(lines[1]
            == "Free changes up to 24 hours before. "
            + "After that you can still cancel here, and Maria is told right away.")
        #expect(lines[2] == "You can reschedule up to 2 times. To reschedule after that, send Maria a request.")
        #expect(lines[3] == "Maria holds your time for 15 minutes if you are late. Let them know from this page.")
        #expect(lines[4] == "Maria keeps track of appointments that are missed without a message.")
    }

    @Test("A late cancellation that counts says so; messaging only changes the after-window lines")
    func variantsEnglish() {
        var policy = CancellationPolicy.standard
        var noShow = NoShowPolicy.standard
        noShow.lateCancelCounts = true
        #expect(text(.en).lines(cancellation: policy,
            noShow: noShow)[1].hasSuffix("It counts as a missed appointment."))

        policy.afterWindowCancel = .message
        policy.afterWindowReschedule = .message
        policy.maxReschedules = nil
        let lines = text(.en).lines(cancellation: policy, noShow: noShow)
        #expect(lines[1] == "Free changes up to 24 hours before. After that, please message Maria.")
        #expect(lines[2] == "You can reschedule as often as you need. To reschedule after that, please message Maria.")
    }

    @Test("A client who cannot reschedule is told to message")
    func noRescheduleEnglish() {
        var policy = CancellationPolicy.standard
        policy.clientCanReschedule = false
        #expect(text(.en).lines(cancellation: policy, noShow: .standard)[2] == "To reschedule, please message Maria.")
    }

    @Test("The no-show line follows the action and the limit, with singular and plural")
    func noShowEnglish() {
        var policy = NoShowPolicy.standard
        policy.action = .approveNewBookings
        policy.limit = 1
        #expect(text(.en).noShowLine(policy)
            == "After 1 missed appointment without a message, Maria confirms your new bookings personally.")
        policy.limit = 3
        #expect(text(.en).noShowLine(policy)
            == "After 3 missed appointments without a message, Maria confirms your new bookings personally.")
        policy.action = .pauseOnline
        #expect(text(.en).noShowLine(policy)
            == "After 3 missed appointments without a message, online booking pauses and Maria contacts you.")
    }

    @Test("With protection off there is no no-show line")
    func noShowOff() {
        var policy = NoShowPolicy.standard
        policy.isOn = false
        #expect(text(.en).noShowLine(policy) == nil)
        #expect(text(.en).lines(cancellation: .standard, noShow: policy).count == 4)
    }

    @Test("The free window singular and plural")
    func freeWindowPlural() {
        // The window options are never 1, but the catalog must still carry both forms for the languages that need them.
        var policy = CancellationPolicy.standard
        policy.freeWindowHours = 1
        #expect(text(.en).lines(cancellation: policy,
            noShow: .standard)[1].hasPrefix("Free changes up to 1 hour before."))
    }

    // MARK: - Every localization

    @Test("Every localization produces whole sentences with the number and the name, and no placeholder left",
          arguments: AppLocalization.allCases)
    func everyLocalization(localization: AppLocalization) {
        for (cancellation, noShow) in policies() {
            let lines = text(localization).lines(cancellation: cancellation, noShow: noShow)
            #expect(lines.count == (noShow.isOn ? 5 : 4), "\(localization.rawValue)")
            for line in lines {
                #expect(!line.isEmpty)
                #expect(!line.contains("{") && !line.contains("}"), "\(localization.rawValue): \(line)")
                #expect(!line.contains("policy.rule"), "\(localization.rawValue) leaked a key: \(line)")
                #expect(!line.contains("%"), "\(localization.rawValue) leaked a format: \(line)")
            }
            #expect(lines.contains { $0.contains("Maria") }, "\(localization.rawValue) names her")
        }
    }

    @Test("The free window number is in the sentence in every localization", arguments: AppLocalization.allCases)
    func freeWindowNumber(localization: AppLocalization) {
        var policy = CancellationPolicy.standard
        policy.freeWindowHours = 24
        let line = text(localization).lines(cancellation: policy, noShow: .standard)[1]
        #expect(line.contains("24"), "\(localization.rawValue): \(line)")
        policy.freeWindowHours = 72
        #expect(text(localization).lines(cancellation: policy, noShow: .standard)[1].contains("72"))
    }

    @Test("The grace minutes and the limit are in the sentences in every localization",
          arguments: AppLocalization.allCases)
    func otherNumbers(localization: AppLocalization) {
        var policy = CancellationPolicy.standard
        policy.graceMinutes = 20
        var noShow = NoShowPolicy.standard
        noShow.action = .pauseOnline
        noShow.limit = 4
        let lines = text(localization).lines(cancellation: policy, noShow: noShow)
        #expect(lines[3].contains("20"), "\(localization.rawValue) grace: \(lines[3])")
        #expect(lines[4].contains("4"), "\(localization.rawValue) limit: \(lines[4])")
    }

    @Test("Every language but English says it in its own words", arguments: AppLocalization.allCases)
    func translated(localization: AppLocalization) {
        guard ![.en, .enGB].contains(localization) else { return }
        let english = text(.en).lines(cancellation: .standard, noShow: .standard)
        let other = text(localization).lines(cancellation: .standard, noShow: .standard)
        for (one, two) in zip(english, other) {
            #expect(one != two, "\(localization.rawValue) left a line in English: \(two)")
        }
    }

    @Test("The derived localizations follow their parents: es-419 reads as es-MX, en-GB as en")
    func derived() {
        let policy = CancellationPolicy.standard
        #expect(text(.es419).lines(cancellation: policy, noShow: .standard)
            == text(.esMX).lines(cancellation: policy, noShow: .standard))
        #expect(text(.enGB).lines(cancellation: policy, noShow: .standard)
            == text(.en).lines(cancellation: policy, noShow: .standard))
    }

    @Test("Different rules give different sentences in every localization", arguments: AppLocalization.allCases)
    func rulesChangeTheText(localization: AppLocalization) {
        let base = text(localization).lines(cancellation: .standard, noShow: .standard)
        var message = CancellationPolicy.standard
        message.afterWindowCancel = .message
        #expect(text(localization).lines(cancellation: message, noShow: .standard)[1] != base[1])
        var noReschedule = CancellationPolicy.standard
        noReschedule.clientCanReschedule = false
        #expect(text(localization).lines(cancellation: noReschedule, noShow: .standard)[2] != base[2])
        var approve = NoShowPolicy.standard
        approve.action = .approveNewBookings
        #expect(text(localization).lines(cancellation: .standard, noShow: approve)[4] != base[4])
    }

    @Test("Plural forms differ where the language has them: Portuguese, French, Arabic and Hindi")
    func pluralForms() {
        func line(_ localization: AppLocalization, limit: Int) -> String {
            var policy = NoShowPolicy.standard
            policy.action = .approveNewBookings
            policy.limit = limit
            return text(localization).noShowLine(policy) ?? ""
        }
        #expect(line(.ptBR, limit: 1).contains("falta") && !line(.ptBR, limit: 1).contains("faltas"))
        #expect(line(.ptBR, limit: 3).contains("faltas"))
        #expect(line(.fr, limit: 1) != line(.fr, limit: 3))
        // Arabic has six plural forms: one, two and few are not spelled alike.
        #expect(Set([1, 2, 3, 11].map { line(.ar, limit: $0) }).count >= 3)
    }

    // MARK: - Names

    @Test("In Arabic the name is isolated so it cannot reorder the sentence; elsewhere nothing invisible is added")
    func bidi() {
        let arabic = text(.ar, name: "Maria").lines(cancellation: .standard, noShow: .standard).joined(separator: " ")
        #expect(arabic.contains("\u{2068}Maria\u{2069}"))
        let english = text(.en, name: "Maria").lines(cancellation: .standard, noShow: .standard).joined(separator: " ")
        #expect(!english.contains("\u{2068}"))
    }

    @Test("A name with braces or a percent sign is put in as written")
    func oddNames() {
        let lines = text(.en, name: "Ana {x} 100%").lines(cancellation: .standard, noShow: .standard)
        #expect(lines[1].contains("Ana {x} 100% is told right away"))
    }

    // MARK: - The paused page

    @Test("A paused page says so, with the return date in the business zone")
    func paused() {
        let returnDay = TestClock.date("2026-10-22 00:00")
        let lines = text(.en).pausedNotice(until: returnDay, timeZone: TestClock.saoPaulo)
        #expect(lines == [
            "Maria is not accepting new bookings right now.",
            "Back on Thursday, October 22. Send a message and you will get a reply."
        ])
    }

    @Test("Without a return date the notice does not invent one")
    func pausedNoDate() {
        let lines = text(.en).pausedNotice(until: nil, timeZone: TestClock.saoPaulo)
        #expect(lines == [
            "Maria is not accepting new bookings right now.",
            "Send a message and you will get a reply as soon as possible."
        ])
    }

    @Test("The paused notice is a whole sentence in every localization", arguments: AppLocalization.allCases)
    func pausedEveryLocalization(localization: AppLocalization) {
        let returnDay = TestClock.date("2026-10-22 00:00")
        for until in [returnDay, nil] {
            let lines = text(localization).pausedNotice(until: until, timeZone: TestClock.saoPaulo)
            #expect(lines.count == 2)
            for line in lines {
                #expect(!line.contains("{") && !line.contains("policy.rule"), "\(localization.rawValue): \(line)")
            }
            #expect(lines[0].contains("Maria"))
        }
        let dated = text(localization).pausedNotice(until: returnDay, timeZone: TestClock.saoPaulo)[1]
        #expect(dated.contains("22"), "\(localization.rawValue): \(dated)")
    }
}
