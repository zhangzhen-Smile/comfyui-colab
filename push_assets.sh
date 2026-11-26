#!/usr/bin/env bash
# ============================================================
# push_assets.sh —— 把生成的文件直接提交到 GitHub 仓库
#   用法：GITHUB_TOKEN=ghp_xxx bash push_assets.sh [源目录]
#   默认源目录 /content/ComfyUI/output，默认仓库 <你>/comfyui-assets
#   超过 95 MB 的文件跳过（GitHub 单文件硬限 100 MB，改用 Release）
# ============================================================
set -uo pipefail

SRC="${1:-/content/ComfyUI/output}"
REPO="${REPO:-zhangzhen-Smile/comfyui-assets}"
BRANCH="${BRANCH:-main}"
WORK="${WORK:-/content/_assets_repo}"
MAXMB="${MAXMB:-95}"

[ -d "$SRC" ] || { echo "源目录不存在：$SRC"; exit 1; }

TOKEN="${GITHUB_TOKEN:-}"
if [ -z "$TOKEN" ] && [ -f "$HOME/.git-credentials" ]; then
  TOKEN=$(sed -n 's#https://[^:]*:\([^@]*\)@github.com#\1#p' "$HOME/.git-credentials" | head -1)
fi
[ -n "$TOKEN" ] || { echo "缺少 GITHUB_TOKEN（Colab 里用 🔑 Secrets 加一个 GH_TOKEN）"; exit 1; }

URL="https://${TOKEN}@github.com/${REPO}.git"

if [ -d "$WORK/.git" ]; then
  git -C "$WORK" remote set-url origin "$URL"
  git -C "$WORK" pull --rebase -q || true
else
  rm -rf "$WORK"
  git clone -q --depth 1 "$URL" "$WORK" 2>/dev/null || {
    echo "克隆失败：仓库 $REPO 可能不存在（先在 GitHub 上建一个空仓库，或确认 token 有 repo 权限）"
    exit 1
  }
fi

cd "$WORK" || exit 1
git config user.name  "colab-agent"
git config user.email "colab-agent@users.noreply.github.com"

n=0; skip=0
while IFS= read -r -d '' f; do
  rel="${f#$SRC/}"
  size_mb=$(( $(stat -c%s "$f") / 1024 / 1024 ))
  if [ "$size_mb" -ge "$MAXMB" ]; then
    echo "[skip] ${size_mb} MB  $rel  (超过 ${MAXMB} MB，请走 Release)"
    skip=$((skip+1)); continue
  fi
  mkdir -p "$(dirname "$rel")"
  cp -f "$f" "$rel"
  n=$((n+1))
done < <(find "$SRC" -type f ! -name '.*' -print0)

if [ "$n" -eq 0 ]; then
  echo "没有新文件需要提交（跳过 $skip 个大文件）"
  exit 0
fi

git add -A
git commit -q -m "assets: ${n} file(s) @ $(date -u '+%Y-%m-%d %H:%M UTC')" || { echo "没有变化"; exit 0; }
git push -q origin "HEAD:$BRANCH" && echo "已推送 $n 个文件 -> https://github.com/${REPO}/tree/${BRANCH}" || { echo "推送失败（token 权限？分支保护？）"; exit 1; }

echo "--- 文件直链 ---"
find . -path ./.git -prune -o -type f -print | sed 's#^\./##' | head -30 | while read -r p; do
  echo "https://github.com/${REPO}/raw/${BRANCH}/${p}"
done
