//
//  ZipWriter.swift
//  BelloHub
//

import Foundation
import zlib

/// Writes a ZIP archive with the "store" method (no compression) and CRC-32 from zlib: a few CSV files and a PDF do
/// not need more, and Files, Numbers and Excel open it. Pure over bytes, so the archive is tested without a disk.
/// Entry names are UTF-8 (flag bit 11); dates are stamped from the `now` the caller passes.
struct ZipWriter: Sendable {
    let now: Date

    func archive(_ entries: [ExportEntry]) -> Data {
        var body = Data()
        var central = Data()
        let (time, date) = dosTimestamp(now)
        for entry in entries {
            let header = Header(
                name: Data(entry.name.utf8), crc: Self.crc32(entry.data), size: UInt32(entry.data.count),
                time: time, date: date
            )
            let offset = UInt32(body.count)
            body.append(Self.localHeader(header))
            body.append(entry.data)
            central.append(Self.centralHeader(header, offset: offset))
        }
        var archive = body
        archive.append(central)
        archive.append(Self.endRecord(
            count: UInt16(entries.count), centralSize: UInt32(central.count), centralOffset: UInt32(body.count)
        ))
        return archive
    }

    // MARK: - Records

    private struct Header {
        let name: Data
        let crc: UInt32
        let size: UInt32
        let time: UInt16
        let date: UInt16
    }

    private static func localHeader(_ header: Header) -> Data {
        let (name, crc, size, time, date) = (header.name, header.crc, header.size, header.time, header.date)
        var data = Data()
        data.append(le32(0x0403_4B50))
        data.append(le16(20))          // version needed
        data.append(le16(0x0800))      // flags: UTF-8 names
        data.append(le16(0))           // method: store
        data.append(le16(time))
        data.append(le16(date))
        data.append(le32(crc))
        data.append(le32(size))
        data.append(le32(size))
        data.append(le16(UInt16(name.count)))
        data.append(le16(0))           // extra length
        data.append(name)
        return data
    }

    private static func centralHeader(_ header: Header, offset: UInt32) -> Data {
        let (name, crc, size, time, date) = (header.name, header.crc, header.size, header.time, header.date)
        var data = Data()
        data.append(le32(0x0201_4B50))
        data.append(le16(20))          // version made by
        data.append(le16(20))          // version needed
        data.append(le16(0x0800))
        data.append(le16(0))
        data.append(le16(time))
        data.append(le16(date))
        data.append(le32(crc))
        data.append(le32(size))
        data.append(le32(size))
        data.append(le16(UInt16(name.count)))
        data.append(le16(0))           // extra
        data.append(le16(0))           // comment
        data.append(le16(0))           // disk
        data.append(le16(0))           // internal attributes
        data.append(le32(0))           // external attributes
        data.append(le32(offset))
        data.append(name)
        return data
    }

    private static func endRecord(count: UInt16, centralSize: UInt32, centralOffset: UInt32) -> Data {
        var data = Data()
        data.append(le32(0x0605_4B50))
        data.append(le16(0))
        data.append(le16(0))
        data.append(le16(count))
        data.append(le16(count))
        data.append(le32(centralSize))
        data.append(le32(centralOffset))
        data.append(le16(0))
        return data
    }

    // MARK: - Helpers

    static func crc32(_ data: Data) -> UInt32 {
        data.withUnsafeBytes { buffer in
            UInt32(zlib.crc32(0, buffer.bindMemory(to: Bytef.self).baseAddress, uInt(buffer.count)))
        }
    }

    private func dosTimestamp(_ date: Date) -> (time: UInt16, date: UInt16) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = max((parts.year ?? 1980) - 1980, 0)
        let time = UInt16(((parts.hour ?? 0) << 11) | ((parts.minute ?? 0) << 5) | ((parts.second ?? 0) / 2))
        let day = UInt16((year << 9) | ((parts.month ?? 1) << 5) | (parts.day ?? 1))
        return (time, day)
    }

    private static func le16(_ value: UInt16) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }

    private static func le32(_ value: UInt32) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }
}
