//
//  ExportAllView.swift
//  BelloHub
//

import SwiftUI

/// 7.8 Export all my data, as Privacy (or the delete-account sheet) opens it. Reads the Services from the environment
/// and hands them to `ExportAllContentView`, which owns the ViewModel.
struct ExportAllView: View {
    @Environment(DataExportService.self) private var export
    @Environment(ProfileService.self) private var profile

    var body: some View {
        ExportAllContentView(export: export, profile: profile)
    }
}

#Preview {
    let vault = VaultService(repository: nil)
    NavigationStack { ExportAllView() }
        .environment(DataExportService(vault: vault))
        .environment(ProfileService(vault: vault))
}
