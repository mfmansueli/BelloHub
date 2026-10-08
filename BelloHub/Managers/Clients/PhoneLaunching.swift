//
//  PhoneLaunching.swift
//  BelloHub
//

/// Starts a phone call, behind a protocol so the client profile is tested without leaving the app.
@MainActor
protocol PhoneLaunching: AnyObject {
    /// Opens the system's call prompt for a number in international form (`+5511987654321`). False when the phone
    /// cannot place a call (an iPhone without a SIM, the simulator) or the number is not one.
    func call(_ phoneE164: String) async -> Bool
}
