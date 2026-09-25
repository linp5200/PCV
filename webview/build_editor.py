#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""PCV WebView 编辑器构建脚本

流程：
  1. esbuild 打包 src/main.js（CodeMirror 6 全家桶）→ dist/editor.js
  2. 组装单文件 HTML：index.html + @font-face（woff2→base64） + 内联 JS
     → ../../assets/webview/editor.html（Flutter 侧一次 loadString 直接用）

依赖：node + npm（webview/ 下 npm install 一次）；本脚本不依赖网络。
用法：python3 build_editor.py
"""
import base64
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, "..", "assets", "webview", "editor.html"))


def run(cmd, cwd):
    print("$", " ".join(cmd))
    r = subprocess.run(cmd, cwd=cwd)
    if r.returncode != 0:
        sys.exit(f"命令失败（{r.returncode}）")


def font_face(name, weight, path):
    with open(path, "rb") as f:
        b64 = base64.b64encode(f.read()).decode("ascii")
    return (
        "@font-face {\n"
        f"  font-family: 'JetBrainsMono';\n"
        f"  font-style: normal;\n"
        f"  font-weight: {weight};\n"
        f"  src: url(data:font/woff2;base64,{b64}) format('woff2');\n"
        "}\n"
    )


def main():
    # 1) esbuild 打包
    run(
        ["npx", "esbuild", "src/main.js", "--bundle", "--minify",
         "--format=iife", "--outfile=dist/editor.js"],
        cwd=HERE,
    )

    # 2) 组装
    with open(os.path.join(HERE, "src", "index.html"), encoding="utf-8") as f:
        tpl = f.read()
    with open(os.path.join(HERE, "dist", "editor.js"), encoding="utf-8") as f:
        js = f.read()

    fonts = ""
    fp = os.path.join(HERE, "fonts")
    for fname, weight in [("JetBrainsMono-Regular.woff2", 400),
                          ("JetBrainsMono-Medium.woff2", 500)]:
        p = os.path.join(fp, fname)
        if os.path.isfile(p):
            fonts += font_face("JetBrainsMono", weight, p)
    if not fonts:
        fonts = "/* 字体缺失：回退系统等宽字体 */"

    html = tpl.replace("/*__PCV_FONTS__*/", fonts).replace("/*__PCV_JS__*/", js)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(html)

    print(f"✔ {OUT}")
    print(f"  size={os.path.getsize(OUT)/1024:.0f}KB  "
          f"(js={len(js)/1024:.0f}KB, fonts={'yes' if 'data:font' in fonts else 'no'})")


if __name__ == "__main__":
    main()
