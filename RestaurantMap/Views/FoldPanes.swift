//
//  FoldPanes.swift
//  RestaurantMap
//
//  아이폰 듀오를 폈을 때 접힌 선 양쪽에 무엇이 서는가.
//  자리 셈 · 시트 가드 · 탭 막대는 LeeoKit Fold 모듈이 하고, 여기는 이 앱의 짝만 정한다.
//
//  - 고르는 쪽(가로면 왼쪽, 세로면 아래): 지도 · 목록 · 추천 중 고른 탭.
//  - 결과 쪽(오른쪽, 위): 지도 핀이나 목록에서 고른 식당의 자세히. 아직 고르지 않았으면 취향.
//    그래서 취향 탭은 따로 서지 않고, 펼친 탭 막대에는 셋만 선다.
//  - 접혀 있거나 보통 아이폰이면 탭만 그린다. 식당을 누르면 지금처럼 시트가 뜬다.
//

import SwiftUI
import SwiftData
import LeeoKit

/// 펼친 화면에서 결과 쪽에 띄울 식당.
@Observable
final class FoldRestaurantPick {
    var restaurant: Restaurant?

    /// 식당을 누를 때의 갈림길. 펼쳐 있으면 결과 쪽 판에 세우고 true,
    /// 접혀 있으면 false (부르는 쪽이 지금처럼 시트를 띄운다).
    func show(_ restaurant: Restaurant, in fold: FoldLayout) -> Bool {
        guard fold.isUnfolded else { return false }
        self.restaurant = restaurant
        return true
    }
}

/// 펼친 화면의 탭 한 장: 고른 탭 | 고른 식당(없으면 취향).
struct FoldTab<Choose: View>: View {
    @ViewBuilder let choose: () -> Choose

    var body: some View {
        FoldSplitView {
            choose()
        } result: {
            FoldRestaurantResult()
                // 결과 쪽 판 안에서는 접히지 않은 화면처럼 선다.
                .environment(\.foldLayout, .single)
        }
        .foldTabBarRoom()
    }
}

private struct FoldRestaurantResult: View {
    @Environment(FoldRestaurantPick.self) private var pick
    @Query private var restaurants: [Restaurant]

    /// 고른 식당이 지워졌으면 취향으로 돌아간다.
    private var picked: Restaurant? {
        guard let id = pick.restaurant?.persistentModelID else { return nil }
        return restaurants.first { $0.persistentModelID == id }
    }

    var body: some View {
        if let picked {
            RestaurantDetailView(restaurant: picked, onClose: { pick.restaurant = nil })
                .id(picked.persistentModelID)
        } else {
            TasteProfileView()
        }
    }
}

enum FoldTabs {
    /// 펼쳤을 때 고르는 쪽 판 바닥에 서는 칸. 취향(3)은 결과 쪽에 서므로 빠진다.
    static let items: [FoldTabBar<Int>.Item] = [
        .init(value: 0, title: String(localized: "지도"), symbol: "map"),
        .init(value: 1, title: String(localized: "목록"), symbol: "list.bullet"),
        .init(value: 2, title: String(localized: "추천"), symbol: "sparkles"),
    ]
}
