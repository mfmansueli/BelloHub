// Generates firebase/functions/test/fixtures/rules.fixture.json from the REAL iOS rule types, so the TypeScript
// rules in functions/src/lib cannot drift from them (docs/11-BACKEND-FIREBASE.md section 4: "both sides read one JSON
// file generated once"). Compiled together with the iOS sources by generate.sh; it never ships in the app.
//
// Output: JSON on stdout. Usage: see generate.sh.

import Foundation

// MARK: - Helpers

func zone(_ id: String) -> TimeZone {
    guard let zone = TimeZone(identifier: id) else { fatalError("unknown zone \(id)") }
    return zone
}

/// "2026-10-08 15:00" read as local time in `zoneID`.
func local(_ text: String, _ zoneID: String) -> Date {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = zone(zoneID)
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    guard let date = formatter.date(from: text) else { fatalError("bad date \(text)") }
    return date
}

let isoFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
}()

func iso(_ date: Date) -> String { isoFormatter.string(from: date) }

func utc(_ text: String) -> Date {
    guard let date = isoFormatter.date(from: text) else { fatalError("bad instant \(text)") }
    return date
}

// MARK: - Free slots

struct SlotCase {
    var name: String
    var zoneID = "America/Sao_Paulo"
    var now: Date
    var dayLocal: String
    var minutes = 60
    var step = 30
    var weekly: [AvailabilityRule]
    var breaks: [BreakRule] = []
    var daysOff: [(String, String)] = []
    var buffer = 15
    var notice = 2
    var horizon = 60
    var appointments: [DateInterval] = []
    var blocks: [DateInterval] = []
}

func mariasWeek(
    weekdays: [Int] = [3, 4, 5, 6, 7], start: Int = 540, end: Int = 1_140
) -> [AvailabilityRule] {
    weekdays.map { AvailabilityRule(weekday: $0, startMinutes: start, endMinutes: end) }
}

let lunch = BreakRule(weekday: nil, startMinutes: 750, endMinutes: 810, label: "Lunch")
let saoPaulo = "America/Sao_Paulo"
let referenceNow = local("2026-10-01 12:00", saoPaulo)

func dayOffDate(_ text: String, _ zoneID: String) -> Date { local("\(text) 00:00", zoneID) }

func slotJSON(_ test: SlotCase) -> [String: Any] {
    let timeZone = zone(test.zoneID)
    let settings = AvailabilitySettings(
        weekly: test.weekly, breaks: test.breaks,
        daysOff: test.daysOff.map {
            DayOff(id: UUID(), startDate: dayOffDate($0.0, test.zoneID), endDate: dayOffDate($0.1, test.zoneID),
                   kind: .dayOff)
        },
        bufferMinutes: test.buffer, minNoticeHours: test.notice, maxDaysAhead: test.horizon,
        timeZoneID: timeZone.identifier
    )
    let request = FreeSlotsRequest(
        day: local("\(test.dayLocal) 12:00", test.zoneID), durationMinutes: test.minutes, now: test.now,
        settings: settings, appointments: test.appointments, blocks: test.blocks, stepMinutes: test.step
    )
    let slots = FreeSlotsCalculator.slots(for: request).map(iso)
    func interval(_ value: DateInterval) -> [String] { [iso(value.start), iso(value.end)] }
    return [
        "name": test.name,
        "input": [
            "now": iso(test.now),
            "day": test.dayLocal,
            "durationMinutes": test.minutes,
            "stepMinutes": test.step,
            "settings": [
                "weekly": test.weekly.map { ["weekday": $0.weekday, "startMinutes": $0.startMinutes,
                                              "endMinutes": $0.endMinutes] },
                "breaks": test.breaks.map { (rule: BreakRule) -> [String: Any] in
                    var entry: [String: Any] = ["startMinutes": rule.startMinutes, "endMinutes": rule.endMinutes]
                    if let weekday = rule.weekday { entry["weekday"] = weekday }
                    return entry
                },
                "daysOff": test.daysOff.map { ["startDate": $0.0, "endDate": $0.1] },
                "bufferMinutes": test.buffer,
                "minNoticeHours": test.notice,
                "maxDaysAhead": test.horizon,
                "timeZoneID": test.zoneID
            ],
            "appointments": test.appointments.map(interval),
            "blocks": test.blocks.map(interval)
        ],
        "expected": slots
    ]
}

var slotCases: [SlotCase] = []

// Maria's ordinary week (ported from FreeSlotsCalculatorTests).
slotCases.append(SlotCase(name: "plain working day around lunch", now: referenceNow, dayLocal: "2026-10-08",
                          weekly: mariasWeek(), breaks: [lunch]))
slotCases.append(SlotCase(
    name: "a booked visit plus the 15 minute buffer", now: referenceNow, dayLocal: "2026-10-08",
    weekly: mariasWeek(), breaks: [lunch],
    appointments: [DateInterval(start: local("2026-10-08 15:00", saoPaulo), end: local("2026-10-08 16:30", saoPaulo))]
))
slotCases.append(SlotCase(
    name: "a block has no buffer", now: referenceNow, dayLocal: "2026-10-08", weekly: mariasWeek(), breaks: [lunch],
    blocks: [DateInterval(start: local("2026-10-08 15:00", saoPaulo), end: local("2026-10-08 16:00", saoPaulo))]
))
slotCases.append(SlotCase(name: "a day off range (inclusive)", now: referenceNow, dayLocal: "2026-10-08",
                          weekly: mariasWeek(), breaks: [lunch], daysOff: [("2026-10-08", "2026-10-09")]))
slotCases.append(SlotCase(name: "the last day of a day off range", now: referenceNow, dayLocal: "2026-10-09",
                          weekly: mariasWeek(), breaks: [lunch], daysOff: [("2026-10-08", "2026-10-09")]))
slotCases.append(SlotCase(name: "the day after a day off range", now: referenceNow, dayLocal: "2026-10-10",
                          weekly: mariasWeek(), breaks: [lunch], daysOff: [("2026-10-08", "2026-10-09")]))
slotCases.append(SlotCase(name: "a weekday she does not work (Monday)", now: referenceNow, dayLocal: "2026-10-12",
                          weekly: mariasWeek(), breaks: [lunch]))
slotCases.append(SlotCase(name: "a day in the past", now: referenceNow, dayLocal: "2026-09-24",
                          weekly: mariasWeek(), breaks: [lunch]))
slotCases.append(SlotCase(name: "minimum notice hides the morning of today", now: referenceNow, dayLocal: "2026-10-01",
                          weekly: mariasWeek(), breaks: [lunch]))
slotCases.append(SlotCase(name: "minimum notice of zero keeps a start at the same instant", now: local("2026-10-01 14:00", saoPaulo),
                          dayLocal: "2026-10-01", weekly: mariasWeek(), breaks: [lunch], notice: 0))
slotCases.append(SlotCase(name: "beyond the booking window (60 days)", now: referenceNow, dayLocal: "2026-12-31",
                          weekly: mariasWeek(), breaks: [lunch], horizon: 60))
slotCases.append(SlotCase(name: "inside a 120 day window", now: referenceNow, dayLocal: "2026-12-31",
                          weekly: mariasWeek(), breaks: [lunch], horizon: 120))
slotCases.append(SlotCase(name: "exactly the last bookable day", now: referenceNow, dayLocal: "2026-11-30",
                          weekly: mariasWeek(), breaks: [lunch], horizon: 60))
slotCases.append(SlotCase(name: "the day after the last bookable day", now: referenceNow, dayLocal: "2026-12-01",
                          weekly: mariasWeek(), breaks: [lunch], horizon: 60))
slotCases.append(SlotCase(name: "a visit longer than the working stretch", now: referenceNow, dayLocal: "2026-10-08",
                          minutes: 660, weekly: mariasWeek(), breaks: []))
slotCases.append(SlotCase(
    name: "two stretches in one day", now: referenceNow, dayLocal: "2026-10-08", minutes: 30,
    weekly: [AvailabilityRule(weekday: 5, startMinutes: 540, endMinutes: 600),
             AvailabilityRule(weekday: 5, startMinutes: 1_020, endMinutes: 1_080)],
    buffer: 0, notice: 0
))
slotCases.append(SlotCase(
    name: "a weekday-specific break (Thursday)", now: referenceNow, dayLocal: "2026-10-08", weekly: mariasWeek(),
    breaks: [lunch, BreakRule(weekday: 5, startMinutes: 960, endMinutes: 975, label: "Coffee")]
))
slotCases.append(SlotCase(
    name: "a weekday-specific break does not apply on Friday", now: referenceNow, dayLocal: "2026-10-09",
    weekly: mariasWeek(), breaks: [lunch, BreakRule(weekday: 5, startMinutes: 960, endMinutes: 975, label: "Coffee")]
))
slotCases.append(SlotCase(name: "a step of 15 minutes", now: referenceNow, dayLocal: "2026-10-08", step: 15,
                          weekly: mariasWeek(), breaks: [lunch]))
slotCases.append(SlotCase(name: "a 45 minute visit on a 30 minute grid", now: referenceNow, dayLocal: "2026-10-08",
                          minutes: 45, weekly: mariasWeek(), breaks: [lunch]))
slotCases.append(SlotCase(name: "an evening stretch that ends at midnight", now: referenceNow, dayLocal: "2026-10-08",
                          minutes: 60, weekly: [AvailabilityRule(weekday: 5, startMinutes: 1_080, endMinutes: 1_440)],
                          buffer: 0))
slotCases.append(SlotCase(name: "an empty stretch (end before start) offers nothing", now: referenceNow,
                          dayLocal: "2026-10-08", weekly: [AvailabilityRule(weekday: 5, startMinutes: 900, endMinutes: 600)]))
slotCases.append(SlotCase(
    name: "two visits and a block in one day", now: referenceNow, dayLocal: "2026-10-09", weekly: mariasWeek(),
    breaks: [lunch],
    appointments: [
        DateInterval(start: local("2026-10-09 10:00", saoPaulo), end: local("2026-10-09 11:00", saoPaulo)),
        DateInterval(start: local("2026-10-09 14:00", saoPaulo), end: local("2026-10-09 15:15", saoPaulo))
    ],
    blocks: [DateInterval(start: local("2026-10-09 17:00", saoPaulo), end: local("2026-10-09 18:00", saoPaulo))]
))
slotCases.append(SlotCase(name: "a booking that started yesterday and runs into today still blocks the morning",
                          now: referenceNow, dayLocal: "2026-10-08", weekly: mariasWeek(), breaks: [lunch],
                          appointments: [DateInterval(start: local("2026-10-07 23:00", saoPaulo),
                                                      end: local("2026-10-08 09:30", saoPaulo))]))

// Daylight saving: counts in a 00:00 to 05:00 window, then wall-clock subtleties.
func overnight(_ name: String, _ zoneID: String, _ day: String, weekday: Int, from: Int = 0, to: Int = 300,
               minutes: Int = 60, step: Int = 60, breaks: [BreakRule] = [], notice: Int = 0) -> SlotCase {
    SlotCase(name: name, zoneID: zoneID, now: local("2026-02-01 12:00", zoneID), dayLocal: day, minutes: minutes,
             step: step, weekly: [AvailabilityRule(weekday: weekday, startMinutes: from, endMinutes: to)],
             breaks: breaks, buffer: 0, notice: notice, horizon: 365)
}

let changes: [(String, String, Int)] = [
    ("Europe/Lisbon", "2026-03-29", 1), ("Europe/Lisbon", "2026-10-25", 1),
    ("Europe/Madrid", "2026-03-29", 1), ("Europe/Madrid", "2026-10-25", 1),
    ("Europe/Rome", "2026-03-29", 1), ("Europe/Rome", "2026-10-25", 1),
    ("Europe/Berlin", "2026-03-29", 1), ("Europe/Berlin", "2026-10-25", 1),
    ("Europe/London", "2026-03-29", 1), ("Europe/London", "2026-10-25", 1),
    ("America/New_York", "2026-03-08", 1), ("America/New_York", "2026-11-01", 1)
]
for (zoneID, day, weekday) in changes {
    slotCases.append(overnight("clock change 00:00-05:00 in \(zoneID) on \(day)", zoneID, day, weekday: weekday))
    slotCases.append(overnight("clock change 00:00-05:00 in 30 minute steps in \(zoneID) on \(day)", zoneID, day,
                               weekday: weekday, minutes: 30, step: 30))
    slotCases.append(overnight("window starting inside the change 01:30-05:00 in \(zoneID) on \(day)", zoneID, day,
                               weekday: weekday, from: 90, to: 300, minutes: 30, step: 30))
    slotCases.append(overnight("window ending inside the change 00:00-02:30 in \(zoneID) on \(day)", zoneID, day,
                               weekday: weekday, from: 0, to: 150, minutes: 30, step: 30))
    slotCases.append(overnight("a break inside the change 01:00-03:00 in \(zoneID) on \(day)", zoneID, day,
                               weekday: weekday, minutes: 30, step: 30,
                               breaks: [BreakRule(weekday: nil, startMinutes: 60, endMinutes: 180, label: "Break")]))
}
for (zoneID, day, weekday) in [("America/Mexico_City", "2026-03-29", 1), ("America/Mexico_City", "2026-10-25", 1),
                               ("America/Sao_Paulo", "2026-03-29", 1), ("America/Sao_Paulo", "2026-11-01", 1),
                               ("Europe/Istanbul", "2026-03-29", 1), ("Asia/Kolkata", "2026-03-29", 1),
                               ("Asia/Riyadh", "2026-03-29", 1), ("Asia/Jakarta", "2026-03-29", 1)] {
    slotCases.append(overnight("zone without clock change \(zoneID) on \(day)", zoneID, day, weekday: weekday))
}
for (zoneID, day) in [("Europe/Lisbon", "2026-03-29"), ("Europe/Lisbon", "2026-10-25"),
                      ("America/New_York", "2026-03-08"), ("America/New_York", "2026-11-01")] {
    slotCases.append(SlotCase(
        name: "working day 09:00-19:00 on the change day \(zoneID) \(day)", zoneID: zoneID,
        now: local("2026-02-01 12:00", zoneID), dayLocal: day,
        weekly: [AvailabilityRule(weekday: 1, startMinutes: 540, endMinutes: 1_140)], buffer: 0, notice: 0, horizon: 365
    ))
}
// A booking and a buffer across the Lisbon spring-forward gap (instants are UTC so they are unambiguous).
slotCases.append(SlotCase(
    name: "a buffer across the Lisbon gap", zoneID: "Europe/Lisbon", now: local("2026-02-01 12:00", "Europe/Lisbon"),
    dayLocal: "2026-03-29", step: 30,
    weekly: [AvailabilityRule(weekday: 1, startMinutes: 0, endMinutes: 300)],
    buffer: 30, notice: 0, horizon: 365,
    appointments: [DateInterval(start: utc("2026-03-29T00:00:00.000Z"), end: utc("2026-03-29T01:00:00.000Z"))]
))
slotCases.append(SlotCase(
    name: "the same wall clock in Lisbon and Sao Paulo are different instants", zoneID: "Europe/Lisbon",
    now: local("2026-10-01 12:00", "Europe/Lisbon"), dayLocal: "2026-10-08", weekly: mariasWeek(), breaks: [lunch]
))
slotCases.append(SlotCase(
    name: "Mexico City working day", zoneID: "America/Mexico_City", now: local("2026-10-01 12:00", "America/Mexico_City"),
    dayLocal: "2026-10-08", weekly: mariasWeek(), breaks: [lunch]
))
slotCases.append(SlotCase(
    name: "Istanbul fixed UTC+3", zoneID: "Europe/Istanbul", now: local("2026-10-01 12:00", "Europe/Istanbul"),
    dayLocal: "2026-10-08", weekly: mariasWeek(), breaks: [lunch]
))

// MARK: - Cancellation

func policyJSON(_ policy: CancellationPolicy) -> [String: Any] {
    var json: [String: Any] = [
        "freeWindowHours": policy.freeWindowHours,
        "clientCanReschedule": policy.clientCanReschedule,
        "afterWindowCancel": policy.afterWindowCancel.rawValue,
        "afterWindowReschedule": policy.afterWindowReschedule.rawValue,
        "askConfirmation": policy.askConfirmation,
        "graceMinutes": policy.graceMinutes
    ]
    if let maximum = policy.maxReschedules { json["maxReschedules"] = maximum }
    return json
}

func cancelName(_ value: CancellationDecision.Cancel) -> String {
    switch value {
    case .free: "free"
    case .allowedWithWarning: "allowedWithWarning"
    case .askByMessage: "askByMessage"
    case .unavailable: "unavailable"
    }
}

func rescheduleName(_ value: CancellationDecision.Reschedule) -> String {
    switch value {
    case .direct: "direct"
    case .request: "request"
    case .message: "message"
    case .unavailable: "unavailable"
    }
}

let startsAt = utc("2026-10-15T18:00:00.000Z")
var cancellationCases: [[String: Any]] = []
var policies: [(String, CancellationPolicy)] = [("standard", .standard)]
var strict = CancellationPolicy.standard
strict.afterWindowCancel = .message
strict.afterWindowReschedule = .message
policies.append(("strict", strict))
var rigid = CancellationPolicy.standard
rigid.clientCanReschedule = false
rigid.maxReschedules = nil
policies.append(("noReschedule", rigid))
var unlimited = CancellationPolicy.standard
unlimited.maxReschedules = nil
unlimited.freeWindowHours = 48
policies.append(("unlimitedReschedules48h", unlimited))
var short = CancellationPolicy.standard
short.freeWindowHours = 2
short.maxReschedules = 1
policies.append(("window2hMax1", short))

for (label, policy) in policies {
    for hours in [100.0, 72.0, 48.0, 47.99, 25.0, 24.0, 23.99, 12.0, 11.99, 2.0, 1.99, 0.5, 0.0, -3.0] {
        for reschedules in [0, 1, 2, 5] {
            let now = startsAt.addingTimeInterval(-hours * 3_600)
            let decision = CancellationEvaluator.decide(policy: policy, startsAt: startsAt, now: now,
                                                        rescheduleCount: reschedules)
            cancellationCases.append([
                "name": "\(label) at \(hours)h with \(reschedules) reschedules",
                "policy": policyJSON(policy),
                "startsAt": iso(startsAt),
                "now": iso(now),
                "rescheduleCount": reschedules,
                "expected": [
                    "cancel": cancelName(decision.cancel),
                    "reschedule": rescheduleName(decision.reschedule),
                    "isInsideFreeWindow": decision.isInsideFreeWindow,
                    "cancellationWouldBeLate": decision.cancellationWouldBeLate,
                    "hoursUntilStart": decision.hoursUntilStart
                ]
            ])
        }
    }
}

var lateCases: [[String: Any]] = []
for (label, policy) in policies {
    for hours in [100.0, 48.0, 24.0, 23.99, 2.0, 1.0, 0.0, -1.0] {
        let cancelledAt = startsAt.addingTimeInterval(-hours * 3_600)
        lateCases.append([
            "name": "\(label) cancelled \(hours)h before",
            "policy": policyJSON(policy),
            "startsAt": iso(startsAt),
            "cancelledAt": iso(cancelledAt),
            "expected": CancellationEvaluator.isLateCancellation(policy: policy, startsAt: startsAt, cancelledAt: cancelledAt)
        ])
    }
}

// MARK: - Registration quota (D42)

var quotaCases: [[String: Any]] = []
for ledger in [0, 5, 9, 10, 11, 40] {
    for server in [nil, 0, 3, 10, 12] as [Int?] {
        for plan in [false, true] {
            for count in [1, 4, 30] {
                let quota = RegistrationQuota(ledgerCount: ledger, serverCount: server, hasActivePlan: plan)
                var expected: [String: Any]
                switch quota.decision(forNewClients: count) {
                case .allowed: expected = ["decision": "allowed"]
                case .needsSubscription: expected = ["decision": "needsSubscription"]
                case .allowedPartially(let allowed): expected = ["decision": "allowedPartially", "count": allowed]
                }
                expected["used"] = quota.used
                expected["remainingFree"] = quota.remainingFree
                var entry: [String: Any] = ["ledgerCount": ledger, "hasActivePlan": plan, "forNewClients": count,
                                            "expected": expected]
                if let server { entry["serverCount"] = server }
                quotaCases.append(entry)
            }
        }
    }
}

// MARK: - Output

let output: [String: Any] = [
    "generatedBy": "firebase/scripts/rules-fixtures/generate.sh (compiles BelloHub/Models/{Agenda,Business,Policy,Plan} rules)",
    "slotStepMinutes": 15,
    "freeSlots": slotCases.map(slotJSON),
    "cancellation": cancellationCases,
    "lateCancellation": lateCases,
    "registrationQuota": quotaCases
]
let data = try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
FileHandle.standardOutput.write(data)
FileHandle.standardOutput.write(Data("\n".utf8))
