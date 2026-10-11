//
//  DocumentPrinting.swift
//  BelloHub
//

/// The system print sheet behind a protocol, so the recovery key screen is tested without a printer.
@MainActor
protocol DocumentPrinting: AnyObject {
    func printDocument(text: String, jobName: String)
}
