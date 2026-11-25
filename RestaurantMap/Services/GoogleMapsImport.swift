//
//  GoogleMapsImport.swift
//  인생 맛집
//
//  구글 데이터 내보내기(Takeout) 파일에서 저장한 장소를 읽는다. 구글 계정에 로그인하지 않고, 파일은 기기 안에서만 읽는다.
//
//   · 별표한 장소 · 후기 남긴 곳 — GeoJSON(.json). 이름 · 주소 · 좌표가 들어 있다.
//   · 저장 목록(가고 싶은 곳 등) — 목록 하나가 CSV 한 장. 이름 · 링크뿐이라 좌표는 이름으로 지도에서 찾는다.
//
//  내보내기 폴더 · 파일 이름은 구글 계정 언어로 바뀌므로 이름이 아니라 **내용**으로 알아본다.
//  집 · 회사 같은 라벨 장소는 구글 지도 링크가 없어 저절로 빠진다.
//

import Foundation
import MapKit
import Compression

/// 파일에서 읽은 장소 하나. 저장하기 전 확인 화면에 한 줄로 보인다.
struct ImportedPlace: Identifiable {
    let id = UUID()
    var name: String
    var address: String
    var coordinate: CLLocationCoordinate2D?
    var note: String
    /// 구글에 남긴 별점(1~5). 후기를 남긴 곳만 있다.
    var rating = 0
    var date: Date?
}

/// 같은 파일에서 나온 장소 묶음 — 구글의 목록 하나.
struct ImportedList: Identifiable {
    let id = UUID()
    var name: String
    var places: [ImportedPlace]
    /// 다녀온 곳으로 넣을지. 후기를 남긴 곳만 처음부터 다녀온 곳이다.
    var visited: Bool
}

enum GoogleMapsImport {

    enum Failure: LocalizedError {
        case tooLarge, nothingFound
        var errorDescription: String? {
            switch self {
            case .tooLarge:
                String(localized: "파일이 너무 커요. 구글 데이터 내보내기에서 지도 항목만 골라 다시 내보내 주세요.")
            case .nothingFound:
                String(localized: "이 파일에서 구글 지도에 저장한 장소를 찾지 못했어요.")
            }
        }
    }

    /// 지도만 고른 내보내기는 몇 MB 다. 모든 항목을 고른 수 GB 파일을 통째로 메모리에 올리지 않는다.
    private static let maxFileSize = 200 * 1024 * 1024

    /// 고른 파일들(zip · json · csv)에서 목록을 읽는다.
    static func read(_ urls: [URL]) throws -> [ImportedList] {
        var lists: [ImportedList] = []
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            guard size <= maxFileSize else { throw Failure.tooLarge }
            let data = try Data(contentsOf: url)
            if url.pathExtension.lowercased() == "zip" {
                for entry in ZipReader.entries(in: data, where: isCandidate) {
                    lists += parse(entry.data, fileName: entry.name)
                }
            } else {
                lists += parse(data, fileName: url.lastPathComponent)
            }
        }
        lists = lists.filter { !$0.places.isEmpty }
        guard !lists.isEmpty else { throw Failure.nothingFound }
        return lists
    }

    private static func isCandidate(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        return ext == "json" || ext == "csv"
    }

    private static func parse(_ data: Data, fileName: String) -> [ImportedList] {
        switch (fileName as NSString).pathExtension.lowercased() {
        case "json": places(fromGeoJSON: data).map { [$0] } ?? []
        case "csv":  places(fromCSV: data, listName: ((fileName as NSString).lastPathComponent as NSString).deletingPathExtension).map { [$0] } ?? []
        default: []
        }
    }

    // MARK: - 별표한 장소 · 후기 (GeoJSON)

    /// 예전 형식(`Title` · `Location`)과 지금 형식(`location` · `google_maps_url`)을 함께 읽는다.
    static func places(fromGeoJSON data: Data) -> ImportedList? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = root["features"] as? [[String: Any]] else { return nil }
        var reviewed = false
        let places: [ImportedPlace] = features.compactMap { feature in
            let props = feature["properties"] as? [String: Any] ?? [:]
            let link = text(props["google_maps_url"], props["Google Maps URL"])
            guard !link.isEmpty else { return nil }    // 집 · 회사 같은 라벨 장소
            let location = (props["location"] ?? props["Location"]) as? [String: Any] ?? [:]
            let address = text(location["address"], location["Address"])
            let name = text(location["name"], location["Business Name"], props["Title"]).nonEmpty ?? address
            guard !name.isEmpty else { return nil }

            var coordinate: CLLocationCoordinate2D?
            if let point = (feature["geometry"] as? [String: Any])?["coordinates"] as? [Double], point.count >= 2,
               point[0] != 0 || point[1] != 0 {
                coordinate = CLLocationCoordinate2D(latitude: point[1], longitude: point[0])
            } else if let geo = location["Geo Coordinates"] as? [String: Any],
                      let lat = number(geo["Latitude"]), let lng = number(geo["Longitude"]), lat != 0 || lng != 0 {
                coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            }
            // 파일에 적힌 좌표가 범위 밖이면(깨진 파일 · 순서가 뒤바뀐 값) 없는 것으로 친다 — 링크나 이름으로 다시 찾는다.
            // 그대로 저장하면 그 식당을 지도에 그릴 때 죽는다.
            if let found = coordinate, !found.isMappable { coordinate = nil }

            var place = ImportedPlace(name: name, address: address, coordinate: coordinate ?? Self.coordinate(in: link),
                                      note: text(props["review_text_published"], props["Comment"], props["comment"]))
            // 유한한 값만, 먼저 0~5 로 자른 뒤 Int 로 — NaN 이나 아주 큰 수를 Int 로 바꾸면 죽는다
            if let stars = number(props["five_star_rating_published"]), stars.isFinite {
                reviewed = true
                place.rating = Int(min(5, max(0, stars)))
            }
            place.date = (props["date"] as? String).flatMap { try? Date($0, strategy: .iso8601) }
            return place
        }
        return ImportedList(name: reviewed ? String(localized: "구글 지도에 후기를 남긴 곳")
                                           : String(localized: "구글 지도에서 별표한 곳"),
                            places: places, visited: reviewed)
    }

    // MARK: - 저장 목록 (CSV)

    /// 목록 하나 = CSV 한 장. 머리줄은 `Title,Note,URL,Tags,Comment`. 링크 칸이 구글 지도가 아니면 목록이 아니다.
    static func places(fromCSV data: Data, listName: String) -> ImportedList? {
        let rows = CSV.rows(String(decoding: data, as: UTF8.self).trimmingCharacters(in: ["\u{FEFF}"]))
            .filter { $0.contains { !$0.isEmpty } }
        guard let header = rows.first?.map({ $0.lowercased() }), rows.count > 1 else { return nil }
        let body = rows.dropFirst()
        guard let urlColumn = header.indices.first(where: { column in
            body.contains { column < $0.count && isGoogleMapsLink($0[column]) }
        }) else { return nil }
        let titleColumn = header.firstIndex(of: "title") ?? 0
        let noteColumns = header.indices.filter { ["note", "comment"].contains(header[$0]) }

        let places: [ImportedPlace] = body.compactMap { row in
            func cell(_ i: Int) -> String { i < row.count ? row[i].trimmingCharacters(in: .whitespacesAndNewlines) : "" }
            let link = cell(urlColumn)
            guard let name = cell(titleColumn).nonEmpty ?? nameInLink(link) else { return nil }
            return ImportedPlace(name: name, address: "", coordinate: coordinate(in: link),
                                 note: noteColumns.map(cell).filter { !$0.isEmpty }.joined(separator: "\n"))
        }
        return ImportedList(name: listName, places: places, visited: false)
    }

    // MARK: - 링크

    private static func isGoogleMapsLink(_ s: String) -> Bool {
        s.contains("google.") && s.contains("maps") || s.contains("goo.gl/maps") || s.contains("maps.app.goo.gl")
    }

    /// 링크에 든 좌표 — `!3d위도!4d경도`, `@위도,경도`, `?q=위도,경도` 순으로 본다.
    static func coordinate(in link: String) -> CLLocationCoordinate2D? {
        let patterns = [#"!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)"#, #"@(-?\d+\.\d+),(-?\d+\.\d+)"#, #"[?&](?:q|ll|query)=(-?\d+\.\d+),(-?\d+\.\d+)"#]
        for pattern in patterns {
            guard let match = link.range(of: pattern, options: .regularExpression) else { continue }
            let numbers = link[match].matches(of: #/-?\d+\.\d+/#).compactMap { Double($0.output) }
            if numbers.count == 2, abs(numbers[0]) <= 90, abs(numbers[1]) <= 180 {
                return CLLocationCoordinate2D(latitude: numbers[0], longitude: numbers[1])
            }
        }
        return nil
    }

    /// `/maps/place/가게+이름/...` 의 이름.
    private static func nameInLink(_ link: String) -> String? {
        guard let range = link.range(of: "/place/") else { return nil }
        let part = link[range.upperBound...].split(separator: "/").first.map(String.init) ?? ""
        return part.replacingOccurrences(of: "+", with: " ").removingPercentEncoding?.nonEmpty
    }

    // MARK: - 위치 찾기

    /// 좌표 없는 장소를 이름으로 지도에서 찾는다. 다른 장소들이 모인 곳을 먼저 본다.
    /// 지도 검색은 짧은 시간에 너무 많이 부르면 잠시 막히므로 하나씩, 막히면 쉬었다 다시 부른다.
    @MainActor
    static func locate(_ lists: inout [ImportedList], progress: (Int, Int) -> Void) async {
        let known = lists.flatMap(\.places).compactMap(\.coordinate)
        let region: MKCoordinateRegion? = known.isEmpty ? nil : {
            let lat = known.map(\.latitude).reduce(0, +) / Double(known.count)
            let lng = known.map(\.longitude).reduce(0, +) / Double(known.count)
            return MKCoordinateRegion(center: .init(latitude: lat, longitude: lng),
                                      latitudinalMeters: 300_000, longitudinalMeters: 300_000)
        }()
        let missing = lists.indices.flatMap { l in lists[l].places.indices.compactMap { p in
            lists[l].places[p].coordinate == nil || lists[l].places[p].address.isEmpty ? (l, p) : nil } }
        for (done, (l, p)) in missing.enumerated() {
            progress(done, missing.count)
            guard !Task.isCancelled else { return }
            let place = lists[l].places[p]
            guard let item = await search(place, near: place.coordinate.map {
                MKCoordinateRegion(center: $0, latitudinalMeters: 500, longitudinalMeters: 500) } ?? region) else { continue }
            if place.coordinate == nil, item.placemark.coordinate.isMappable { lists[l].places[p].coordinate = item.placemark.coordinate }
            if place.address.isEmpty { lists[l].places[p].address = item.placemark.title ?? "" }
        }
        progress(missing.count, missing.count)
    }

    private static func search(_ place: ImportedPlace, near region: MKCoordinateRegion?) async -> MKMapItem? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = [place.name, place.address].filter { !$0.isEmpty }.joined(separator: " ")
        request.resultTypes = [.pointOfInterest, .address]
        if let region { request.region = region }
        for attempt in 0..<3 {
            do {
                return try await MKLocalSearch(request: request).start().mapItems.first
            } catch let error as MKError where error.code == .loadingThrottled {
                try? await Task.sleep(for: .seconds(2 << attempt))
            } catch {
                return nil
            }
        }
        return nil
    }

    // MARK: - 값 꺼내기

    private static func text(_ values: Any?...) -> String {
        values.lazy.compactMap { ($0 as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty } ?? ""
    }

    private static func number(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue ?? (value as? String).flatMap(Double.init)
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

// MARK: - CSV

/// 따옴표 · 칸 안 줄바꿈을 지키는 CSV 읽개.
enum CSV {
    static func rows(_ text: String) -> [[String]] {
        var rows: [[String]] = [], row: [String] = [], field = ""
        var quoted = false
        var chars = text.makeIterator()
        while let c = chars.next() {
            if quoted {
                if c == "\"" {
                    if let next = chars.next() {
                        if next == "\"" { field.append("\"") } else { quoted = false; handle(next) }
                    } else { quoted = false }
                } else { field.append(c) }
            } else { handle(c) }
        }
        func handle(_ c: Character) {
            switch c {
            case "\"": quoted = true
            case ",": row.append(field); field = ""
            case "\n", "\r\n", "\r": row.append(field); rows.append(row); row = []; field = ""
            default: field.append(c)
            }
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows
    }
}

// MARK: - zip

/// 구글 내보내기 zip 에서 필요한 파일만 꺼내는 작은 읽개. 외부 패키지를 들이지 않으려고 직접 읽는다.
/// 저장(0) · deflate(8) 만 읽는다 — 구글 내보내기는 이 둘뿐이다.
enum ZipReader {
    struct Entry { let name: String; let data: Data }
    private static let maxEntrySize = 64 * 1024 * 1024

    static func entries(in data: Data, where keep: (String) -> Bool) -> [Entry] {
        let bytes = [UInt8](data)
        func u16(_ i: Int) -> Int { Int(bytes[i]) | Int(bytes[i + 1]) << 8 }
        func u32(_ i: Int) -> Int { u16(i) | u16(i + 2) << 16 }
        guard bytes.count >= 22 else { return [] }

        // 끝에서부터 중앙 목록의 끝 표시(PK 05 06)를 찾는다.
        var end = bytes.count - 22
        let lowest = max(0, end - 65_535)
        while end >= lowest, u32(end) != 0x0605_4b50 { end -= 1 }
        guard end >= lowest else { return [] }

        var p = u32(end + 16)
        var result: [Entry] = []
        for _ in 0..<u16(end + 10) {
            guard p + 46 <= bytes.count, u32(p) == 0x0201_4b50 else { break }
            let method = u16(p + 10), packed = u32(p + 20), size = u32(p + 24)
            // 풀었을 때 너무 큰 파일(위치 기록처럼 수백 MB~GB 인 JSON)은 건너뛴다 — 통째로 메모리에 올리다 꺼진다.
            // 저장한 장소 파일은 몇 MB 를 넘지 않는다.
            let tooBig = size > maxEntrySize
            let nameLength = u16(p + 28), local = u32(p + 42)
            guard p + 46 + nameLength <= bytes.count else { break }
            let name = String(decoding: bytes[(p + 46)..<(p + 46 + nameLength)], as: UTF8.self)
            p += 46 + nameLength + u16(p + 30) + u16(p + 32)

            guard keep(name), !tooBig, local + 30 <= bytes.count, u32(local) == 0x0403_4b50 else { continue }
            let start = local + 30 + u16(local + 26) + u16(local + 28)
            guard start + packed <= bytes.count else { continue }
            let raw = Array(bytes[start..<(start + packed)])
            switch method {
            case 0: result.append(Entry(name: name, data: Data(raw)))
            case 8: if let out = inflate(raw, size: size) { result.append(Entry(name: name, data: out)) }
            default: continue
            }
        }
        return result
    }

    /// zip 의 deflate 는 머리 없는 날 deflate 다 — Compression 의 ZLIB 가 바로 그것을 푼다.
    private static func inflate(_ input: [UInt8], size: Int) -> Data? {
        guard size > 0, !input.isEmpty else { return Data() }
        var output = [UInt8](repeating: 0, count: size)
        let written = input.withUnsafeBufferPointer { src in
            output.withUnsafeMutableBufferPointer { dst in
                compression_decode_buffer(dst.baseAddress!, size, src.baseAddress!, input.count, nil, COMPRESSION_ZLIB)
            }
        }
        return written == size ? Data(output) : nil
    }
}
