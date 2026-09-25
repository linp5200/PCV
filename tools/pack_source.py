#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""PCV 内置源码打包器 · 自定义 PAK 容器

格式（v1）:
    [MAGIC "PCVPAK1\\n"]                       8 字节
    [index_len 10 位 ASCII 数字 + "\\n"]       11 字节
    [JSON index（UTF-8）]
    [文件数据区：按 index 顺序拼接]

JSON index:
    {"format":1,"name":"...","version":"...","commit":"...","built_at":"...",
     "file_count":N,"byte_count":N,"files":[{"p":相对路径,"o":偏移,"l":长度},...]}

整体再 gzip 压缩。Dart 侧只用 dart:io 的 gzip 解码（零第三方依赖）。

用法:
    python3 pack_source.py <源码目录> <输出.pak.gz> [--name lingos-source] [--commit SHA]
"""
import gzip
import json
import os
import subprocess
import sys
import time

MAGIC = b"PCVPAK1\n"
SKIP_EXTS = {".png", ".jpg", ".jpeg", ".gif", ".ico", ".so", ".a", ".o",
             ".bin", ".gz", ".zip", ".jks", ".ttf", ".woff", ".woff2", ".pak"}


def main():
    src = os.path.abspath(sys.argv[1])
    out = os.path.abspath(sys.argv[2])
    name = "lingos-source"
    commit = ""
    if "--name" in sys.argv:
        name = sys.argv[sys.argv.index("--name") + 1]
    if "--commit" in sys.argv:
        commit = sys.argv[sys.argv.index("--commit") + 1]

    # 版本号：VERSION 文件
    version = ""
    vf = os.path.join(src, "VERSION")
    if os.path.isfile(vf):
        with open(vf, encoding="utf-8") as f:
            version = f.read().strip()

    # 收集文件（相对路径排序，跳过二进制扩展）
    rels = []
    for root, dirs, files in os.walk(src):
        dirs[:] = [d for d in dirs if d not in (".git",)]
        for fn in files:
            full = os.path.join(root, fn)
            rel = os.path.relpath(full, src).replace(os.sep, "/")
            ext = os.path.splitext(fn)[1].lower()
            if ext in SKIP_EXTS:
                continue
            rels.append(rel)
    rels.sort()

    # 数据区
    data = bytearray()
    files = []
    for rel in rels:
        full = os.path.join(src, rel)
        with open(full, "rb") as f:
            b = f.read()
        files.append({"p": rel, "o": len(data), "l": len(b)})
        data += b

    index = {
        "format": 1,
        "name": name,
        "version": version,
        "commit": commit,
        "built_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "file_count": len(files),
        "byte_count": len(data),
        "files": files,
    }
    index_bytes = json.dumps(index, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    if len(index_bytes) >= 10 ** 10:
        raise SystemExit("index 过大")

    raw = MAGIC + f"{len(index_bytes):010d}\n".encode("ascii") + index_bytes + bytes(data)

    with open(out, "wb") as f:
        f.write(gzip.compress(raw, compresslevel=9))

    pok = os.path.getsize(out)
    print(f"✔ {out}")
    print(f"  name={name} version={version} commit={commit}")
    print(f"  files={len(files)} raw={len(raw)/1e6:.2f}MB pak={pok/1e6:.2f}MB "
          f"ratio={pok/len(raw)*100:.1f}%")


if __name__ == "__main__":
    main()
