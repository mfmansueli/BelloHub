//
//  WaitlistRequest.swift
//  BelloHub
//

import Foundation

/// Somebody who asked, on her booking page, to be told when a time opens up (2.9, `waitlist/{id}`). Set by the server;
/// the app offers a time through `offerWaitlistSlot` or removes the entry. Distinct from the vault's `WaitlistEntry`
/// (the professional's own list): this one lives on the server and holds no client id.
struct WaitlistRequest: Identifiable, Hashable, Codable, Sendable {
    enum Status: String, PersistedEnum {
        case waiting
        case offered
        case booked

        static let fallback = Status.waiting
    }

    let id: String
    var name: String
    var phone: String
    var serviceId: String?
    var serviceName: String?
    /// `YYYY-MM-DD` in her time zone.
    var dayFrom: String
    var dayTo: String
    var status: Status
    var createdAt: Date
    var offeredAt: Date?

    init(
        id: String, name: String, phone: String, serviceId: String? = nil, serviceName: String? = nil,
        dayFrom: String, dayTo: String, status: Status = .waiting, createdAt: Date, offeredAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.phone = phone
        self.serviceId = serviceId
        self.serviceName = serviceName
        self.dayFrom = dayFrom
        self.dayTo = dayTo
        self.status = status
        self.createdAt = createdAt
        self.offeredAt = offeredAt
    }

    var isWaiting: Bool { status == .waiting }

    /// Whether `day` (a `YYYY-MM-DD` in her zone) falls inside the days she can come.
    func covers(day: String) -> Bool {
        dayFrom <= day && day <= dayTo
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        phone = try container.decodeIfPresent(String.self, forKey: .phone) ?? ""
        serviceId = try container.decodeIfPresent(String.self, forKey: .serviceId)
        serviceName = try container.decodeIfPresent(String.self, forKey: .serviceName)
        dayFrom = try container.decodeIfPresent(String.self, forKey: .dayFrom) ?? ""
        dayTo = try container.decodeIfPresent(String.self, forKey: .dayTo) ?? dayFrom
        status = Status(persisted: try container.decodeIfPresent(String.self, forKey: .status) ?? "waiting")
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(timeIntervalSince1970: 0)
        offeredAt = try container.decodeIfPresent(Date.self, forKey: .offeredAt)
    }
}
