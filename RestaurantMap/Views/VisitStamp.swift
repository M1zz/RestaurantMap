//
//  VisitStamp.swift
//  인생 맛집
//
//  식당 앞에 서는 동그란 표시 — 음식 종류가 아니라 **얼마나 자주 갔는지**를 보여 준다.
//  커피 쿠폰 도장판처럼 읽힌다: 갈 때마다 테두리가 한 칸씩 차고, 네 칸이 다 차면 하트가 된다.
//
//   · 가볼 곳      책갈피 (아직 안 가 봄)
//   · 1~3번        테두리가 1/4 씩 차고, 가운데에 다녀온 횟수
//   · 단골         꽉 찬 분홍 원에 하트
//   · 인생 맛집    꽉 찬 금빛 원에 왕관
//   · 한때 단골    회색 원에 하트
//  나의 미슐랭에 오른 집은 오른쪽 위에 순위가 붙는다.
//

import SwiftUI

struct VisitStamp: View {
    var days: Int
    var level: RegularLevel
    var isLapsed = false
    var isWishlist = false
    var rank: Int? = nil
    var size: CGFloat = 40

    private var fill: AnyShapeStyle {
        if isLapsed { return AnyShapeStyle(Color.gray.gradient) }
        return level == .lifetime ? AnyShapeStyle(Color.orange.gradient) : AnyShapeStyle(Color.pink.gradient)
    }

    var body: some View {
        ZStack {
            if isWishlist {
                Circle().fill(.orange.opacity(0.15))
                Image(systemName: "bookmark.fill")
                    .font(.system(size: size * 0.42))
                    .foregroundStyle(.orange)
            } else if level >= .regular {
                Circle().fill(fill)
                Image(systemName: level == .lifetime && !isLapsed ? "crown.fill" : "heart.fill")
                    .font(.system(size: size * 0.44))
                    .foregroundStyle(.white)
            } else {
                // 도장판: 네 번이면 단골. 빈 테두리 위에 다녀온 만큼만 칠한다.
                Circle().fill(.pink.opacity(0.08))
                Circle().inset(by: size * 0.05)
                    .stroke(.gray.opacity(0.25), lineWidth: size * 0.09)
                Circle().inset(by: size * 0.05)
                    .trim(from: 0, to: CGFloat(min(max(days, 0), Regular.regularDays)) / CGFloat(Regular.regularDays))
                    .stroke(.pink, style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(verbatim: "\(days)")
                    .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                    .foregroundStyle(.pink)
            }
        }
        .frame(width: size, height: size)
        .overlay(alignment: .topTrailing) {
            if let rank {
                Text(verbatim: "\(rank)")
                    .font(.system(size: size * 0.3, weight: .heavy, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(width: size * 0.44, height: size * 0.44)
                    .background(.yellow, in: Circle())
                    .overlay(Circle().stroke(.background, lineWidth: 1.5))
                    .offset(x: size * 0.14, y: -size * 0.14)
            }
        }
        .accessibilityHidden(true)
    }
}

extension VisitStamp {
    init(restaurant: Restaurant, rank: Int? = nil, size: CGFloat = 40) {
        let regular = restaurant.regular
        self.init(days: regular.days, level: regular.level, isLapsed: regular.isLapsed,
                  isWishlist: restaurant.isWishlist, rank: rank, size: size)
    }
}
