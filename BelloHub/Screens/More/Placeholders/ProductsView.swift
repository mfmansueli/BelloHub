//
//  ProductsView.swift
//  BelloHub
//

import SwiftUI

/// PLACEHOLDER for 6.4 Products. An S5 slice replaces it with the real screen (same name and `init()`, in its
/// feature folder) and deletes this file. Nothing here is meant to ship.
struct ProductsView: View {
    var body: some View {
        Text(verbatim: "ProductsView")
            .accessibilityIdentifier("products.placeholder")
    }
}

#Preview {
    NavigationStack { ProductsView() }
}
