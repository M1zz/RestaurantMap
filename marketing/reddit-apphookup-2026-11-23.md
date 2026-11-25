# r/AppHookup 딜 포스트 — 인생 맛집 (2026-11-23)

플레어: iOS
딜: Pro 평생(Pro Lifetime) 26.99 USD → 무료, 사용자 지정 오퍼 코드 MATJIP

## 0. App Store Connect 설정 (2026-11-23 완료)

- 앱 가격: 175개 국가 모두 무료 (2.99 USD 에서 변경, 즉시 적용)
- 오퍼 코드: Pro Lifetime ▸ 특가 코드 "AppHookup Free 2026-11" ▸ 사용자 설정 코드 MATJIP
  - 무료, 175개 국가, 구입 이력과 상관없이 누구나
  - 한도 10,000, 만료 2026-12-08 (본문의 "until December 7" 하루를 다 채우려고 하루 뒤로 잡았다)
- 남은 일: 미국 스토어에 Free 로 보이는지, 아래 링크가 Pro Lifetime 을 0 USD 로 여는지 실기기에서 확인

리딤 링크: https://apps.apple.com/redeem?ctx=offercodes&id=6755934548&code=MATJIP

## 1. 자격 검사

통과
- 인앱 구입 자체의 가격 변화다 (Pro Lifetime 26.99 USD → 0). 앱이 무료라는 것을 딜로 내세우지 않는다
- 평생 이용권이다. 기간 한정 체험이 아니다
- App Store 오퍼 코드를 쓴다. 외부 결제 우회 없음
- 광고 없음, 라이트 · 베타 아님
- 최근 몇 달 가격을 올렸다 내렸다 한 이력 없음

확인이 필요한 것 (지워질 수 있는 이유)
- 유료 앱이 프리미엄으로 바뀐 직후다. 규칙 1 의 "formerly paid apps that went free with non-free IAP" 는 앱이 무료가 된 것을 딜로 올릴 때의 금지지만, 모더레이터가 같은 것으로 볼 수 있다
- Pro Lifetime 은 1.0.2(2026-11-22 출시)에 새로 생긴 상품이라 26.99 USD 에 팔린 기간이 거의 없다. "launch deal" 로 볼 수 있다. 며칠이라도 정가로 둔 뒤 올리면 안전하다
- 주간 구독(Plus Weekly, Pro Weekly)을 판다. HigGym 글 때 적어 둔 것과 같은 위험
- 지워지면 모드에게 "the lifetime unlock is free with an App Store offer code" 라고 묻는다

## 2. 제목

[iOS] [Insaeng Matjip Food Map] [Pro Lifetime 26.99 USD to Free] [Private restaurant journal that pins where you ate on a map with ratings and taste notes]

대안

[iOS and visionOS] [Insaeng Matjip Food Map] [Pro Lifetime 26.99 USD to Free] [Log every restaurant visit with stars, dishes, photos and taste notes on your own map]

## 3. 본문

Hi everyone, I'm the developer of Insaeng Matjip, a private restaurant journal for iPhone and Apple Vision Pro. The name is Korean for a restaurant you would keep for life.

The app just moved from a paid download (2.99 USD) to a free download with optional upgrades. To mark that, Pro Lifetime is free until December 7 with an App Store offer code. Pro Lifetime normally costs 26.99 USD, is a one time purchase and not a subscription. 10,000 redemptions of the code are available.

Redeem Pro Lifetime: https://apps.apple.com/redeem?ctx=offercodes&id=6755934548&code=MATJIP

App Store: https://apps.apple.com/app/id6755934548

Install the app first, then open the redeem link on your iPhone. If the link does not open the redeem sheet, open the upgrade screen inside the app, tap Redeem Code at the bottom, and type the code from the end of the link.

What it does:
You pin the restaurants you have eaten at on a map and log every visit with the date, stars, dishes, photos and notes. Instead of one overall score, each visit can be rated on how well the food was made (ingredients, technique, harmony, character) and how it tasted (richness and kick). Go back to the same place on four different days and the app marks you as a regular there.

Free for everyone:
Save up to 30 restaurants across Visited and Want to Go
Map search, visit logs with photos, gourmet criteria and taste notes
Regulars and a taste map built from your own ratings
CSV export of restaurants and visits

Unlocked by this deal:
Unlimited restaurants
Your own food types with their own taste notes
A summary of your gourmet criteria per restaurant and what your records say about your taste
Designed regular cards you can share
A reminder to log a visit 40 minutes after you leave a saved restaurant
Manual iCloud backup and restore

No ads and no account. Your records stay on your device and in your own iCloud. Place search goes through Apple Maps, and anonymous usage statistics and crash reports are collected. The app also sells Plus and Pro subscriptions, but with this code you will not need them. Requires iOS 18.6 or later.

I would like to hear whether the rating criteria make sense for the food you eat, since I designed them around Korean dining. I will be in the comments.

## 4. 검사 스크립트 결과

check_post.py — 제목 + 본문 FAIL 0, WARN 0.
대안 제목은 WARN 1 (Platform 값 'iOS and visionOS' 확인).

## 5. 홍보 이미지

- marketing/promo-card.png (1600x900)
- marketing/promo-card-square.png (1080x1080)

AppHookup 은 링크 글로 올리고, 이미지는 댓글이나 다른 서브레딧에서 쓴다.
스크린샷은 docs/screenshots/marketing/en-US 의 것이다. 가운데 장(03-detail)에 1.0.2 에서 뺀 취향 차트가 보이면 새로 찍어 갈아 끼운다.

## 6. 댓글 FAQ

Is this really lifetime? Any subscription later?
Yes. The code gives you Pro Lifetime, the same one time purchase that costs 26.99 USD. It never renews and it follows your Apple Account to a new phone through Restore Purchases.

Does it work on iPad, Mac or Android?
iPhone (iOS 18.6 or later) and Apple Vision Pro. No iPad, Mac or Android version right now.

What data do you collect?
No account and no ads. Restaurants, visits and photos stay on your device and in your own iCloud. Search terms and map position go to the place search service when you search. I also get anonymous usage statistics and crash reports, and any feedback you choose to send.

Does search work outside Korea?
Yes, place search uses Apple Maps, and you can also drop a pin by hand anywhere on the map.

The link does not work or the code is rejected.
Install the app first and open the link on the iPhone itself. If the sheet does not appear, open the upgrade screen in the app and tap Redeem Code. If you already own Pro Lifetime, the App Store will not let you redeem it again.

I paid 2.99 USD for the app before. Do I need the code?
No. Everyone who bought the paid version already has Pro for life. Tap Restore Purchases if it does not show.

The code has run out. Any more?
Thanks for the interest. All redemptions have been claimed and I am not planning another batch.

Why not just use Apple Maps guides or Google Maps lists?
Those keep a list of places. This keeps a log of each visit, so you can see how a place changed over time and what you actually ordered, and it stays private.

Feature request
Thank you, noted. (실제로 계획이 있을 때만 약속한다)

## 7. 다른 서브레딧용 변형

올리기 전에 각 서브레딧 사이드바 규칙(셀프 프로모션 빈도, 요일, 카르마 제한)을 직접 확인한다. 같은 날 여러 곳에 붙이지 않는다.

### r/iosapps — 사용자 관점

제목: I made a private restaurant journal that rates how a dish was made, not just how many stars

I kept forgetting what I ordered at places I liked, and a single star rating never told me why I liked them. So I built Insaeng Matjip. You pin the restaurants you ate at, and each visit gets the date, dishes, photos and two kinds of notes: how well it was made (ingredients, technique, harmony, character) and how it tasted (richness and kick). Steak gets doneness, ramen gets broth, coffee gets body. Visit the same place on four different days and it becomes one of your regulars.

It is free for up to 30 restaurants, with no ads and no account. Pro Lifetime is free until December 7 with an offer code, link in the comments.

주의: 이미지 글로 올리고 promo-card.png 를 붙인다. 링크는 첫 댓글에.

### r/SideProject — 만든 이야기

제목: I turned my paid restaurant journal app into a free one after a year of almost no sales

A year ago I shipped a 2.99 USD restaurant journal. Almost nobody bought an app they could not try first. This month I rebuilt the pricing: free for 30 restaurants, and paid tiers only for things that cost me nothing to give away early, like unlimited saves and summaries. Everyone who paid before keeps the top tier for life. I also added 24 languages and a Vision Pro version. Happy to share what changed in the numbers once I have them.

주의: 숫자(판매량, 전환)를 실제 값으로 넣으면 반응이 좋다. 딜 링크는 마지막 한 줄만.

### r/SwiftUI 또는 r/iOSProgramming — 기술 이야기

제목: Grandfathering paid users into a lifetime tier when a paid app goes freemium

When my app went from paid to free with in app purchases, I had to give earlier buyers the top tier without a server. I used AppTransaction to read the original purchase version and compared it against the last paid build. Notes on what went wrong: the sandbox always reports version 1.0, and the build number, not the marketing version, is what you get on iOS.

주의: 홍보는 마지막 한 줄. 위 내용은 실제 구현(RestaurantPlan.swift)과 맞는지 확인하고 고친 뒤 올린다.

## 8. 딜 끝났을 때

본문 맨 위에 추가하고 플레어를 Expired 로 바꾼다.

Edit: The offer code has expired and all redemptions are closed. Pro Lifetime is back to 26.99 USD. Thank you all, and thanks for the feedback in the comments.

## 9. 올리기 전 체크리스트

- [ ] 미국 스토어에 앱이 Free 로 보인다 (가격은 무료로 바꿈)
- [ ] 리딤 링크를 실기기에서 열어 Pro Lifetime 이 0 USD 로 뜬다 (코드는 만듦)
- [ ] 미국 스토어의 인앱 구입 표시 이름과 가격(Pro Lifetime, 26.99 USD)이 제목과 같다
- [ ] 사용 횟수 500 이상, 본문의 10,000 과 December 7 이 실제 설정과 같다
- [ ] 검사 스크립트 FAIL 0
- [ ] 미국 동부 평일 오전(한국 시간 밤 10시~자정)에 올리고 첫 1~2시간 댓글에 바로 답한다
- [ ] 2026-12-07 또는 소진 시 글을 수정하고, 더 달라는 요청에는 추가 배포하지 않는다
