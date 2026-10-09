//
//  ActivityShareSheet.swift
//  BelloHub
//

import SwiftUI
import UIKit

/// The system share sheet for one file. `ShareLink` cannot say when the sheet closed or whether she shared, and the
/// exported PDF must be deleted as soon as it was, so the sheet is wrapped here (UIKit only through a representable).
struct ActivityShareSheet: UIViewControllerRepresentable {
    let url: URL
    /// Called when the sheet closes; `completed` is true when she shared or saved the file.
    let onFinish: (_ completed: Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            Task { @MainActor in onFinish(completed) }
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
