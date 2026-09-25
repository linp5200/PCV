#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""PCV 启动图标生成器（Pillow）
生成：
  mipmap-*/ic_launcher.png      传统图标（圆角深底 + 蓝色尖括号 + 青色斜杠）
  mipmap-*/ic_launcher_bg.png   自适应图标背景（纯色方形）
  mipmap-*/ic_launcher_fg.png   自适应图标前景（透明底 + 居中字形）
"""
import os
from PIL import Image, ImageDraw

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "android", "app", "src", "main", "res")
BG = (27, 30, 45)          # #1B1E2D
BLUE = (122, 162, 247)     # #7AA2F7
CYAN = (125, 207, 255)     # #7DCFFF

LEGACY = {"mipmap-mdpi": 48, "mipmap-hdpi": 72, "mipmap-xhdpi": 96,
          "mipmap-xxhdpi": 144, "mipmap-xxxhdpi": 192}
ADAPT = {"mipmap-mdpi": 108, "mipmap-hdpi": 162, "mipmap-xhdpi": 216,
         "mipmap-xxhdpi": 324, "mipmap-xxxhdpi": 432}
SS = 4  # 超采样


def draw_glyph(d, s, ox, oy, scale, lw):
    """在 (ox,oy) 处按 scale 画字形（单位坐标 -> 像素）
    scale: 单位坐标到像素的缩放（已含 S）
    lw:    线宽（直接为像素值——勿再乘 scale）
    """
    def P(u, v):
        return (ox + u * scale, oy + v * scale)

    w = max(2, int(lw))
    # 左尖括号 <
    d.line([P(0.36, 0.40), P(0.24, 0.50), P(0.36, 0.60)], fill=BLUE, width=w, joint="curve")
    # 右尖括号 >
    d.line([P(0.64, 0.40), P(0.76, 0.50), P(0.64, 0.60)], fill=BLUE, width=w, joint="curve")
    # 斜杠 /
    d.line([P(0.58, 0.375), P(0.42, 0.625)], fill=CYAN, width=w, joint="curve")
    # 圆头处理
    for (u, v), col in [((0.36, 0.40), BLUE), ((0.24, 0.50), BLUE), ((0.36, 0.60), BLUE),
                        ((0.64, 0.40), BLUE), ((0.76, 0.50), BLUE), ((0.64, 0.60), BLUE),
                        ((0.58, 0.375), CYAN), ((0.42, 0.625), CYAN)]:
        x, y = P(u, v)
        r = w / 2
        d.ellipse([x - r, y - r, x + r, y + r], fill=col)


def make_legacy(size):
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = int(S * 0.22)
    d.rounded_rectangle([0, 0, S - 1, S - 1], radius=r, fill=BG)
    # 内部微微提亮的内描边（层次感）
    d.rounded_rectangle([1, 1, S - 2, S - 2], radius=r, outline=(41, 46, 66, 90), width=max(1, S // 96))
    pad = S * 0.16
    draw_glyph(d, S, pad, pad, S - 2 * pad, 0.085 * S)
    return img.resize((size, size), Image.LANCZOS)


def make_bg(size):
    S = size * SS
    img = Image.new("RGBA", (S, S), BG)
    return img.resize((size, size), Image.LANCZOS)


def make_fg(size):
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # 字形占安全区 66%：居中区域 = 0.5 ± 0.33
    g = S * 0.62
    off = (S - g) / 2
    draw_glyph(d, S, off, off, g, 0.095 * S)
    return img.resize((size, size), Image.LANCZOS)


def main():
    out_dir = os.path.abspath(BASE)
    # 自适应目录
    anydpi = os.path.join(out_dir, "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    with open(os.path.join(anydpi, "ic_launcher.xml"), "w", encoding="utf-8") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable="@mipmap/ic_launcher_bg"/>\n'
                '    <foreground android:drawable="@mipmap/ic_launcher_fg"/>\n'
                '</adaptive-icon>\n')

    for d, s in LEGACY.items():
        os.makedirs(os.path.join(out_dir, d), exist_ok=True)
        make_legacy(s).save(os.path.join(out_dir, d, "ic_launcher.png"))
        print(f"✔ {d}/ic_launcher.png ({s}px)")
    for d, s in ADAPT.items():
        os.makedirs(os.path.join(out_dir, d), exist_ok=True)
        make_bg(s).save(os.path.join(out_dir, d, "ic_launcher_bg.png"))
        make_fg(s).save(os.path.join(out_dir, d, "ic_launcher_fg.png"))
        print(f"✔ {d}/ic_launcher_bg.png + ic_launcher_fg.png ({s}px)")
    print("图标生成完成")


if __name__ == "__main__":
    main()
