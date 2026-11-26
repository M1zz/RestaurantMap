//
//  GoogleImportTests.swift
//  인생 맛집
//
//  구글 지도에서 옮겨 오기 — zip 풀기 · CSV · GeoJSON · 링크 속 좌표.
//  깨진 파일이 들어와도 죽지 않고, 지도에 못 그릴 좌표는 저장하지 않는지 본다.
//

import XCTest
import CoreLocation
@testable import RestaurantMap

final class GoogleImportTests: XCTestCase {

    // MARK: - CSV

    func testCSVKeepsQuotedCommasNewlinesAndEscapedQuotes() {
        let rows = CSV.rows("a,b,c\n\"x, y\",\"line1\nline2\",\"say \"\"hi\"\"\"\r\nlast,,")
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[1], ["x, y", "line1\nline2", "say \"hi\""])
        XCTAssertEqual(rows[2], ["last", "", ""])
    }

    func testCSVWithoutTrailingNewline() {
        XCTAssertEqual(CSV.rows("a,b"), [["a", "b"]])
        XCTAssertEqual(CSV.rows(""), [])
    }

    func testSavedListCSV() throws {
        let csv = """
        \u{FEFF}Title,Note,URL,Tags,Comment
        을지면옥,평양냉면,"https://www.google.com/maps/place/Euljimyeonok/@37.5662,126.9910,17z",,재방문
        ,,https://www.google.com/maps/place/Mingles+Seoul/data=!3d37.5251!4d127.0410,,
        ,,,,
        """
        let list = try XCTUnwrap(GoogleMapsImport.places(fromCSV: Data(csv.utf8), listName: "가고 싶은 곳"))
        XCTAssertEqual(list.name, "가고 싶은 곳")
        XCTAssertFalse(list.visited)
        XCTAssertEqual(list.places.map(\.name), ["을지면옥", "Mingles Seoul"], "제목이 없으면 링크 속 이름을 쓴다")
        XCTAssertEqual(list.places[0].note, "평양냉면\n재방문")
        XCTAssertEqual(list.places[0].coordinate?.latitude ?? 0, 37.5662, accuracy: 1e-6)
        XCTAssertEqual(list.places[1].coordinate?.longitude ?? 0, 127.0410, accuracy: 1e-6)
    }

    func testCSVWithoutGoogleLinksIsNotAList() {
        let csv = "Title,URL\nfoo,https://example.com\n"
        XCTAssertNil(GoogleMapsImport.places(fromCSV: Data(csv.utf8), listName: "x"))
    }

    // MARK: - 링크 속 좌표

    func testCoordinateInLinkPrefersThePlacePinOverTheViewport() throws {
        let link = "https://www.google.com/maps/place/X/@37.0,127.0,15z/data=!3d37.5665!4d126.9780"
        let c = try XCTUnwrap(GoogleMapsImport.coordinate(in: link))
        XCTAssertEqual(c.latitude, 37.5665, accuracy: 1e-6)
        XCTAssertEqual(c.longitude, 126.9780, accuracy: 1e-6)
    }

    func testCoordinateFromQueryAndRejectsOutOfRange() {
        XCTAssertNotNil(GoogleMapsImport.coordinate(in: "https://maps.google.com/?q=-33.8688,151.2093"))
        XCTAssertNil(GoogleMapsImport.coordinate(in: "https://maps.google.com/?q=120.5,30.1"), "위도 90 넘는 값은 버린다")
        XCTAssertNil(GoogleMapsImport.coordinate(in: "https://maps.app.goo.gl/abc"))
    }

    // MARK: - GeoJSON

    private func geoJSON(_ features: [[String: Any]]) -> Data {
        try! JSONSerialization.data(withJSONObject: ["type": "FeatureCollection", "features": features])
    }

    func testReviewedPlacesBecomeAVisitedListWithClampedStars() throws {
        let data = geoJSON([
            ["geometry": ["coordinates": [126.978, 37.5665]],
             "properties": ["google_maps_url": "https://maps.google.com/?cid=1",
                            "location": ["name": "광장시장", "address": "서울 종로구"],
                            "five_star_rating_published": 7,
                            "review_text_published": "빈대떡",
                            "date": "2025-03-01T12:00:00Z"]],
            ["geometry": ["coordinates": [0, 0]],
             "properties": ["google_maps_url": "https://maps.google.com/?cid=2",
                            "location": ["name": "좌표 없는 곳"],
                            "five_star_rating_published": 3]]
        ])
        let list = try XCTUnwrap(GoogleMapsImport.places(fromGeoJSON: data))
        XCTAssertTrue(list.visited)
        XCTAssertEqual(list.places.count, 2)
        XCTAssertEqual(list.places[0].rating, 5, "5를 넘는 별은 5로 자른다")
        XCTAssertEqual(list.places[0].note, "빈대떡")
        XCTAssertEqual(list.places[0].coordinate?.latitude ?? 0, 37.5665, accuracy: 1e-6)
        XCTAssertNotNil(list.places[0].date)
        XCTAssertNil(list.places[1].coordinate, "(0,0) 은 좌표가 없는 것이다")
    }

    func testStarredPlacesOldFormatAndLabelsAreSkipped() throws {
        let data = geoJSON([
            ["geometry": ["coordinates": [200.0, 95.0]],
             "properties": ["Google Maps URL": "https://maps.google.com/?cid=3",
                            "Title": "옛 형식 가게",
                            "Location": ["Address": "부산"]]],
            ["geometry": ["coordinates": [127.0, 37.0]],
             "properties": ["Title": "집"]]
        ])
        let list = try XCTUnwrap(GoogleMapsImport.places(fromGeoJSON: data))
        XCTAssertFalse(list.visited)
        XCTAssertEqual(list.places.map(\.name), ["옛 형식 가게"], "링크 없는 라벨 장소(집 · 회사)는 뺀다")
        XCTAssertNil(list.places[0].coordinate, "지도에 그릴 수 없는 좌표는 저장하지 않는다")
        XCTAssertEqual(list.places[0].address, "부산")
    }

    func testNonFiniteRatingDoesNotCrash() throws {
        let json = #"{"features":[{"properties":{"google_maps_url":"https://maps.google.com/?cid=9","location":{"name":"A"},"five_star_rating_published":"nan"}}]}"#
        let list = try XCTUnwrap(GoogleMapsImport.places(fromGeoJSON: Data(json.utf8)))
        XCTAssertEqual(list.places.first?.rating, 0)
        XCTAssertFalse(list.visited, "읽을 수 없는 별점은 후기로 치지 않는다")
    }

    func testGarbageIsNotAList() {
        XCTAssertNil(GoogleMapsImport.places(fromGeoJSON: Data("not json".utf8)))
        XCTAssertNil(GoogleMapsImport.places(fromGeoJSON: Data("{}".utf8)))
    }

    // MARK: - zip

    /// zip -9 로 압축한 CSV 하나 + zip -0 으로 넣은 글 하나.
    private let takeout = Data(base64Encoded: "UEsDBBQAAgAIABpHe137CQYhLQEAAH0FAAAbABwAVGFrZW91dC9TYXZlZC9GYXZvcml0ZXMuY3N2VVQJAANDxwhrQ8cIa3V4CwABBPUBAAAEAAAAAI3STUrDYBSF4bmrcAEhyZv/OHIBIkV0AaWEKrSm0EDB1Vs55/uc3tGFw+UdPe9f22kpXtdtKT7eXh52p/1heayL7/twP5/bdrk+VdXtdiuP63o8LeVhPVfn/eVaXf5eq11dPbdj2dcFzVjW9Y8TKEEkgRIoQUo0SjSRRKNEo0STEq0SbSTRKtEq0aZEp0QXSXRKdEp0KdEr0UcSvRK9En1KDEoMkcSgxKDEkBKjEmMkMSoxKjGmxKTEFElMSkxKTCkxKzFHErMSsxJzpmWehHxioFgo/0ST0RjSpDQxzU4xVEJSMVVslYwVayXEFXvFYMliMVlCZjFarJbMFrslBBfLxXTJdjFeQnoxX+yXDBgLJkQYG8aIyYoxY0KOMWQsmUwZWyaEGWvGnLl7/gVQSwMECgAAAAAAGkd7XYamEDYFAAAABQAAABIAHABUYWtlb3V0L3JlYWRtZS50eHRVVAkAA0PHCGtDxwhrdXgLAAEE9QEAAAQAAAAAaGVsbG9QSwECHgMUAAIACAAaR3td+wkGIS0BAAB9BQAAGwAYAAAAAAABAAAApIEAAAAAVGFrZW91dC9TYXZlZC9GYXZvcml0ZXMuY3N2VVQFAANDxwhrdXgLAAEE9QEAAAQAAAAAUEsBAh4DCgAAAAAAGkd7XYamEDYFAAAABQAAABIAGAAAAAAAAAAAAKSBggEAAFRha2VvdXQvcmVhZG1lLnR4dFVUBQADQ8cIa3V4CwABBPUBAAAEAAAAAFBLBQYAAAAAAgACALkAAADTAQAAAAA=")!

    func testZipReadsDeflatedAndStoredEntries() throws {
        let all = ZipReader.entries(in: takeout) { _ in true }
        XCTAssertEqual(all.map(\.name), ["Takeout/Saved/Favorites.csv", "Takeout/readme.txt"])
        XCTAssertEqual(String(decoding: all[1].data, as: UTF8.self), "hello")
        let csv = String(decoding: all[0].data, as: UTF8.self)
        XCTAssertTrue(csv.hasPrefix("Title,Note,URL\nPlace 0,note 0,"))
        XCTAssertEqual(CSV.rows(csv).count, 21)
    }

    func testZipFilterAndBrokenInput() {
        XCTAssertEqual(ZipReader.entries(in: takeout) { $0.hasSuffix(".csv") }.count, 1)
        XCTAssertTrue(ZipReader.entries(in: Data("PK nope".utf8)) { _ in true }.isEmpty)
        XCTAssertTrue(ZipReader.entries(in: takeout.prefix(takeout.count - 10)) { _ in true }.isEmpty,
                      "끝이 잘린 zip 은 아무것도 꺼내지 않는다(죽지 않는다)")
    }
}
