# 今日食咩好？ — Cloudflare Worker 靜態遊戲

這個 Worker 直接服務 Godot Web 版。因為 `index.wasm` 原始大小約 39.5 MB，超過 Cloudflare 靜態資源單檔 **25 MiB** 上限，所以：

- `public/` 只放其他靜態檔案（HTML、JS、PCK、PWA icons…）。
- wasm 以 gzip 形式放在 `public/_wasm/index.wasm.gz`（約 9.6 MB）。
- `src/index.js` 收到 `/index.wasm` 時，用 `DecompressionStream("gzip")` 即時解壓成原始 wasm 回傳。
- 瀏覽器照常 `instantiateStreaming('/index.wasm')`，不需要改 Godot loader。

## 已部署

- 遊戲：https://what-to-eat-game.leechungkit2011.workers.dev/
- 排行榜 API：https://what-to-eat-leaderboard.leechungkit2011.workers.dev/api/

## 重新部署

```powershell
# 1. 重新 build Web + 更新 public/ + gzip wasm
powershell -ExecutionPolicy Bypass -File tools\deploy_cloudflare.ps1

# 或者只更新遊戲 Worker（public 已準備好）
cd workers\game
npx wrangler deploy
```

## 注意

- `public/` 是 generated；不要手動改，重新跑 `tools/prepare_game_assets.py` 會覆蓋。
- `public/.gdignore` 係必要嘅，防止 Godot 掃描／匯出呢批靜態檔。
- `run_worker_first = ["/index.wasm"]` 只讓 Worker 攔截 wasm；其他檔案由 Cloudflare Static Assets 直接服務。
- 如果日後 Godot wasm 細過 25 MiB，可以移除 gzip 特例，直接放原始 `index.wasm`。
