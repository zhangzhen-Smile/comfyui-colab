#!/usr/bin/env bash
# ============================================================
# setup_models.sh —— 把模型放到 Colab 本地盘
#   策略：Drive 里有就拷贝（快、免下载），没有就回源 Hugging Face（CDN 快）
#   已存在的文件直接跳过；下载带断点续传 + sha256 校验
# 用法：
#   bash setup_models.sh              # 小模型（SD1.5，2 GB）
#   WITH_H3=1 bash setup_models.sh    # 额外拉 MiniMax H3 最小组合（37 GB）
#   SYNC_DRIVE=1 bash setup_models.sh # 下载完成后回写一份到 Drive
# ============================================================
set -uo pipefail

MODELS="${MODELS:-/content/ComfyUI/models}"
DRIVE_ROOT="${DRIVE_ROOT:-/content/drive/MyDrive/comfyui}"
WITH_H3="${WITH_H3:-0}"
SYNC_DRIVE="${SYNC_DRIVE:-0}"
HF=https://huggingface.co

have_drive=0
[ -d /content/drive/MyDrive ] && have_drive=1
echo "models=$MODELS  drive=$have_drive  h3=$WITH_H3"

mkdir -p "$MODELS"/{checkpoints,diffusion_models,text_encoders,vae,loras}

fetch() {  # $1=相对路径 $2=下载地址 $3=sha256（可空）
  local rel="$1" url="$2" sum="${3:-}"
  local dst="$MODELS/$rel"
  if [ -s "$dst" ]; then
    echo "[skip] $rel"
  else
    mkdir -p "$(dirname "$dst")"
    if [ "$have_drive" = 1 ] && [ -s "$DRIVE_ROOT/models/$rel" ]; then
      echo "[drive] $rel  <- $DRIVE_ROOT/models/$rel"
      cp "$DRIVE_ROOT/models/$rel" "$dst" || return 1
    else
      echo "[hf] $rel"
      curl -fL --retry 3 --retry-delay 3 -C - -o "$dst.part" "$url" || { echo "download failed: $rel"; return 1; }
      mv "$dst.part" "$dst"
    fi
  fi
  if [ -n "$sum" ]; then
    echo "$sum  $dst" | sha256sum -c - >/dev/null || { echo "!! sha256 mismatch: $rel"; rm -f "$dst"; return 1; }
  fi
  if [ "$SYNC_DRIVE" = 1 ] && [ "$have_drive" = 1 ]; then
    mkdir -p "$DRIVE_ROOT/models/$(dirname "$rel")"
    [ -s "$DRIVE_ROOT/models/$rel" ] || cp "$dst" "$DRIVE_ROOT/models/$rel"
  fi
}

# ---------- 小模型：SD1.5（2.1 GB）----------
fetch checkpoints/Counterfeit-V2.5_fp16.safetensors \
  "$HF/gsdf/Counterfeit-V2.5/resolve/main/Counterfeit-V2.5_fp16.safetensors" \
  71e703a0fca0e284dd9868bca3ce63c64084db1f0d68835f0a31e1e4e5b7cca6

# ---------- 大模型：MiniMax H3 最小可用组合（37 GB）----------
if [ "$WITH_H3" = 1 ]; then
  R=Comfy-Org/MiniMax-H3/resolve/main
  fetch diffusion_models/minimax_h3_fl2va_pruned_w6a8.safetensors          "$HF/$R/diffusion_models/minimax_h3_fl2va_pruned_w6a8.safetensors"
  fetch text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors         "$HF/$R/text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors"
  fetch vae/minimax_h3_video_vae_int8_convrot.safetensors                  "$HF/$R/vae/minimax_h3_video_vae_int8_convrot.safetensors"
  fetch vae/minimax_h3_audio_vae_fp32.safetensors                          "$HF/$R/vae/minimax_h3_audio_vae_fp32.safetensors"
  fetch loras/minimax_h3_fl2v_turbo_4step_v1.0_768p_comfyui_bf16.safetensors "$HF/$R/loras/minimax_h3_fl2v_turbo_4step_v1.0_768p_comfyui_bf16.safetensors"
fi

echo "== 本地盘剩余空间 =="
df -h /content | tail -1
echo "== 已就位 =="
find "$MODELS" -maxdepth 2 -type f -size +100M -printf '%10.2f GB  %p\n' 2>/dev/null | sort -rn || true
echo "DONE"
