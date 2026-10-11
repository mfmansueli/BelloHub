//
//  SceneCaptureObserver.swift
//  BelloHub
//

import SwiftUI
import UIKit

/// Reports whether the screen is being recorded, mirrored or shared (`UITraitCollection.sceneCaptureState`, iOS 17+).
/// SwiftUI has no environment value for it, so a zero-size UIKit view reads the trait and follows its changes. Used by
/// `hiddenWhileCaptured()`; it has no business rules.
struct SceneCaptureObserver: UIViewRepresentable {
    @Binding var isCaptured: Bool

    func makeUIView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.onChange = { captured in
            Task { @MainActor in
                if isCaptured != captured { isCaptured = captured }
            }
        }
        return view
    }

    func updateUIView(_ uiView: ObserverView, context: Context) {}

    /// The view that owns the trait registration.
    final class ObserverView: UIView {
        var onChange: ((Bool) -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            isAccessibilityElement = false
            registerForTraitChanges([UITraitSceneCaptureState.self]) { (view: ObserverView, _: UITraitCollection) in
                view.report()
            }
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not used")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        private func report() {
            onChange?(traitCollection.sceneCaptureState == .active)
        }
    }
}
