#!/usr/bin/env python3
"""Generate the NeKo VPN launcher icons, adaptive foreground and TV banner.

The artwork is drawn programmatically so the repository stays free of binary
source files. Requires Pillow:  python -m pip install pillow
Run from the repository root:  python tools/generate_icons.py
"""
from __future__ import annotations

import math
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "V2rayNG" / "app" / "src" / "main" / "res"
ASSETS = ROOT / "assets"

S = 1024  # master artwork size
SS = 2  # supersampling factor for the master artwork

# Palette
BG_TOP = (10, 14, 24)
BG_BOTTOM = (26, 15, 46)
SHIELD_TOP = (15, 22, 40)
SHIELD_BOTTOM = (30, 18, 56)
CYAN = (34, 211, 238)
VIOLET = (168, 85, 247)
CAT = (245, 243, 255)
CAT_SHADE = (221, 214, 254)
EAR_INNER = (196, 181, 253)
EYE = (34, 211, 238)
EYE_DARK = (76, 29, 149)
NOSE = (251, 113, 133)
WHISKER = (167, 139, 250)


def lerp(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def vertical_gradient(size: tuple[int, int], top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    w, h = size
    img = Image.new("RGB", size)
    draw = ImageDraw.Draw(img)
    for y in range(h):
        draw.line([(0, y), (w, y)], fill=lerp(top, bottom, y / max(1, h - 1)))
    return img


def horizontal_gradient(size: tuple[int, int], left: tuple[int, int, int], right: tuple[int, int, int]) -> Image.Image:
    w, h = size
    img = Image.new("RGB", size)
    draw = ImageDraw.Draw(img)
    for x in range(w):
        draw.line([(x, 0), (x, h)], fill=lerp(left, right, x / max(1, w - 1)))
    return img


def cubic(p0, p1, p2, p3, steps=48):
    pts = []
    for i in range(1, steps + 1):
        t = i / steps
        u = 1 - t
        x = u * u * u * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t * t * t * p3[0]
        y = u * u * u * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t * t * t * p3[1]
        pts.append((x, y))
    return pts


def quad(p0, p1, p2, steps=24):
    pts = []
    for i in range(1, steps + 1):
        t = i / steps
        u = 1 - t
        x = u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0]
        y = u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1]
        pts.append((x, y))
    return pts


def shield_path(scale: float = 1.0, center=(512, 540)):
    left, right = 190, 834
    top, shoulder, tip = 196, 560, 886
    r = 42

    pts = [(left + r, top), (right - r, top)]
    pts += quad((right - r, top), (right, top), (right, top + r))
    pts += [(right, shoulder)]
    pts += cubic((right, shoulder), (right, 704), (686, 812), (512, tip))
    pts += cubic((512, tip), (338, 812), (left, 704), (left, shoulder))
    pts += [(left, top + r)]
    pts += quad((left, top + r), (left, top), (left + r, top))

    if scale != 1.0:
        cx, cy = center
        pts = [(cx + (x - cx) * scale, cy + (y - cy) * scale) for x, y in pts]
    return pts


def color_layer(mask: Image.Image, color) -> Image.Image:
    layer = Image.new("RGBA", mask.size, color if len(color) == 4 else (*color, 255))
    layer.putalpha(mask)
    return layer


def draw_shield_art(size: int = S) -> Image.Image:
    """Shield + cat on a transparent canvas, cropped to the artwork bounds."""
    w = h = size * SS
    art = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(art)

    outer = [(x * SS, y * SS) for x, y in shield_path()]
    inner = [(x * SS, y * SS) for x, y in shield_path(0.925)]

    border_mask = Image.new("L", (w, h), 0)
    bd = ImageDraw.Draw(border_mask)
    bd.polygon(outer, fill=255)
    bd.polygon(inner, fill=0)

    # Soft neon glow around the shield
    glow_mask = border_mask.filter(ImageFilter.GaussianBlur(28 * SS))
    glow = color_layer(glow_mask, (*VIOLET, 220))
    art.alpha_composite(glow)
    glow2 = color_layer(border_mask.filter(ImageFilter.GaussianBlur(9 * SS)), (*CYAN, 180))
    art.alpha_composite(glow2)

    # Border gradient
    border = vertical_gradient((w, h), CYAN, VIOLET).convert("RGBA")
    border.putalpha(border_mask)
    art.alpha_composite(border)

    # Shield body
    body_mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(body_mask).polygon(inner, fill=255)
    body = vertical_gradient((w, h), SHIELD_TOP, SHIELD_BOTTOM).convert("RGBA")
    body.putalpha(body_mask)
    art.alpha_composite(body)

    # Subtle inner rim highlight
    rim = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(rim).line(inner + [inner[0]], fill=(255, 255, 255, 26), width=3 * SS)
    art.alpha_composite(rim)

    # ---- Cat ----
    def e(v):
        return v * SS

    # ears (behind the head)
    left_ear = [(356, 476), (386, 258), (510, 402)]
    right_ear = [(668, 476), (638, 258), (514, 402)]
    for ear in (left_ear, right_ear):
        draw.polygon([(e(x), e(y)) for x, y in ear], fill=CAT)

    # inner ears
    draw.polygon([(e(x), e(y)) for x, y in [(400, 438), (414, 318), (474, 408)]], fill=EAR_INNER)
    draw.polygon([(e(x), e(y)) for x, y in [(624, 438), (610, 318), (550, 408)]], fill=EAR_INNER)

    # head
    draw.ellipse([e(354), e(372), e(670), e(706)], fill=CAT)

    # cheek shading
    draw.ellipse([e(372), e(556), e(652), e(700)], fill=CAT_SHADE)
    draw.ellipse([e(372), e(536), e(652), e(690)], fill=CAT)

    # eyes
    for cx in (450, 574):
        draw.ellipse([e(cx - 36), e(508), e(cx + 36), e(584)], fill=EYE_DARK)
        draw.ellipse([e(cx - 28), e(516), e(cx + 28), e(576)], fill=EYE)
        draw.ellipse([e(cx - 7), e(518), e(cx + 7), e(574)], fill=(8, 12, 24))
        draw.ellipse([e(cx - 20), e(524), e(cx - 8), e(538)], fill=(255, 255, 255))

    # nose
    draw.polygon([(e(498), e(610)), (e(526), e(610)), (e(512), e(629))], fill=NOSE)
    # mouth
    mouth = [(512, 629), (500, 642), (488, 637)]
    draw.line([(e(x), e(y)) for x, y in mouth], fill=(109, 40, 217), width=6 * SS, joint="curve")
    mouth = [(512, 629), (524, 642), (536, 637)]
    draw.line([(e(x), e(y)) for x, y in mouth], fill=(109, 40, 217), width=6 * SS, joint="curve")

    # whiskers
    whiskers = [
        [(392, 590), (306, 572)], [(394, 612), (300, 612)], [(392, 634), (310, 652)],
        [(632, 590), (718, 572)], [(630, 612), (724, 612)], [(632, 634), (714, 652)],
    ]
    for line in whiskers:
        draw.line([(e(x), e(y)) for x, y in line], fill=(*WHISKER, 220), width=5 * SS)

    art = art.resize((size, size), Image.LANCZOS)
    # Crop to the visible artwork (glow included) and add a small margin.
    bbox = art.getbbox()
    pad = 18
    box = (max(0, bbox[0] - pad), max(0, bbox[1] - pad),
           min(size, bbox[2] + pad), min(size, bbox[3] + pad))
    return art.crop(box)


def paste_art(canvas: Image.Image, art: Image.Image, target_h: float, center=None) -> None:
    w, h = canvas.size
    scale = target_h / art.height
    new_size = (max(1, round(art.width * scale)), max(1, round(art.height * scale)))
    art = art.resize(new_size, Image.LANCZOS)
    cx, cy = center or (w // 2, h // 2)
    canvas.alpha_composite(art, (round(cx - art.width / 2), round(cy - art.height / 2)))


def legacy_icon(round_icon: bool) -> Image.Image:
    img = vertical_gradient((S, S), BG_TOP, BG_BOTTOM).convert("RGBA")
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([140, 120, 884, 900], fill=(124, 58, 237, 90))
    glow = glow.filter(ImageFilter.GaussianBlur(120))
    img.alpha_composite(glow)

    mask = Image.new("L", (S, S), 0)
    md = ImageDraw.Draw(mask)
    if round_icon:
        md.ellipse([0, 0, S - 1, S - 1], fill=255)
    else:
        md.rounded_rectangle([0, 0, S - 1, S - 1], radius=176, fill=255)
    img.putalpha(mask)

    art = draw_shield_art(S)
    paste_art(img, art, target_h=S * 0.82)
    return img


def adaptive_foreground() -> Image.Image:
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    art = draw_shield_art(S)
    paste_art(img, art, target_h=S * 0.58)
    return img


def monochrome_icon() -> Image.Image:
    size = S
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)

    outer = shield_path()
    inner = shield_path(0.90)
    d.polygon(outer, fill=255)
    d.polygon(inner, fill=0)

    # cat silhouette
    d.polygon([(356, 476), (386, 258), (510, 402)], fill=255)
    d.polygon([(668, 476), (638, 258), (514, 402)], fill=255)
    d.ellipse([354, 372, 670, 706], fill=255)

    # cut out the eyes so the themed icon reads as a cat
    d.ellipse([414, 508, 486, 584], fill=0)
    d.ellipse([538, 508, 610, 584], fill=0)

    # crop + center like the foreground
    bbox = mask.getbbox()
    pad = 18
    mask = mask.crop((max(0, bbox[0] - pad), max(0, bbox[1] - pad),
                      min(size, bbox[2] + pad), min(size, bbox[3] + pad)))
    canvas = Image.new("L", (size, size), 0)
    scale = (size * 0.58) / mask.height
    mask = mask.resize((round(mask.width * scale), round(mask.height * scale)), Image.LANCZOS)
    canvas.paste(mask, ((size - mask.width) // 2, (size - mask.height) // 2))

    out = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    out.putalpha(canvas)
    return out


def notification_icon(color: tuple[int, int, int]) -> Image.Image:
    mono = monochrome_icon()
    bbox = mono.getbbox()
    glyph = mono.crop(bbox)
    canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    scale = 236 / max(glyph.size)
    glyph = glyph.resize((max(1, round(glyph.width * scale)),
                          max(1, round(glyph.height * scale))), Image.LANCZOS)
    layer = Image.new("RGBA", glyph.size, (*color, 255))
    layer.putalpha(glyph.getchannel("A"))
    canvas.alpha_composite(layer, ((256 - glyph.width) // 2, (256 - glyph.height) // 2))
    return canvas


def banner_art(with_background: bool) -> Image.Image:
    w, h = 640, 360
    if with_background:
        img = horizontal_gradient((w, h), (10, 14, 24), (28, 16, 48)).convert("RGBA")
        glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(glow).ellipse([-60, 20, 360, 440], fill=(124, 58, 237, 110))
        img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(60)))
    else:
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    # Keep everything inside the central 80%: the adaptive banner applies a
    # 10% inset on each side before drawing the foreground.
    art = draw_shield_art(1024)
    paste_art(img, art, target_h=h * 0.66, center=(190, h // 2))

    font_path = "C:/Windows/Fonts/arialbd.ttf"
    if not os.path.exists(font_path):
        font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
    d = ImageDraw.Draw(img)
    d.text((320, 116), "NeKo VPN", font=ImageFont.truetype(font_path, 46),
           fill=(245, 243, 255, 255))
    d.text((324, 182), "Xray  •  VLESS / VMess", font=ImageFont.truetype(font_path, 17),
           fill=(167, 139, 250, 255))
    return img


def banner() -> Image.Image:
    return banner_art(True).resize((320, 180), Image.LANCZOS)


def main() -> None:
    ASSETS.mkdir(exist_ok=True)

    master = legacy_icon(round_icon=False)
    master.save(ASSETS / "neko-icon-1024.png")

    densities = {
        "mdpi": 1,
        "hdpi": 1.5,
        "xhdpi": 2,
        "xxhdpi": 3,
        "xxxhdpi": 4,
    }

    square = legacy_icon(round_icon=False)
    round_ = legacy_icon(round_icon=True)
    fg = adaptive_foreground()
    mono = monochrome_icon()

    for name, factor in densities.items():
        folder = RES / f"mipmap-{name}"
        folder.mkdir(parents=True, exist_ok=True)
        legacy_size = round(48 * factor)
        adaptive_size = round(108 * factor)
        square.resize((legacy_size, legacy_size), Image.LANCZOS).save(folder / "ic_launcher.png")
        round_.resize((legacy_size, legacy_size), Image.LANCZOS).save(folder / "ic_launcher_round.png")
        fg.resize((adaptive_size, adaptive_size), Image.LANCZOS).save(folder / "ic_launcher_foreground.png")
        mono.resize((adaptive_size, adaptive_size), Image.LANCZOS).save(folder / "ic_launcher_monochrome.png")

        drawable = RES / f"drawable-{name}"
        drawable.mkdir(parents=True, exist_ok=True)
        status_size = round(24 * factor)
        notification_icon((255, 255, 255)).resize((status_size, status_size), Image.LANCZOS).save(
            drawable / "ic_stat_name.png")
        notification_icon((0, 0, 0)).resize((status_size, status_size), Image.LANCZOS).save(
            drawable / "ic_stat_name_black.png")

    banner_img = banner()
    banner_folder = RES / "mipmap-xhdpi"
    banner_folder.mkdir(parents=True, exist_ok=True)
    banner_img.save(banner_folder / "ic_banner.png")

    # TV adaptive banner foreground: transparent version of the banner artwork.
    banner_art(False).resize((320, 180), Image.LANCZOS).save(
        banner_folder / "ic_banner_foreground.png")

    # Preview sheet for quick visual review.
    sheet = Image.new("RGBA", (1120, 720), (32, 33, 36, 255))
    sheet.alpha_composite(square.resize((256, 256), Image.LANCZOS), (40, 60))
    sheet.alpha_composite(fg.resize((256, 256), Image.LANCZOS), (340, 60))
    sheet.alpha_composite(round_.resize((256, 256), Image.LANCZOS), (640, 60))
    sheet.alpha_composite(mono.resize((256, 256), Image.LANCZOS), (820, 60))
    sheet.alpha_composite(banner_img.resize((640, 360), Image.LANCZOS), (40, 340))
    sheet.save(ASSETS / "neko-icon-preview.png")

    print("Icons written to", RES)


if __name__ == "__main__":
    main()
