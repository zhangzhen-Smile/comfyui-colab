# ComfyUI + MiniMax H3 on Google Colab

**模型走 Hugging Face（大）/ Drive（小，可选），生成的作品直接推到 GitHub。**

- 一键打开：https://colab.research.google.com/github/zhangzhen-Smile/comfyui-colab/blob/main/ComfyUI_H3_Colab.ipynb
- 作品仓库：https://github.com/zhangzhen-Smile/comfyui-assets （私有，可改公开）

## 四格流程

| 格 | 做什么 | 每天要不要跑 |
|---|---|---|
| 1 | 检查 GPU，Drive 可选 | 跑 |
| 2 | 装 ComfyUI + 备模型（`WITH_H3="1"` 才拉 37 GB） | 跑（运行时重置后 /content 是空的） |
| 3 | 启动 ComfyUI + cloudflared 隧道 | 跑，断线后**只重跑这格** |
| 4 | 把 `/content/ComfyUI/output` 推到 GitHub | 出图后按需跑 |

## 为什么这么分工

Colab 每天重置的只是 `/content` 本地盘，Drive 和 Hugging Face 都不丢。

| 资源 | 放哪 | 耗时 |
|---|---|---|
| SD1.5 2 GB / LoRA / VAE | Drive 有就 `cp` 到本地盘（可选） | 30–90 s |
| H3 最小组合 37 GB | HF 流式拉（CDN 100+ MB/s） | 6–10 min |
| 生成的作品 | GitHub 仓库 `comfyui-assets` | 秒级 |
| H3 直接从 Drive 挂载读 | ❌ FUSE 顺序读 10–50 MB/s，加载 5–25 min | — |

## 一次性设置：GitHub token

1. https://github.com/settings/tokens 建一个 token，勾 `repo`（或细粒度只给 `comfyui-assets` 的 Contents: Read and write）
2. Colab 左侧 🔑 **Secrets** 里加一条：名称 `GH_TOKEN`，值填 token，打开 **Notebook access**
3. 之后跑第 4 格即可，脚本会 `clone → cp → commit → push`，并打印每个文件的 raw 直链

`push_assets.sh` 的规则：单个文件 ≥ 95 MB 跳过（GitHub 单文件硬限 100 MB，这种走 Release）；
每次提交信息带 UTC 时间；已存在的同名文件直接覆盖。

## 显存门槛

| 目标 | 最低显存 | 运行时 |
|---|---|---|
| MiniMax H3（5 s 768p，自带音频） | 24 GB（fp8/int8） | L4 / A100（Pro 起） |
| SDXL | 12 GB | T4 勉强 / L4 |
| SD1.5 | 4 GB | T4 轻松 |

## 文件

- `ComfyUI_H3_Colab.ipynb` —— 笔记本本体（4 格）
- `setup_models.sh` —— Drive 命中则拷贝、否则回源 HF，带断点续传 + sha256
- `push_assets.sh` —— 生成物推送 GitHub
