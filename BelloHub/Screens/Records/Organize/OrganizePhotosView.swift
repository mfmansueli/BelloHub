//
//  OrganizePhotosView.swift
//  BelloHub
//

import SwiftUI

/// Photos with no visit, each with a menu of the client's visits to place it in. A photo she leaves alone stays where
/// it is, kept and private.
struct OrganizePhotosView: View {
    let clientID: UUID
    @Environment(VaultService.self) private var vault

    var body: some View {
        OrganizePhotosContentView(clientID: clientID, vault: vault)
    }
}
