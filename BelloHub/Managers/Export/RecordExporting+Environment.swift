//
//  RecordExporting+Environment.swift
//  BelloHub
//

import SwiftUI

extension EnvironmentValues {
    /// How a record becomes a file. The default writes a plain PDF; a test injects a fake and the owner swaps it later.
    @Entry var recordExporter: any RecordExporting = PDFRecordExporter()
}
