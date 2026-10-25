# Cloudflare Workers + D1 線上排行榜

處理「每日挑戰」成績、朋友食譜分享、讚好與人氣獎勵。遊戲本身仍有本機排行榜；API 掛咗／離線時會自動 fallback。

## API

- `POST /api/leaderboard`：每日挑戰成績
- `GET /api/leaderboard?date=YYYYMMDD&limit=10`：指定日期 Top 10
- `POST /api/recipes`：發佈自創食譜（可帶 `method`：`pan_fry`／`deep_fry`／`braise`／`stew`／`bake`／`steam`）
- `GET /api/recipes?limit=20`：朋友食譜（匿名，按讚好排序，會回傳 `method`）
- `POST /api/recipes/:id/like`：讚好（每裝置每食譜一次，不可自讚）
- `GET /api/rewards?device_id=...`：創作者收到嘅總讚好（用嚟派人氣預算）

## 免費額度

- Workers：100,000 requests／日、10ms CPU／次
- D1：5,000,000 rows read／日、100,000 rows written／日、5GB 儲存
- 免費 plan 係 hard cap，超過會出 error，唔會自動收費

## 本機測試

```powershell
cd workers\leaderboard
npx wrangler d1 execute what-to-eat-leaderboard --local --file=./schema.sql
npx wrangler dev --local --port 8787
```

API：

```text
GET  http://127.0.0.1:8787/api/leaderboard?date=20261025
POST http://127.0.0.1:8787/api/leaderboard
```

測試 POST：

```powershell
$body = @{
  device_id = "0123456789abcdef0123456789abcdef"
  date_key = (Get-Date).ToUniversalTime().ToString("yyyyMMdd")
  stats = @{ body = 70; vitc = 70; vitd = 70; fiber = 70; mood = 70 }
  savings = 20
  distinct = 10
  perfect = 6
  burnt = 1
  favourite = "番茄炒蛋"
} | ConvertTo-Json

Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8787/api/leaderboard" `
  -ContentType "application/json" -Body $body
```

再 call 一次會回 `409 already_submitted`（每日每裝置一次）。

## 部署

目前已部署：

- 遊戲：`https://what-to-eat-game.leechungkit2011.workers.dev/`（`workers/game/`）
- API：`https://what-to-eat-leaderboard.leechungkit2011.workers.dev/api/`
- Worker：`what-to-eat-leaderboard`
- D1：`what-to-eat-leaderboard`（database id `396b2609-2639-41d9-8e5b-dbeeff65cfaa`，APAC）
- `ALLOWED_ORIGIN`：`https://what-to-eat-game.leechungkit2011.workers.dev,http://127.0.0.1:8000,http://localhost:8000`

重新部署：

```powershell
cd workers\leaderboard
npx wrangler login
npx wrangler d1 execute what-to-eat-leaderboard --remote --file=./schema.sql
npx wrangler deploy
```

部署後將 `wrangler.toml` 的 `ALLOWED_ORIGIN` 改成你隻遊戲嘅網址，再 `npx wrangler deploy` 一次。

如果同時要更新遊戲靜態版，喺專案根目錄跑：

```powershell
powershell -ExecutionPolicy Bypass -File tools\deploy_cloudflare.ps1
```

如果之前已經部署過舊版（`recipes` 表未有 `method`），先跑一次遷移：

```powershell
npx wrangler d1 execute what-to-eat-leaderboard --remote --file=./migrations/002_recipe_method.sql
```

## 接落遊戲

`what_to_eat/config/online.cfg`（目前正式設定）：

```ini
[online]
; production Cloudflare Worker
endpoint="https://what-to-eat-leaderboard.leechungkit2011.workers.dev/api/leaderboard"
enabled=true
```

改完 config 要重新 export Web build。

如果想用同源（Pages + Worker route），可以將 endpoint 留空：

```ini
[online]
endpoint=""
enabled=true
```

如果遊戲放喺 `https://game.example.com`、Worker 喺 `https://api.example.com`：

1. 遊戲 config：`endpoint="https://api.example.com/api/leaderboard"`
2. Worker `ALLOWED_ORIGIN="https://game.example.com"`

## 防刷範圍

已做：

- 匿名 device id + `UNIQUE(device_id, date_key)`：每日每裝置只可提交一次
- 日期只接受 UTC 今日起 14 日內（容許 7 日 run 跨日完成）
- 分數由 stats 重新計算，grade 由伺服器決定
- stats 0–100、儲蓄 0–600、菜式數 0–27、完美／燶 0–21
- 食譜：名稱／材料白名單／form／method／顏色嚴格驗證，只回傳匿名資料
- 讚好：每裝置每食譜一次，server 拒絕自讚
- 人氣獎勵：客戶端比較 `/api/rewards` 總數，有新讚好才加 10 日
- body 4KB 上限、JSON schema 檢查
- 每 IP 每分鐘 POST 6 次、GET 60 次（in-memory，isolate 內有效）
- 只回傳匿名排名，不公開 device id

限制：

- 遊戲係 client-authoritative；改機／改 JS 仍然可以偽造成績。真正防作弊需要 server-side replay 或簽名驗證，成本高很多。
- 匿名 device id 可以清除／重裝再刷；呢個係休閒遊戲嘅取捨。
- Cloudflare 免費 plan 係 hard cap，唔會自動收費；付費 plan 要小心 D1 row writes。

## API 回傳

GET：

```json
{"ok":true,"date":"20261025","total":12,"entries":[
  {"rank":1,"average":86.4,"grade":"S","savings":27,"favourite":"香煎三文魚飯","distinct":14,"perfect":9,"burnt":1}
]}
```

POST 成功：

```json
{"ok":true,"rank":3,"total":12,"average":76.2,"grade":"A"}
```

POST 重複：

```json
{"ok":false,"error":"already_submitted"}
```
