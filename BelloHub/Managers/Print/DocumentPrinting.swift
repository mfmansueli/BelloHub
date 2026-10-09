//
//  DocumentPrinting.swift
//  BelloHub
//

/// The system print sheet behind a protocol, so the recovery key screen is tested without a printer.
@MainActor
protocol DocumentPrinting: AnyObject {
    func print(text: String, jobName: String)
}
