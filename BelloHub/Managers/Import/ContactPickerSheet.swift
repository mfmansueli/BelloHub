//
//  ContactPickerSheet.swift
//  BelloHub
//

import Contacts
import ContactsUI
import SwiftUI

/// The system's contact picker for SwiftUI (UIKit only through a representable, CLAUDE.md section 1). With a delegate
/// that implements the plural `didSelect`, the picker lets her tick several contacts and answers once. It runs
/// outside the app, so the app never sees a contact she did not tick.
struct ContactPickerSheet: UIViewControllerRepresentable {
    /// The contacts she chose as plain candidates, or nil when she cancelled.
    let onFinish: ([ImportCandidate]?) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        private let onFinish: ([ImportCandidate]?) -> Void

        init(onFinish: @escaping ([ImportCandidate]?) -> Void) {
            self.onFinish = onFinish
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            onFinish(ContactCandidateMapper.candidates(from: contacts))
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onFinish(nil)
        }
    }
}
