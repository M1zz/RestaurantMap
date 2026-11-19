#!/usr/bin/env python3
"""앱 아이콘을 그린다 — 짙은 바탕 · 접시 모양 위치 핀 · 금빛 별.

  python3 scripts/make_app_icon.py

세 곳에 바로 쓴다.
- RestaurantMap/AppIcon.icon      iOS 유리 질감 아이콘(아이콘 컴포저 형식). 층: 핀 · 접시 · 별
- Assets.xcassets/AppIcon.appiconset   유리 질감이 없는 한 장(홍보 그림 · 예전 iOS 용)
- Assets.xcassets/AppIcon.solidimagestack   visionOS 3단 아이콘(바탕 · 핀 · 별)
"""
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

S = 4                      # 크게 그린 뒤 줄여 가장자리를 매끈하게
N = 1024 * S
ASSETS = Path(__file__).resolve().parent.parent / "RestaurantMap/Assets.xcassets"

def rgb(h): return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))
def box(*v): return [x * S for x in v]
def mask(): return Image.new("L", (N, N), 0)

def gradient(top, bottom):
    g = Image.linear_gradient("L").resize((N, N))
    return Image.composite(Image.new("RGB", (N, N), rgb(bottom)), Image.new("RGB", (N, N), rgb(top)), g)

def soften(m, r):
    """모서리를 r 만큼 둥글린다."""
    return m.filter(ImageFilter.GaussianBlur(r * S)).point(lambda v: 255 if v > 127 else 0)

def pin(cx, cy, r, tip):
    m = mask(); d = ImageDraw.Draw(m)
    a = math.acos(r / (tip - cy))
    lx, rx, ty = cx - r * math.sin(a), cx + r * math.sin(a), cy + r * math.cos(a)
    d.ellipse(box(cx - r, cy - r, cx + r, cy + r), fill=255)
    d.polygon(box(cx, tip, lx, ty, rx, ty), fill=255)
    return soften(m, 10)

def star(cx, cy, R):
    pts = []
    for i in range(10):
        rad = R if i % 2 == 0 else R * 0.5
        ang = -math.pi / 2 + i * math.pi / 5
        pts += [cx + rad * math.cos(ang), cy + rad * math.sin(ang)]
    m = mask(); ImageDraw.Draw(m).polygon(box(*pts), fill=255)
    return soften(m, 9)

def disc(cx, cy, r):
    m = mask(); ImageDraw.Draw(m).ellipse(box(cx - r, cy - r, cx + r, cy + r), fill=255)
    return m

def ring(cx, cy, r, width):
    m = mask(); ImageDraw.Draw(m).ellipse(box(cx - r, cy - r, cx + r, cy + r), outline=255, width=width * S)
    return m

def layer(*parts):
    """(마스크, 색 또는 그러데이션) 들을 투명 바탕 위에 차례로 얹는다."""
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    for m, fill in parts:
        fill = fill if isinstance(fill, Image.Image) else Image.new("RGB", (N, N), rgb(fill))
        img.paste(fill, (0, 0), m)
    return img

def save(img, path):
    img.resize((1024, 1024), Image.LANCZOS).save(path)
    print(path.relative_to(ASSETS.parent.parent))

TOP, BOTTOM = "#3B2A22", "#1E1411"
back = gradient(TOP, BOTTOM)
pin_only = layer((pin(512, 445, 295, 880), "#FFF6E8"))
plate = layer((disc(512, 445, 225), "#FFFDF8"))
middle = layer((pin(512, 445, 295, 880), "#FFF6E8"), (ring(512, 445, 225, 9), "#E6D3B5"))
front = layer((star(512, 453, 150), gradient("#FFC83D", "#F59A1B")))

flat = back.copy()
flat.paste(middle, (0, 0), middle)
flat.paste(front, (0, 0), front)

save(flat, ASSETS / "AppIcon.appiconset/AppIcon.png")
stack = ASSETS / "AppIcon.solidimagestack"
save(back, stack / "Back.solidimagestacklayer/Content.imageset/Back.png")
save(middle, stack / "Middle.solidimagestacklayer/Content.imageset/Middle.png")
save(front, stack / "Front.solidimagestacklayer/Content.imageset/Front.png")

# 유리 질감 아이콘 — 위에 적은 묶음이 앞에 온다. 접시 테두리는 선으로 긋지 않고 유리 가장자리 빛에 맡긴다.
icon = ASSETS.parent / "AppIcon.icon"
(icon / "Assets").mkdir(parents=True, exist_ok=True)
save(pin_only, icon / "Assets/pin.png")
save(plate, icon / "Assets/plate.png")
save(front, icon / "Assets/star.png")

def p3(h): return "display-p3:" + ",".join(f"{v / 255:.5f}" for v in rgb(h)) + ",1.00000"
def group(name, image, shadow, opacity):
    return {
        "layers": [{"glass": True, "image-name-specializations": [{"value": image}], "name": image.split(".")[0]}],
        "lighting": "individual", "name": name,
        "shadow": {"kind": shadow, "opacity": opacity},
        "specular": True, "translucency": {"enabled": False, "value": 0.5},
    }
(icon / "icon.json").write_text(json.dumps({
    "fill-specializations": [{"value": {
        "linear-gradient": [p3(TOP), p3(BOTTOM)],
        "orientation": {"start": {"x": 0.5, "y": 0}, "stop": {"x": 0.5, "y": 1}},
    }}],
    "groups": [
        group("별", "star.png", "layer-color", 0.6),
        group("접시", "plate.png", "neutral", 0.35),
        group("핀", "pin.png", "neutral", 0.5),
    ],
    "supported-platforms": {"squares": "shared"},
}, ensure_ascii=False, indent=2) + "\n")
print("RestaurantMap/AppIcon.icon/icon.json")
