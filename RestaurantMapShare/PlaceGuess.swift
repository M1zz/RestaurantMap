//
//  PlaceGuess.swift
//  인생 맛집 · 공유 확장
//
//  공유로 들어온 글(게시물 본문 · 블로그 제목과 소개글 · 지도 앱이 붙인 글)에서 가게 이름일 만한 말을 고른다.
//  맞히는 것은 지도 검색이 한다 (→ PlaceFinder) — 여기서는 검색어를 두 갈래로 내놓을 뿐이다.
//   · sure  — 글이 가게라고 밝힌 이름 (📍 · '상호:' · 지도 앱의 공유 글). 찾은 곳을 그대로 보인다.
//   · words — 글 앞머리 낱말 · 해시태그. 이름이 그 낱말과 맞는 음식점 · 카페만 남긴다.
//     블로그 제목은 '성수 맛집' 처럼 뭉뚱그린 말이 많고, 가게 이름은 대개 소개글 맨 앞에 온다.
//

import Foundation

struct PlaceGuess: Equatable {
    var sure: [String] = []
    var words: [String] = []

    var isEmpty: Bool { sure.isEmpty && words.isEmpty }
    /// 손으로 찾을 때 검색칸에 미리 넣어 둘 말
    var firstQuery: String? { sure.first ?? words.first }

    init(sure: [String] = [], words: [String] = []) {
        self.sure = sure
        self.words = words
    }

    init(from texts: [String], wordLimit: Int = 10) {
        let texts = texts.map(Self.caption).filter { !Self.isSiteName($0) }
        var words: [String] = []
        for text in texts {
            let lines = text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            for (index, line) in lines.enumerated() {
                // 📍성수 OO식당 · 📌 OO / 상호: OO / 가게명 - OO
                if let marked = Self.afterMarker(line) {
                    sure.append(marked)
                    continue
                }
                // [네이버 지도] 다음 줄 · [카카오맵] OO 은 그 자체가 가게 이름이다
                if line.contains("네이버 지도") || line.contains("네이버지도") || line.contains("[카카오맵]") {
                    let rest = line.replacingOccurrences(of: #"\[[^\]]*\]"#, with: "", options: .regularExpression)
                    if let name = Self.clean(rest) { sure.append(name) }
                    else if index + 1 < lines.count, let name = Self.clean(lines[index + 1]) { sure.append(name) }
                }
            }
            words += Self.hashtags(in: text)
        }
        // 글마다 앞머리 낱말을 번갈아 — 제목 첫 낱말, 소개글 첫 낱말, 제목 둘째 낱말 …
        let leads = texts.map(Self.leadWords)
        for i in 0..<(leads.map(\.count).max() ?? 0) {
            for lead in leads where i < lead.count { words.append(lead[i]) }
        }

        var seen = Set<String>()
        sure = sure.filter { seen.insert(Self.key($0)).inserted }
        self.words = words.filter { seen.insert(Self.key($0)).inserted }.prefix(wordLimit).map { $0 }
    }

    /// 이름을 견줄 때 쓰는 꼴 — 띄어쓰기 · 기호 없이, 소문자로.
    static func key(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    // MARK: - 줄 읽기

    private static let markers = ["📍", "📌", "🏠", "🍽"]
    private static let labels = ["상호명", "상호", "가게명", "가게 이름", "가게", "식당", "매장명", "place", "restaurant", "店名", "店铺", "餐厅", "お店"]

    private static func afterMarker(_ line: String) -> String? {
        for marker in markers where line.hasPrefix(marker) {
            return clean(String(line.dropFirst(marker.count)))
        }
        let lower = line.lowercased()
        for label in labels where lower.hasPrefix(label.lowercased()) {
            let rest = line.dropFirst(label.count).trimmingCharacters(in: .whitespaces)
            // '상호: OO' · '상호 - OO' 처럼 이어 주는 기호가 있어야 한다 — '식당 분위기가…' 같은 문장은 아니다
            guard let first = rest.first, ":：-|)".contains(first) else { continue }
            return clean(String(rest.dropFirst()))
        }
        return nil
    }

    /// 가게 이름이 아닌 흔한 말. 낱말 · 해시태그에서 뺀다.
    private static let generic = ["맛집", "먹스타", "카페", "추천", "데이트", "맛스타", "존맛", "jmt", "food", "foodie", "yummy", "instafood",
                                  "맛있", "점심", "저녁", "브런치", "술집", "디저트", "일상", "소통", "팔로우", "좋아요", "협찬", "광고",
                                  "내돈내산", "후기", "리뷰", "솔직", "방문", "웨이팅", "메뉴", "가격", "주차", "정보", "reels", "릴스"]

    private static func isGeneric(_ word: String) -> Bool {
        let lower = word.lowercased()
        return generic.contains { lower.contains($0) }
    }

    /// #성수맛집 · #먹스타그램 같은 흔한 꼬리표는 빼고, 가게 이름일 만한 것만.
    private static func hashtags(in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"#([^\s#]+)"#) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let r = Range(match.range(at: 1), in: text) else { return nil }
            let tag = String(text[r])
            return isGeneric(tag) ? nil : clean(tag)
        }
    }

    /// 글 맨 앞 몇 낱말과, 이웃한 두 낱말 (이름이 두 낱말인 가게 — '쿠촐로 테라짜').
    private static func leadWords(_ text: String) -> [String] {
        let head = text.replacingOccurrences(of: #"\[[^\]]*\]|\([^)]*\)|【[^】]*】|#\S+|https?://\S+"#, with: " ", options: .regularExpression)
        let tokens = head.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters).union(.symbols))
            .map(stripParticle)
            .filter { $0.count >= 2 && !isGeneric($0) && !$0.allSatisfy(\.isNumber) }
            .prefix(4)
        var words: [String] = []
        for (i, token) in tokens.enumerated() {
            words.append(token)
            if i + 1 < tokens.count { words.append("\(token) \(tokens[tokens.index(tokens.startIndex, offsetBy: i + 1)])") }
        }
        return words
    }

    /// '타코마이너에서' → '타코마이너'. 한 글자짜리 조사는 이름 끝 글자와 헷갈려 떼지 않는다.
    private static func stripParticle(_ word: String) -> String {
        for particle in ["에서", "으로", "에게", "까지", "부터", "이랑", "이에요", "입니다"] where word.hasSuffix(particle) && word.count > particle.count + 1 {
            return String(word.dropLast(particle.count))
        }
        return word
    }

    /// 인스타가 붙이는 머리('OO on Instagram: "…"' · '좋아요 12개, 댓글 3개 - OO: "…"')를 걷고 본문만.
    private static func caption(_ text: String) -> String {
        guard let open = text.range(of: ": \""), text.hasSuffix("\""),
              text[..<open.lowerBound].count < 120 else { return text }
        return String(text[open.upperBound..<text.index(before: text.endIndex)])
    }

    /// 글을 못 읽어 사이트 이름 · 사이트 소개만 왔으면 찾을 게 없다.
    private static func isSiteName(_ text: String) -> Bool {
        let lower = text.lowercased().trimmingCharacters(in: .whitespaces)
        return ["instagram", "youtube", "naver blog", "네이버 블로그", "tiktok", "threads", "facebook"].contains(lower)
            || lower.hasPrefix("http")
            || lower.contains("전 세계 사람들과 동영상 공유")
    }

    /// 앞뒤 기호 · 이모지 · 주소 링크를 걷고, 너무 짧거나 길면 버린다.
    private static func clean(_ raw: String) -> String? {
        var text = raw.replacingOccurrences(of: #"https?://\S+"#, with: "", options: .regularExpression)
        text = String(text.unicodeScalars.filter { !($0.properties.isEmojiPresentation || $0.properties.isEmoji && $0.value > 0x2000) })
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespaces.union(.punctuationCharacters).union(.symbols))
        guard (2...40).contains(text.count) else { return nil }
        return text
    }
}
