//
//  WelcomeView.swift
//  인생 맛집
//
//  처음 열었을 때 한 번 — 이 앱이 무엇을 하는지 세 장으로.
//  단골 인정이 생기기 전부터 쓰던 사람도 한 번 본다 (나의 미슐랭이 직접 고르는 것에서 앱이 매기는 것으로 바뀌었다).
//

import SwiftUI

struct WelcomeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    private struct Page: Identifiable {
        let id: Int
        let symbol: String
        let title: LocalizedStringKey
        let body: LocalizedStringKey
    }

    private let pages: [Page] = [
        Page(id: 0, symbol: "rosette",
             title: "자주 가는 집이 진짜 좋아하는 집",
             body: "좋아한다고 말한 집이 아니라 실제로 다녀온 날을 세요. 네 번 가면 단골, 반년 넘게 꾸준히 가면 인생 맛집으로 인정해요."),
        Page(id: 1, symbol: "leaf.fill",
             title: "미식의 기준으로 적어요",
             body: "재료, 조리, 조화, 개성. 접시 위의 음식만 보고 적어요. 갈 때마다 한결같은지는 앱이 세어 줘요."),
        Page(id: 2, symbol: "person.2.fill",
             title: "단골만 올리는 후기",
             body: "한 번 가 보고 쓴 글 대신, 네 번 넘게 간 사람들의 후기를 봐요. 내 단골집 후기도 올릴 수 있어요."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(pages) { item in
                    ScrollView {
                        VStack(spacing: 20) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 64))
                                .foregroundStyle(.orange)
                                .padding(.top, 48)
                                .accessibilityHidden(true)
                            Text(item.title)
                                .font(.title2.bold())
                                .multilineTextAlignment(.center)
                            Text(item.body)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 32)
                    }
                    .tag(item.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    dismiss()
                }
            } label: {
                Text(page < pages.count - 1 ? "다음" : "시작하기")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .interactiveDismissDisabled()
    }
}

extension View {
    /// 첫 실행 안내를 한 번 띄운다. 다 본 뒤에 뒤따르는 것(축하 등)이 서도록 본 사실을 적는다.
    func welcomeOnce() -> some View { modifier(WelcomeOnce()) }
}

private struct WelcomeOnce: ViewModifier {
    @AppStorage("welcome.regulars.seen") private var seen = false
    @State private var shows = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                #if DEBUG
                if ScreenshotScene.current != nil { return }
                #endif
                if !seen { shows = true }
            }
            .sheet(isPresented: $shows, onDismiss: { seen = true }) {
                WelcomeView()
            }
    }
}
