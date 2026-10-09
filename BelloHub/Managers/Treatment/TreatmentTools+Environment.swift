//
//  TreatmentTools+Environment.swift
//  BelloHub
//

import SwiftUI

/// The treatment flow's replaceable technologies, read from the environment so a screen or a test can inject a fake.
/// Each S7 slice adds its own entry here or in its own file (`photoProcessing`, `recordExporting`).
extension EnvironmentValues {
    @Entry var voiceCapture: any VoiceCapturing = UnavailableVoiceCapture()
    @Entry var recordStructuring: any RecordStructuring = UnavailableRecordStructuring()
}
