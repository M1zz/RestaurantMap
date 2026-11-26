//
//  PlaceFinder.swift
//  인생 맛집 · 공유 확장
//
//  공유로 받은 링크의 글을 읽고(제목 · 소개글), 가게 이름일 만한 말로 지도에서 식당을 찾는다.
//  한국 안은 카카오 로컬이 작은 가게까지 잘 찾고, 그 밖은 Apple 지도가 찾는다.
//

import Foundation
import MapKit

/// 고를 수 있는 식당 하나.
struct PlaceCandidate: Identifiable, Equatable {
    let id: String
    let name: String
    let address: String
    let phone: String
    let category: String
    let categoryHints: [String]
    let latitude: Double
    let longitude: Double
    /// 음식점 · 카페로 분류된 곳인가 — 그런 곳을 앞에 둔다
    let isFood: Bool

    func shared(link: String) -> SharedPlace {
        SharedPlace(name: name, address: address, phone: phone, category: category, categoryHints: categoryHints,
                    latitude: latitude, longitude: longitude, link: link)
    }
}

enum PlaceFinder {

    // MARK: - 링크의 글 읽기

    /// 링크 페이지의 제목과 소개글(og:title · og:description). 못 읽으면 빈 배열.
    static func pageTexts(of url: URL) async -> [String] {
        var request = URLRequest(url: readable(url), timeoutInterval: 8)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
                         forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return [] }
        // 머리(head)만 보면 된다
        let html = String(decoding: data.prefix(600_000), as: UTF8.self)
        let keys = ["og:title", "og:description", "twitter:title", "twitter:description", "description"]
        var texts = keys.compactMap { meta($0, in: html) }
        if texts.isEmpty, let title = firstMatch(#"<title[^>]*>([^<]+)</title>"#, in: html) { texts.append(decode(title)) }
        var seen = Set<String>()
        return texts.filter { seen.insert($0).inserted }
    }

    /// 네이버 블로그 PC 주소는 글을 틀(frame) 안에 둬서 머리에 소개글이 없다 — 모바일 주소로 읽는다.
    private static func readable(_ url: URL) -> URL {
        guard url.host() == "blog.naver.com",
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        components.host = "m.blog.naver.com"
        return components.url ?? url
    }

    private static func meta(_ name: String, in html: String) -> String? {
        let n = NSRegularExpression.escapedPattern(for: name)
        // property="og:title" content="…" 와 content 가 먼저 오는 꼴 둘 다
        let patterns = [#"<meta[^>]+(?:property|name)=["']\#(n)["'][^>]*content=["']([^"']*)["']"#,
                        #"<meta[^>]+content=["']([^"']*)["'][^>]*(?:property|name)=["']\#(n)["']"#]
        for pattern in patterns {
            if let value = firstMatch(pattern, in: html), !value.isEmpty { return decode(value) }
        }
        return nil
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    /// &quot; · &#39; · &#x1F4CD; 같은 HTML 글자를 원래 글자로.
    private static func decode(_ text: String) -> String {
        var result = text
        for (entity, char) in ["&quot;": "\"", "&#39;": "'", "&apos;": "'", "&lt;": "<", "&gt;": ">", "&nbsp;": " "] {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        if let regex = try? NSRegularExpression(pattern: #"&#(x?)([0-9a-fA-F]+);"#) {
            for match in regex.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed() {
                guard let whole = Range(match.range, in: result),
                      let hexMark = Range(match.range(at: 1), in: result),
                      let digits = Range(match.range(at: 2), in: result),
                      let value = UInt32(result[digits], radix: result[hexMark].isEmpty ? 10 : 16),
                      let scalar = Unicode.Scalar(value) else { continue }
                result.replaceSubrange(whole, with: String(Character(scalar)))
            }
        }
        return result.replacingOccurrences(of: "&amp;", with: "&")
    }

    // MARK: - 식당 찾기

    /// 글에서 고른 말로 찾는다. 밝힌 이름(sure)은 찾은 곳을 앞에서 몇 곳, 낱말(words)은 이름이 맞는 음식점 · 카페만.
    /// 검색은 한꺼번에 보내고, 차례는 글에 나온 차례를 지킨다.
    static func search(_ guess: PlaceGuess) async -> [PlaceCandidate] {
        let queries = guess.sure + guess.words
        let results = await withTaskGroup(of: (Int, [PlaceCandidate]).self) { group in
            for (index, query) in queries.enumerated() {
                group.addTask { (index, await places(query)) }
            }
            var byIndex: [Int: [PlaceCandidate]] = [:]
            for await (index, found) in group { byIndex[index] = found }
            return queries.indices.map { byIndex[$0] ?? [] }
        }
        var sure: [PlaceCandidate] = []
        var matched: [(place: PlaceCandidate, length: Int)] = []
        for (index, places) in results.enumerated() {
            if index < guess.sure.count {
                let food = places.filter(\.isFood)
                sure += (food.isEmpty ? places : food).prefix(3)
            } else {
                let length = PlaceGuess.key(queries[index]).count
                matched += places.filter { $0.isFood && named($0.name, like: queries[index]) }.prefix(2).map { ($0, length) }
            }
        }
        // 긴 말이 맞은 곳일수록 그 가게일 가능성이 크다 — '성수차이나' 가 '탕수육' 이라는 이름의 가게보다 앞에 (같으면 글의 차례)
        let ranked = matched.enumerated().sorted { ($0.element.length, -$0.offset) > ($1.element.length, -$1.offset) }.map(\.element.place)
        return Array(unique(sure + ranked).prefix(6))
    }

    /// 손으로 친 이름으로 찾는다. 음식점 · 카페를 앞에.
    static func search(typed query: String) async -> [PlaceCandidate] {
        let places = await places(query)
        return unique(places.filter(\.isFood) + places.filter { !$0.isFood })
    }

    /// '타코마이너' 와 '타코마이너 성수점' 은 같은 가게다. '성수' 와 '성수족발' 은 아니다 — 두 글자 말은 똑같아야 맞다.
    static func named(_ name: String, like word: String) -> Bool {
        let n = PlaceGuess.key(name), w = PlaceGuess.key(word)
        guard !n.isEmpty, !w.isEmpty else { return false }
        return n == w || (w.count >= 3 && n.hasPrefix(w)) || (n.count >= 3 && w.hasPrefix(n))
    }

    private static func places(_ query: String) async -> [PlaceCandidate] {
        let found = await kakao(query)
        return found.isEmpty ? await appleMaps(query) : found
    }

    private static func unique(_ places: [PlaceCandidate]) -> [PlaceCandidate] {
        var seen = Set<String>()
        return places.filter { seen.insert("\($0.name)|\(Int($0.latitude * 2000))|\(Int($0.longitude * 2000))").inserted }
    }

    /// 카카오 로컬 키워드 검색. 키가 없거나 실패하면 빈 배열 (→ Apple 지도로).
    private static func kakao(_ query: String) async -> [PlaceCandidate] {
        let key = Bundle.main.object(forInfoDictionaryKey: "KAKAO_REST_API_KEY") as? String ?? ""
        guard !key.isEmpty,
              var components = URLComponents(string: "https://dapi.kakao.com/v2/local/search/keyword.json") else { return [] }
        components.queryItems = [.init(name: "query", value: query), .init(name: "size", value: "10")]
        guard let url = components.url else { return [] }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("KakaoAK \(key)", forHTTPHeaderField: "Authorization")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let body = try? JSONDecoder().decode(KakaoBody.self, from: data) else { return [] }
        return body.documents.compactMap { place in
            guard let lat = Double(place.y), let lon = Double(place.x) else { return nil }
            return PlaceCandidate(
                id: "kakao-\(place.id)",
                name: place.place_name,
                address: place.road_address_name.isEmpty ? place.address_name : place.road_address_name,
                phone: place.phone,
                category: place.category_group_name,
                categoryHints: [place.category_name, place.place_name],
                latitude: lat, longitude: lon,
                isFood: ["FD6", "CE7"].contains(place.category_group_code)
            )
        }
    }

    private struct KakaoBody: Decodable {
        struct Place: Decodable {
            let id, place_name, category_name, category_group_code, category_group_name: String
            let phone, address_name, road_address_name, x, y: String
        }
        let documents: [Place]
    }

    private static let foodCategories: Set<MKPointOfInterestCategory> = [.restaurant, .cafe, .bakery, .brewery, .winery, .nightlife, .foodMarket]

    private static func appleMaps(_ query: String) async -> [PlaceCandidate] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest
        guard let items = try? await MKLocalSearch(request: request).start().mapItems else { return [] }
        return items.prefix(10).map { item in
            let mark = item.placemark
            let coordinate = mark.coordinate
            let poi = item.pointOfInterestCategory
            return PlaceCandidate(
                id: "apple-\(coordinate.latitude),\(coordinate.longitude)-\(item.name ?? "")",
                name: item.name ?? query,
                address: [mark.thoroughfare, mark.subThoroughfare, mark.locality].compactMap { $0 }.joined(separator: " ").nonEmpty
                    ?? mark.title ?? "",
                phone: item.phoneNumber ?? "",
                category: poi?.rawValue ?? "",
                categoryHints: [poi?.rawValue ?? "", item.name ?? ""],
                latitude: coordinate.latitude, longitude: coordinate.longitude,
                isFood: poi.map(foodCategories.contains) ?? false
            )
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
