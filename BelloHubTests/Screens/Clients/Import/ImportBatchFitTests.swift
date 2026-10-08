//
//  ImportBatchFitTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Testing

@Suite("ImportBatchFit")
struct ImportBatchFitTests {
    private func usage(used: Int, hasPlan: Bool = false) -> RegistrationUsage {
        RegistrationUsage(quota: RegistrationQuota(ledgerCount: used, hasActivePlan: hasPlan))
    }

    @Test("A batch that fits goes through whole", arguments: [(0, 10, 10), (6, 4, 4), (9, 1, 1), (0, 0, 0)])
    func fits(used: Int, selected: Int, willImport: Int) {
        let fit = ImportBatchFit(selected: selected, usage: usage(used: used))

        #expect(fit.willImport == willImport && fit.waiting == 0 && !fit.needsPlan)
    }

    @Test("A batch larger than the free slots splits into what goes through and what waits")
    func splits() {
        let fit = ImportBatchFit(selected: 30, usage: usage(used: 6))

        #expect(fit.willImport == 4 && fit.waiting == 26 && fit.needsPlan)
    }

    @Test("With no free slot left everything waits")
    func nothingFits() {
        let fit = ImportBatchFit(selected: 5, usage: usage(used: 10))

        #expect(fit.willImport == 0 && fit.waiting == 5)
    }

    @Test("Registrations past the free ten still leave nothing free, never a negative number")
    func pastTheLimit() {
        let fit = ImportBatchFit(selected: 3, usage: usage(used: 14))

        #expect(fit.willImport == 0 && fit.waiting == 3)
    }

    @Test("A plan lets everything through")
    func plan() {
        let fit = ImportBatchFit(selected: 30, usage: usage(used: 10, hasPlan: true))

        #expect(fit.willImport == 30 && fit.waiting == 0)
    }

    @Test("A negative selection counts as none")
    func negative() {
        #expect(ImportBatchFit(selected: -3, usage: usage(used: 0)).willImport == 0)
    }
}
