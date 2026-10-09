//
//  ExportBundleBuilder.swift
//  BelloHub
//

import Foundation

/// Turns a vault snapshot into the files of the export: `clients.csv`, `appointments.csv`, `records.csv`, the
/// summary the PDF is rendered from, and the photos when asked. Column names are localized through the catalog;
/// values use `Formatters` for dates and money, so her spreadsheet reads in her language. Pure: no IO, fixed `now`.
struct ExportBundleBuilder: Sendable {
    let formatters: Formatters
    let locale: Locale
    let now: Date

    // MARK: - Tables

    func clientsTable(_ snapshot: ExportSnapshot) -> CSVTable {
        let tagNames = Dictionary(uniqueKeysWithValues: snapshot.tags.map { ($0.id, $0.name) })
        let visitsByClient = Dictionary(grouping: snapshot.appointments.filter { $0.status == .completed },
                                        by: \.clientID)
        let rows = snapshot.clients.sorted(by: Self.byName).map { client -> [String] in
            let lastVisit = visitsByClient[client.id]?.map(\.startsAt).max()
            return [
                client.name,
                client.phoneE164 ?? "",
                client.email ?? "",
                client.birthday.map(Self.birthdayText) ?? "",
                client.tagIDs.compactMap { tagNames[$0] }.joined(separator: "; "),
                formatters.number(visitsByClient[client.id]?.count ?? 0),
                lastVisit.map(formatters.shortDate) ?? "",
                client.importantNote ?? "",
                client.allergies.joined(separator: "; "),
                client.sensitivities.joined(separator: "; "),
                client.preferences.joined(separator: "; "),
                client.isArchived ? text("export.csv.yes") : text("export.csv.no"),
                formatters.shortDate(client.createdAt)
            ]
        }
        return CSVTable(header: [
            "export.csv.name", "export.csv.phone", "export.csv.email", "export.csv.birthday", "export.csv.tags",
            "export.csv.visits", "export.csv.lastVisit", "export.csv.importantNote", "export.csv.allergies",
            "export.csv.sensitivities", "export.csv.preferences", "export.csv.archived", "export.csv.createdAt"
        ].map(text), rows: rows)
    }

    func appointmentsTable(_ snapshot: ExportSnapshot) -> CSVTable {
        let names = clientNames(snapshot)
        let rows = snapshot.appointments.sorted { $0.startsAt < $1.startsAt }.map { appointment -> [String] in
            [
                names[appointment.clientID] ?? "",
                appointment.serviceName,
                formatters.shortDate(appointment.startsAt),
                formatters.time(appointment.startsAt, use24Hour: snapshot.profile?.use24Hour),
                formatters.minutes(appointment.totalMinutes),
                appointment.status.rawValue,
                appointment.origin.rawValue,
                appointment.privateNote ?? ""
            ]
        }
        return CSVTable(header: [
            "export.csv.client", "export.csv.service", "export.csv.date", "export.csv.time", "export.csv.duration",
            "export.csv.status", "export.csv.origin", "export.csv.note"
        ].map(text), rows: rows)
    }

    func recordsTable(_ snapshot: ExportSnapshot) -> CSVTable {
        let names = clientNames(snapshot)
        let rows = snapshot.records.sorted { $0.createdAt < $1.createdAt }.map { record -> [String] in
            [
                names[record.clientID] ?? "",
                formatters.shortDate(record.createdAt),
                record.serviceName,
                record.technique ?? "",
                record.productsUsed.joined(separator: "; "),
                record.resultDetail ?? "",
                record.aftercare ?? "",
                record.notes ?? "",
                record.nextSessionSuggestion ?? ""
            ]
        }
        return CSVTable(header: [
            "export.csv.client", "export.csv.date", "export.csv.service", "export.csv.technique", "export.csv.products",
            "export.csv.result", "export.csv.aftercare", "export.csv.notes", "export.csv.nextSession"
        ].map(text), rows: rows)
    }

    // MARK: - Summary (what the PDF prints)

    struct Summary: Equatable, Sendable {
        let title: String
        let lines: [String]
    }

    func summary(_ snapshot: ExportSnapshot) -> Summary {
        let name = snapshot.profile?.publicName ?? ""
        return Summary(
            title: text("export.pdf.title"),
            lines: [
                String(localized: LocalizedStringResource(
                    "export.pdf.business", defaultValue: "Business: \(name)"
                ).localized(in: locale)),
                String(localized: LocalizedStringResource(
                    "export.pdf.exportedOn", defaultValue: "Exported on \(formatters.dateTime(now))"
                ).localized(in: locale)),
                String(localized: LocalizedStringResource(
                    "export.pdf.counts",
                    defaultValue: """
                    \(snapshot.clients.count) clients, \(snapshot.appointments.count) appointments, \
                    \(snapshot.records.count) records
                    """
                ).localized(in: locale)),
                text("export.pdf.privacy")
            ]
        )
    }

    // MARK: - Entries

    /// The archive's files, the PDF given by the caller (rendering is IO). Photos go under `photos/<client>/`.
    func entries(_ snapshot: ExportSnapshot, pdf: Data, contents: ExportContents) -> [ExportEntry] {
        var entries = [
            ExportEntry(name: "clients.csv", data: clientsTable(snapshot).data),
            ExportEntry(name: "appointments.csv", data: appointmentsTable(snapshot).data),
            ExportEntry(name: "records.csv", data: recordsTable(snapshot).data),
            ExportEntry(name: "summary.pdf", data: pdf)
        ]
        if contents.includesPhotos {
            let names = clientNames(snapshot)
            for (photo, data) in snapshot.photos {
                let folder = Self.fileSafe(names[photo.clientID] ?? photo.clientID.uuidString)
                let stamp = ISO8601DateFormatter().string(from: photo.takenAt).replacingOccurrences(of: ":", with: "-")
                entries.append(ExportEntry(
                    name: "photos/\(folder)/\(stamp)-\(photo.kind.rawValue).jpg", data: data.image
                ))
            }
        }
        return entries
    }

    /// `bellohub-export-2026-10-09.zip`.
    func archiveName() -> String {
        let day = now.formatted(Date.ISO8601FormatStyle(timeZone: formatters.timeZone).year().month().day())
        return "bellohub-export-\(day).zip"
    }

    // MARK: - Helpers

    private func clientNames(_ snapshot: ExportSnapshot) -> [UUID: String] {
        Dictionary(uniqueKeysWithValues: snapshot.clients.map { ($0.id, $0.name) })
    }

    private func text(_ key: String.LocalizationValue) -> String {
        String(localized: key, locale: locale)
    }

    /// `1990-05-14` or `--05-14` when the year is unknown: ISO, so another app can read it back.
    static func birthdayText(_ birthday: Birthday) -> String {
        let monthDay = String(format: "%02d-%02d", birthday.month, birthday.day)
        return birthday.year.map { "\($0)-\(monthDay)" } ?? "--\(monthDay)"
    }

    private static func byName(_ lhs: Client, _ rhs: Client) -> Bool {
        lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    /// A folder name from a client name: letters, digits, spaces and dashes only.
    static func fileSafe(_ name: String) -> String {
        let allowed = name.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == " " || $0 == "-" }
        let cleaned = String(String.UnicodeScalarView(allowed)).trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "client" : cleaned
    }
}
