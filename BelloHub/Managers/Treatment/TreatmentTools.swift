//
//  TreatmentTools.swift
//  BelloHub
//

import SwiftUI

/// The treatment flow's replaceable technologies, built once with the app's other dependencies (`AppDependencies`) and
/// given to the view tree with `.treatmentTools(_:)`. v1 ships the defaults (D53): no voice, no structuring, the real
/// camera. A UI-test launch can swap in scripted ones (`-uiVoice scripted`, `-uiCamera scripted`).
@MainActor
struct TreatmentTools {
    var voiceCapture: any VoiceCapturing = UnavailableVoiceCapture()
    var recordStructuring: any RecordStructuring = UnavailableRecordStructuring()
    var cameraCapture: any CameraCapturing = AVCameraCapture()
    var photoProcessing: any PhotoProcessing = ImageIOPhotoProcessing()

    static func make(options: LaunchOptions = .current) -> TreatmentTools {
        #if DEBUG
        var tools = TreatmentTools()
        if options.uiVoice == "scripted" {
            tools.voiceCapture = ScriptedVoiceCapture()
            tools.recordStructuring = ScriptedRecordStructuring()
        }
        if options.uiCamera == "scripted" { tools.cameraCapture = ScriptedCameraCapture() }
        return tools
        #else
        return TreatmentTools()
        #endif
    }
}

extension View {
    /// Puts the treatment technologies in the environment, where the treatment flow reads them.
    func treatmentTools(_ tools: TreatmentTools) -> some View {
        environment(\.voiceCapture, tools.voiceCapture)
            .environment(\.recordStructuring, tools.recordStructuring)
            .environment(\.cameraCapture, tools.cameraCapture)
            .environment(\.photoProcessing, tools.photoProcessing)
    }
}
