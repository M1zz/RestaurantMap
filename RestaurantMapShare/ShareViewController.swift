//
//  ShareViewController.swift
//  인생 맛집 · 공유 확장
//
//  인스타 · 릴스 · 블로그 · 지도 앱에서 공유 ▸ 인생 맛집.
//  글에서 가게를 찾아 보여 주고, 하나를 고르면 링크와 함께 '가볼 곳' 보관함에 넣는다 (→ SharedPlace.swift).
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        let host = UIHostingController(rootView: ShareView(items: items) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        })
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }
}

// MARK: - 화면

struct ShareView: View {
    let items: [NSExtensionItem]
    let close: () -> Void

    enum Phase { case reading, ready, saved }

    @State private var phase = Phase.reading
    @State private var link = ""
    @State private var candidates: [PlaceCandidate] = []
    @State private var selection: PlaceCandidate.ID?
    @State private var query = ""
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("인생 맛집에 담기")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("취소", action: close)
                    }
                }
        }
        .task { await read() }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .reading:
            ProgressView("글에서 가게를 찾고 있어요")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready:
            picker
        case .saved:
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
                Text("가볼 곳에 담았어요")
                    .font(.title3.weight(.semibold))
                Text("앱을 열면 링크와 함께 들어가 있어요.")
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var picker: some View {
        List(selection: $selection) {
            Section {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("가게 이름으로 찾기", text: $query)
                        .submitLabel(.search)
                        .onSubmit { Task { await searchTyped() } }
                    if isSearching { ProgressView() }
                }
            }

            Section {
                if candidates.isEmpty {
                    Text("글에서 가게를 찾지 못했어요. 가게 이름을 검색해 주세요.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(candidates) { place in
                        row(place).tag(place.id)
                    }
                }
            } header: {
                if !candidates.isEmpty { Text("어느 가게인가요?") }
            } footer: {
                if let host = URL(string: link)?.host() {
                    Label(host, systemImage: "link")
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .safeAreaInset(edge: .bottom) {
            Button {
                save()
            } label: {
                Label("가볼 곳에 담기", systemImage: "bookmark.fill")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(selection == nil)
            .padding()
            .background(.bar)
        }
    }

    private func row(_ place: PlaceCandidate) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(place.name).font(.body.weight(.semibold))
            if !place.address.isEmpty {
                Text(place.address).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 일

    /// 받은 링크 · 글을 읽고, 링크의 페이지 글까지 모아 가게를 찾는다.
    private func read() async {
        var texts: [String] = []
        for item in items {
            if let text = item.attributedContentText?.string, !text.isEmpty { texts.append(text) }
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                    if link.isEmpty, !url.isFileURL { link = url.absoluteString }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                          let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
                    texts.append(text)
                }
            }
        }
        // 글 속에만 링크가 있는 공유(지도 앱 · 카톡)도 있다
        if link.isEmpty, let found = texts.lazy.compactMap(Self.firstLink).first { link = found.absoluteString }
        if let url = URL(string: link) { texts += await PlaceFinder.pageTexts(of: url) }

        let guess = PlaceGuess(from: texts)
        candidates = await PlaceFinder.search(guess)
        selection = candidates.first?.id
        if candidates.isEmpty { query = guess.firstQuery ?? "" }
        phase = .ready
    }

    private func searchTyped() async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isSearching = true
        candidates = await PlaceFinder.search(typed: text)
        selection = candidates.first?.id
        isSearching = false
    }

    private func save() {
        guard let place = candidates.first(where: { $0.id == selection }) else { return }
        ShareInbox.add(place.shared(link: link))
        withAnimation { phase = .saved }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            close()
        }
    }

    private static func firstLink(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        return detector?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))?.url
    }
}
