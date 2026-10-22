#!/usr/bin/env python3
"""App Store 마케팅 스크린샷: 원본 캡처 + 헤드라인 → HTML → 헤드리스 Chrome (appstore-assets 스킬).

사용법: python3 scripts/make_marketing_screenshots.py [언어 ...]   (없으면 전부)

자리
  docs/screenshots/raw/<언어>/NN-….png          원본 캡처 (1320x2868, 스토어에 안 올라감)
  docs/screenshots/marketing/<로케일>/NN-….png   제출본 1242x2688 — DeployBar 가 이 폴더를 그대로 올린다
슬라이드마다 배치(layout)를 달리한다: hero-bleed · left-text · text-bottom · flat-rotate · dark
"""
import subprocess, sys, pathlib, tempfile, time

ROOT = pathlib.Path(__file__).resolve().parent.parent
RAW = ROOT / "docs" / "screenshots" / "raw"
OUT = ROOT / "docs" / "screenshots" / "marketing"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
W, H = 1242, 2688   # 이 계정의 아이폰 제출 규격

# 앱 언어 → App Store 로케일
STORE = {"ko": "ko", "en": "en-US"}

# 파일 · 배치 · 언어별 (헤드라인, 보조 문장)
SHOTS = [
    ("01-map.png",          "hero-bleed",  {"ko": ("내가 찾은 맛집<br>지도에 모아요", "순위 핀으로 최고의 맛집이 한눈에"), "en": ("Pin the restaurants<br>you discover", "Your best spots, ranked on the map")}),
    ("02-list.png",         "left-text",   {"ko": ("최고의 여섯 곳은<br>따로 모아요", "가본 곳, 가볼 곳까지 목록으로 정리해요"), "en": ("Your top six,<br>kept together", "Visited and Want to Go, neatly listed")}),
    ("03-detail.png",       "text-bottom", {"ko": ("갈 때마다 쌓이는<br>맛 기록", "방문 평균과 점수로 진짜 맛집을 가려요"), "en": ("A taste log that<br>grows each visit", "Average scores help you spot true favorites")}),
    ("04-taste-review.png", "flat-rotate", {"ko": ("스테이크는 굽기,<br>라멘은 국물", "음식마다 다른 기준으로 맛을 평가해요"), "en": ("Doneness for steak,<br>broth for ramen", "Rate each food by its own criteria")}),
    ("05-profile.png",      "dark",        {"ko": ("평가가 쌓이면<br>내 입맛이 보여요", "맵기부터 조리법까지 나의 미식 지도"), "en": ("Rate more,<br>and your palate shows", "From spice level to cooking style")}),
]

# 색은 헤더·검색 결과 그림(make_creative_assets.py)과 맞춘다.
THEME = dict(bg="#FBEBD7", ink="#2A2420", sub="#7A6656", dark_bg="#2A2420", dark_ink="#FBEBD7",
             dark_sub="#C9B29C", frame="#2A2420", rim="#5a4a3e", glow="rgba(217,72,43,.30)")

BASE_CSS = """
* { margin:0; padding:0; box-sizing:border-box; }
html,body { width:%(W)dpx; height:%(H)dpx; overflow:hidden; }
body { background:%(bg)s; font-family:-apple-system, "Apple SD Gothic Neo", "Hiragino Sans", sans-serif; position:relative; }
.headline { font-size:96px; font-weight:800; color:%(ink)s; letter-spacing:-2px; line-height:1.22; text-wrap:balance; }
.sub { font-size:50px; font-weight:500; color:%(sub)s; letter-spacing:-1px; line-height:1.35; text-wrap:balance; }
:lang(ko) .headline, :lang(ko) .sub { word-break:keep-all; }
.phone { background:%(frame)s; border-radius:112px; border:3px solid %(rim)s; padding:24px;
  box-shadow: 60px 90px 120px rgba(0,0,0,.24), 20px 30px 50px rgba(0,0,0,.14); }
.phone img { width:100%%; display:block; border-radius:89px; }
"""

LAYOUTS = {
    "hero-bleed": """
.headline { text-align:center; margin-top:270px; padding:0 70px; }
.sub { text-align:center; margin-top:46px; padding:0 80px; }
.wrap { display:flex; justify-content:center; margin-top:130px; }
.phone { width:970px; }
""",
    "left-text": """
.headline { text-align:left; margin:280px 90px 0 105px; }
.sub { text-align:left; margin:44px 90px 0 109px; }
.wrap { perspective:2600px; perspective-origin:30% 30%; position:absolute; left:290px; top:960px; }
.phone { width:815px; transform:rotateY(16deg) rotateX(2deg); }
""",
    "text-bottom": """
.wrap { perspective:2800px; perspective-origin:50% 40%; display:flex; justify-content:center; margin-top:160px; }
.phone { width:850px; transform:rotateY(-10deg) rotateX(2deg); }
.headline { text-align:center; margin-top:110px; padding:0 70px; }
.sub { text-align:center; margin-top:44px; padding:0 80px; }
""",
    "flat-rotate": """
.headline { text-align:center; margin-top:250px; padding:0 70px; }
.sub { text-align:center; margin-top:46px; padding:0 80px; }
.wrap { position:absolute; left:115px; top:980px; }
.phone { width:980px; transform:rotate(-6deg); }
""",
    "dark": """
body { background:%(dark_bg)s; }
.headline { color:%(dark_ink)s; text-align:center; margin-top:270px; padding:0 70px; }
.sub { color:%(dark_sub)s; text-align:center; margin-top:46px; padding:0 80px; }
.wrap { display:flex; justify-content:center; margin-top:130px; }
.phone { width:900px; border-color:#48484e; box-shadow: 0 0 160px %(glow)s, 40px 70px 110px rgba(0,0,0,.55); }
""",
}

TEXT_FIRST = '<div class="headline">{h}</div><div class="sub">{s}</div><div class="wrap"><div class="phone"><img src="{img}"></div></div>'
PHONE_FIRST = '<div class="wrap"><div class="phone"><img src="{img}"></div></div><div class="headline">{h}</div><div class="sub">{s}</div>'
HTML = '<!doctype html><html lang="{lang}"><head><meta charset="utf-8"><style>{css}</style></head><body>{body}</body></html>'


def raw_for(lang, fname):
    p = RAW / lang / fname
    return p if p.exists() else RAW / fname


def main(langs):
    tmp = pathlib.Path(tempfile.mkdtemp())
    vals = dict(THEME, W=W, H=H)
    for lang in langs:
        out_dir = OUT / STORE[lang]
        out_dir.mkdir(parents=True, exist_ok=True)
        for fname, layout, texts in SHOTS:
            h, s = texts[lang]
            src = raw_for(lang, fname)
            assert src.exists(), f"원본 없음: {src}"
            tpl = PHONE_FIRST if layout == "text-bottom" else TEXT_FIRST
            css = BASE_CSS % vals + LAYOUTS[layout] % vals if "%(" in LAYOUTS[layout] else BASE_CSS % vals + LAYOUTS[layout]
            html = tmp / f"{lang}-{fname}.html"
            html.write_text(HTML.format(lang=lang, css=css, body=tpl.format(h=h, s=s, img=src.as_uri())), encoding="utf-8")
            out = out_dir / fname
            # Chrome 은 그림을 다 쓰고도 안 끝나거나, 아무것도 안 그리고 끝날 때가 있다.
            # 파일이 생기고 크기가 멈추면 다 된 것으로 보고 닫는다. 세 번까지 한다.
            for _ in range(3):
                out.unlink(missing_ok=True)
                proc = subprocess.Popen([CHROME, "--headless=new", f"--screenshot={out}", f"--window-size={W},{H}",
                                         "--force-device-scale-factor=1", "--hide-scrollbars", "--disable-gpu",
                                         "--no-first-run", "--disable-extensions", "--disable-background-networking",
                                         "--virtual-time-budget=3000", "--allow-file-access-from-files",
                                         f"--user-data-dir={tmp / 'chrome'}", html.as_uri()],
                                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                size, deadline = -1, time.time() + 90
                while time.time() < deadline:
                    time.sleep(1)
                    now = out.stat().st_size if out.exists() else -1
                    if now > 0 and now == size:
                        break
                    if proc.poll() is not None and now <= 0:
                        break
                    size = now
                proc.kill(); proc.wait()
                if out.exists() and out.stat().st_size > 0:
                    break
            else:
                raise SystemExit(f"Chrome 이 그리지 못했다: {out}")
            print("rendered", out.relative_to(ROOT))


if __name__ == "__main__":
    main(sys.argv[1:] or list(STORE))
