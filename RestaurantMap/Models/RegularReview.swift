//
//  RegularReview.swift
//  인생 맛집
//
//  단골 후기 — 다른 사람에게 공개하는 한 건.
//
//  ⚠️ 단골(서로 다른 날 네 번)이 된 집에만 올릴 수 있다. 한 번 가 보고 쓰는 후기가 아니다.
//  ⚠️ 공개하는 것은 여기 있는 것뿐이다: 가게 · 다녀온 횟수 · 몇 달째인지 · 별점 평균 · 미식 기준 평균 · 한마디 · 별명.
//     다녀온 날짜 · 사진 · 메모 · 내 위치는 올리지 않는다.
//

import Foundation
import CloudKit
import CoreLocation

struct RegularReview: Identifiable, Equatable {
    static let recordType = "RegularReview"
    static let textLimit = 200
    static let nicknameLength = 2...12

    var id: String
    var placeName: String
    var address: String
    var categoryIcon: String
    var latitude: Double
    var longitude: Double
    /// 다녀온 서로 다른 날 수.
    var days: Int
    var level: RegularLevel
    /// 처음 간 달부터 세어 몇 달째인지.
    var months: Int
    var rating: Double
    var criteria: [GourmetCriterion: Double]
    var consistency: Consistency?
    /// 이 집을 왜 계속 가는지 한마디.
    var text: String
    var nickname: String
    /// 올린 사람 (iCloud 사용자 레코드 이름 — 사람을 알아볼 수 없는 값).
    var author: String
    var postedAt: Date

    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
}

extension RegularReview {
    /// 지금 기록으로 만든 후기. 단골이 아니면 nil.
    init?(restaurant: Restaurant, id: String, text: String, nickname: String, author: String, now: Date = Date()) {
        let regular = restaurant.regular
        guard regular.isRanked, let first = regular.first else { return nil }
        self.id = id
        placeName = restaurant.name
        address = restaurant.address
        categoryIcon = restaurant.categoryIcon
        latitude = restaurant.latitude
        longitude = restaurant.longitude
        days = regular.days
        level = regular.level
        months = (Calendar.current.dateComponents([.month], from: first, to: now).month ?? 0) + 1
        rating = restaurant.averageRating
        criteria = Dictionary(uniqueKeysWithValues: GourmetCriterion.allCases.compactMap { criterion in
            restaurant.gourmetAverage(criterion).map { (criterion, $0) }
        })
        consistency = restaurant.consistency
        self.text = text
        self.nickname = nickname
        self.author = author
        postedAt = now
    }

    init?(record: CKRecord) {
        guard record.recordType == Self.recordType,
              let placeName = record["placeName"] as? String,
              let author = record["author"] as? String,
              let level = RegularLevel(rawValue: record["level"] as? Int ?? 0), level >= .regular else { return nil }
        id = record.recordID.recordName
        self.placeName = placeName
        address = record["address"] as? String ?? ""
        categoryIcon = record["categoryIcon"] as? String ?? "fork.knife"
        let location = record["location"] as? CLLocation
        latitude = location?.coordinate.latitude ?? 0
        longitude = location?.coordinate.longitude ?? 0
        days = record["days"] as? Int ?? 0
        self.level = level
        months = record["months"] as? Int ?? 1
        rating = record["rating"] as? Double ?? 0
        criteria = Dictionary(uniqueKeysWithValues: GourmetCriterion.allCases.compactMap { criterion in
            (record[criterion.rawValue] as? Double).map { (criterion, $0) }
        })
        consistency = (record["consistency"] as? Int).flatMap(Consistency.init(score:))
        text = record["text"] as? String ?? ""
        nickname = record["nickname"] as? String ?? ""
        self.author = author
        postedAt = record["postedAt"] as? Date ?? record.creationDate ?? .distantPast
    }

    func fill(_ record: CKRecord) {
        record["placeName"] = placeName
        record["address"] = address
        record["categoryIcon"] = categoryIcon
        record["location"] = CLLocation(latitude: latitude, longitude: longitude)
        record["days"] = days
        record["level"] = level.rawValue
        record["months"] = months
        record["rating"] = rating
        for criterion in GourmetCriterion.allCases { record[criterion.rawValue] = criteria[criterion] }
        record["consistency"] = consistency?.score
        record["text"] = text
        record["nickname"] = nickname
        record["author"] = author
        record["postedAt"] = postedAt
        record["language"] = Locale.current.language.languageCode?.identifier
    }

    /// "9번 다녀옴 · 8개월째"
    var visitLine: String {
        String(localized: "\(days)번 다녀옴 · \(months)개월째", comment: "Regular review: visit count and how many months the person has been going")
    }
}

// MARK: - 올리기 전에 거르기

/// 공개 글에 넣으면 안 되는 것. 올리기 전에 기기에서 먼저 막는다 (심사 지침 1.2 — 부적절한 내용 거르기).
enum ReviewFilter {
    enum Problem: Equatable {
        case tooShort, tooLong, offensive, contact

        var message: String {
            switch self {
            case .tooShort: String(localized: "조금만 더 적어 주세요.", comment: "Review text is too short")
            case .tooLong: String(localized: "조금만 줄여 주세요.", comment: "Review text is too long")
            case .offensive: String(localized: "욕설이나 남을 깎아내리는 말은 올릴 수 없어요.", comment: "Review text contains offensive words")
            case .contact: String(localized: "링크, 전화번호, 계정 이름은 올릴 수 없어요.", comment: "Review text contains links or contact details")
            }
        }
    }

    /// 욕설 · 비하. 붙여 쓰거나 사이에 기호를 넣어도 잡히게 글자만 남겨 본다.
    /// ⚠️ 음식 글에 흔히 나오는 말과 겹치는 것(새끼돼지 · 불이 꺼져 · バカうま)은 넣지 않는다.
    private static let offensive: [String] = [
        "씨발", "시발", "씨바", "ㅅㅂ", "ㅆㅂ", "병신", "ㅂㅅ", "지랄", "ㅈㄹ", "개새끼", "개새기", "좆", "ㅈ같",
        "미친놈", "미친년", "썅", "창녀", "느금", "니애미", "한남충", "김치녀", "틀딱", "급식충", "맘충",
        "fuck", "shit", "bitch", "asshole", "bastard", "cunt", "nigger", "nigga", "faggot", "whore", "slut",
        "死ね", "傻逼", "操你", "他妈的", "婊子", "puta", "mierda", "scheiße", "сука", "блять",
    ]

    private static let contactPatterns: [String] = [
        #"https?://"#, #"www\."#, #"\.(com|net|kr|io|me|ly|gg|shop)\b"#, #"@[A-Za-z0-9_.]{3,}"#,
        #"\d{2,4}[-.\s]?\d{3,4}[-.\s]?\d{4}"#, "카톡", "오픈채팅", "텔레그램", "kakao", "telegram",
    ]

    static func problem(in text: String, minimum: Int = 5, limit: Int = RegularReview.textLimit) -> Problem? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < minimum { return .tooShort }
        if trimmed.count > limit { return .tooLong }
        let squeezed = trimmed.lowercased().filter { $0.isLetter || $0.isNumber }
        if offensive.contains(where: { squeezed.contains($0) }) { return .offensive }
        let lowered = trimmed.lowercased()
        if contactPatterns.contains(where: { lowered.range(of: $0, options: .regularExpression) != nil }) { return .contact }
        return nil
    }

    static func nicknameProblem(_ nickname: String) -> Problem? {
        problem(in: nickname, minimum: RegularReview.nicknameLength.lowerBound, limit: RegularReview.nicknameLength.upperBound)
    }
}
