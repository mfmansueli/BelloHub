//
//  PreVisitChecklist.swift
//  BelloHub
//

import Foundation

/// Everything the professional glances at before she starts a visit (3.2 and 3.3), derived from what the vault holds
/// about the client. Pure: the ViewModel reads the vault and hands the values in. It informs and never blocks (D16).
struct PreVisitChecklist: Equatable, Sendable {
    /// What the vault holds, read for one visit.
    struct Input: Sendable {
        let client: Client
        let appointment: Appointment
        var service: Service?
        var forms: [HealthForm] = []
        var consents: [ConsentRecord] = []
        var patchTests: [PatchTest] = []
        var catalog: HealthFormCatalog?
        var plans: [SessionPlan] = []
        var appointments: [Appointment] = []
        /// "Ask again every N months", the professional's setting.
        var reviewMonths = HealthFormTemplateRules.defaultReviewMonths
    }

    struct Plan: Equatable, Sendable {
        let name: String
        let intervalWeeks: Int
        let progress: SessionPlanProgress
    }

    let allergies: [String]
    let importantNote: String?
    let sensitivities: [String]
    let preferences: [String]
    let contraindications: ContraindicationStatus
    let patchTest: PatchTestStatus
    /// When the client last gave her health history (a signed paper form or an older answered one); nil when never.
    let healthFormSignedAt: Date?
    /// The form is older than "ask again every N months".
    let healthFormReviewDue: Bool
    /// When the latest consent record she marked signed is dated; nil when none is signed (D55). Health forms count
    /// under `healthFormSignedAt`, not here.
    let consentSignedAt: Date?
    /// The plan this visit belongs to, or the client's plan in progress.
    let plan: Plan?
    /// Her latest completed visit before this one.
    let lastVisit: Appointment?

    /// Something she should read before starting: an allergy, a note, a warning or a missing patch test.
    var hasAttention: Bool {
        !allergies.isEmpty || importantNote != nil || contraindications.hasWarnings || patchTest.needsAttention
    }

    static func make(_ input: Input, now: Date, calendar: Calendar) -> PreVisitChecklist {
        let form = HealthFormTemplateRules.latestForm(in: input.forms)
        let signed = HealthFormTemplateRules.lastHealthFormDate(forms: input.forms, records: input.consents)
        let review = signed.map {
            HealthFormTemplateRules.reviewStatus(signedAt: $0, months: input.reviewMonths, now: now, calendar: calendar)
        }
        let own = input.appointments.filter { $0.clientID == input.client.id }
        return PreVisitChecklist(
            allergies: input.client.allergies,
            importantNote: input.client.importantNote.flatMap { $0.isEmpty ? nil : $0 },
            sensitivities: input.client.sensitivities,
            preferences: input.client.preferences,
            contraindications: ContraindicationStatus.make(service: input.service, form: form, catalog: input.catalog),
            patchTest: PatchTestStatus.make(service: input.service, patchTests: input.patchTests, now: now),
            healthFormSignedAt: signed,
            healthFormReviewDue: review?.isDue ?? false,
            consentSignedAt: input.consents.filter { $0.isSigned && $0.kind != .healthForm }.map(\.effectiveDate).max(),
            plan: plan(for: input.appointment, plans: input.plans, appointments: own, calendar: calendar),
            lastVisit: own.filter { $0.status == .completed && $0.startsAt < input.appointment.startsAt }
                .max { $0.startsAt < $1.startsAt }
        )
    }

    /// The plan the visit is booked into, otherwise the most recently started one with sessions to go.
    private static func plan(
        for appointment: Appointment, plans: [SessionPlan], appointments: [Appointment], calendar: Calendar
    ) -> Plan? {
        let linked = appointment.sessionPlanID.flatMap { id in plans.first { $0.id == id } }
        let chosen = linked ?? plans.sorted { $0.startDate > $1.startDate }.first { plan in
            !SessionPlanProgress.make(plan: plan, appointments: appointments, calendar: calendar).isFinished
        }
        return chosen.map {
            Plan(
                name: $0.name, intervalWeeks: $0.intervalWeeks,
                progress: SessionPlanProgress.make(plan: $0, appointments: appointments, calendar: calendar)
            )
        }
    }
}
