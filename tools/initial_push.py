#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""PCV · 空仓库初始推送（Git Data API）

与 git_api_push2.py 的差异：处理"远端还没有 main 引用"的情况
（409 Conflict）——上传全部 blob → 建 tree（无 base）→ 建无父 commit
→ 创建 refs/heads/main。

用法:
    python3 initial_push.py <repo_dir> [--dry]
token 从 ~/.git-credentials 读取（不打印）。
"""
import base64
import json
import os
import subprocess
import sys
import urllib.request

REPO_DIR = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else "."
DRY = "--dry" in sys.argv
GH = "https://api.github.com"


def token():
    p = os.path.expanduser("~/.git-credentials")
    for line in open(p, encoding="utf-8"):
        if "github.com" in line:
            cred = line.strip().split("://", 1)[1]
            return cred.split(":", 1)[1].split("@", 1)[0]
    raise SystemExit("未找到 github token")


TOK = token()


def api(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(GH + path, data=data, method=method)
    req.add_header("Authorization", "Bearer " + TOK)
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=90) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        print(f"!! {method} {path} -> {e.code}")
        print(detail[:800])
        raise


def git(*args):
    return subprocess.check_output(["git"] + list(args), cwd=REPO_DIR).decode().strip()


def main():
    remote = git("remote", "get-url", "origin")
    slug = remote.split("github.com/")[1].replace(".git", "").strip("/")
    print("仓库:", slug)

    # 本地索引：文件路径 -> (mode, blob sha)
    out = git("ls-files", "-s")
    lf = {}
    for line in out.splitlines():
        meta, path = line.split("\t", 1)
        mode, sha, _ = meta.split()
        lf[path] = (mode, sha)
    print("本地文件:", len(lf))

    if not lf:
        raise SystemExit("本地索引为空——先 git add/commit")

    if DRY:
        print("（--dry：不推送）")
        return

    # 1) 上传全部 blob
    tree_entries = []
    for p in sorted(lf):
        mode, sha = lf[p]
        full = os.path.join(REPO_DIR, p)
        with open(full, "rb") as f:
            content = base64.b64encode(f.read()).decode()
        blob = api("POST", "/repos/%s/git/blobs" % slug,
                   {"content": content, "encoding": "base64"})
        if blob["sha"] != sha:
            print("⚠ sha 不一致 %s" % p)
        tree_entries.append({"path": p, "mode": mode, "type": "blob", "sha": blob["sha"]})
        print("  up %-64s %s" % (p, blob["sha"][:8]))

    # 2) 建 tree（无 base——全新）
    tree = api("POST", "/repos/%s/git/trees" % slug, {"tree": tree_entries})

    # 3) 建 commit（无父）
    msg = git("log", "-1", "--pretty=%B")
    commit = api("POST", "/repos/%s/git/commits" % slug,
                 {"message": msg, "tree": tree["sha"], "parents": []})
    print("新 commit:", commit["sha"][:8])

    # 4) 创建 main ref
    api("POST", "/repos/%s/git/refs" % slug,
        {"ref": "refs/heads/main", "sha": commit["sha"]})
    print("✅ 初始推送成功 main -> %s" % commit["sha"][:8])

    ref2 = api("GET", "/repos/%s/git/ref/heads/main" % slug)
    if ref2["object"]["sha"] == commit["sha"]:
        print("✓ 验证通过：远端 main =", commit["sha"][:8])
    else:
        print("⚠ 验证失败：远端为", ref2["object"]["sha"][:8])


if __name__ == "__main__":
    main()
