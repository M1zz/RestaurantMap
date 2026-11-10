//
//  RestaurantExport.swift
//  인생 맛집
//
//  식당 · 방문 기록을 CSV 한 장으로 꺼낸다. 어느 칸이든 무료다 (기본 내보내기는 잠그지 않는다).
//  방문 한 번이 한 줄이고, 방문이 없는 식당(가볼 곳 등)도 한 줄로 남긴다.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct RestaurantExport: Transferable {
    let rows: [[String]]

    static var fileName: String { String(localized: "인생맛집 기록") }

    @MainActor
    init(restaurants: [Restaurant]) {
        let header = [
            String(localized: "식당 이름"), String(localized: "구분"), String(localized: "음식 종류"),
            String(localized: "카테고리"), String(localized: "주소"), String(localized: "전화번호"),
            String(localized: "위도"), String(localized: "경도"), String(localized: "탑6 순위"),
            String(localized: "식당 메모"), String(localized: "방문 날짜"), String(localized: "별점"),
            String(localized: "메뉴"), String(localized: "방문 메모"), String(localized: "사진 수"),
        ]
        let day = Date.ISO8601FormatStyle().year().month().day()
        var rows = [header]
        for restaurant in restaurants.sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) {
            let place = [
                restaurant.name, restaurant.listType.displayName, restaurant.foodCategory.localizedName,
                restaurant.category, restaurant.address, restaurant.phoneNumber,
                String(restaurant.latitude), String(restaurant.longitude),
                restaurant.top6Rank.map(String.init) ?? "", restaurant.notes,
            ]
            let visits = (restaurant.visits ?? []).sorted { $0.visitDate < $1.visitDate }
            if visits.isEmpty {
                rows.append(place + ["", "", "", "", ""])
            }
            for visit in visits {
                rows.append(place + [
                    visit.visitDate.formatted(day), visit.rating > 0 ? String(visit.rating) : "",
                    visit.displayMenuName, visit.notes, visit.hasPhotos ? String(visit.photos?.count ?? 0) : "",
                ])
            }
        }
        self.rows = rows
    }

    /// 엑셀 · 넘버스가 한글을 바로 읽도록 BOM 을 붙인다.
    var csv: Data {
        let text = rows.map { $0.map(Self.escape).joined(separator: ",") }.joined(separator: "\r\n")
        return Data("\u{FEFF}".utf8) + Data(text.utf8)
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { $0.csv }
            .suggestedFileName { _ in fileName + ".csv" }
    }
}
