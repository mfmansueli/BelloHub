//
//  CPUTime.swift
//  BelloHubTests
//

import Foundation

/// Measures the CPU time the calling thread spends in a piece of work, not the time on the wall clock. A test that
/// asserts "2,000 rows in under a second" must not fail because the machine is busy running the rest of the suite
/// (Swift Testing runs suites in parallel and a Debug build is slow): CPU time of the thread is what the work costs.
enum CPUTime {
    static func measure(_ work: () -> Void) -> Duration {
        let start = clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)
        work()
        let end = clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)
        return .nanoseconds(Int64(end - start))
    }
}
