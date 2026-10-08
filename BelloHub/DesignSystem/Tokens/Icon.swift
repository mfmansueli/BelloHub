//
//  Icon.swift
//  BelloHub
//

import SwiftUI

/// The prototype's line icons mapped to SF Symbols in one place (docs/08-DESIGN-SYSTEM.md section 7),
/// so the whole app can change a symbol with one edit. Directional symbols (`chevron.forward`,
/// `chevron.backward`) mirror by themselves in right-to-left languages. Decorative uses must hide the
/// image from VoiceOver; an icon-only button needs an `accessibilityLabel`.
enum Icon: String, CaseIterable {
    case home = "house"
    case clients = "person.2"
    case calendar = "calendar"
    case bell = "bell"
    case plus = "plus"
    case check = "checkmark"
    case forward = "chevron.forward"
    case back = "chevron.backward"
    case chevronUpDown = "chevron.up.chevron.down"
    case close = "xmark"
    case key = "key"
    case print = "printer"
    case lock = "lock"
    case camera = "camera"
    case mic = "mic"
    case link = "link"
    case phone = "phone"
    case chat = "bubble.left"
    case clock = "clock"
    case user = "person"
    case userPlus = "person.badge.plus"
    case tag = "tag"
    case shield = "checkmark.shield"
    case gear = "gearshape"
    case image = "photo"
    case document = "doc.text"
    case download = "arrow.down.to.line"
    case share = "square.and.arrow.up"
    case qr = "qrcode"
    case search = "magnifyingglass"
    case trash = "trash"
    case info = "info.circle"
    case sparkle = "sparkles"
    case repeatArrows = "arrow.triangle.2.circlepath"
    case mail = "envelope"
    case globe = "globe"
    case faceID = "faceid"
    case star = "star"
    case bolt = "bolt"
    case help = "questionmark.circle"
    case pencil = "pencil"
    case box = "shippingbox"
    case scissors = "scissors"
    case sliders = "slider.horizontal.3"
    case cloud = "icloud"
    case wifi = "wifi"
    case wifiSlash = "wifi.slash"
    case alert = "exclamationmark.triangle"
    case logout = "rectangle.portrait.and.arrow.right"
    case gift = "gift"
    case moon = "moon"

    var symbolName: String { rawValue }
}

extension Image {
    init(icon: Icon) {
        self.init(systemName: icon.symbolName)
    }
}
