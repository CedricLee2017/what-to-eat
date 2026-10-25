-- 今日食咩好？ 每日挑戰線上排行榜
-- 一位匿名裝置每日只可提交一次；伺服器只保留排名需要的資料。

CREATE TABLE IF NOT EXISTS scores (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT NOT NULL,
  date_key TEXT NOT NULL,
  average REAL NOT NULL,
  grade TEXT NOT NULL,
  savings INTEGER NOT NULL DEFAULT 0,
  favourite TEXT NOT NULL DEFAULT '',
  distinct_count INTEGER NOT NULL DEFAULT 0,
  perfect INTEGER NOT NULL DEFAULT 0,
  burnt INTEGER NOT NULL DEFAULT 0,
  stats_json TEXT NOT NULL DEFAULT '{}',
  created_at INTEGER NOT NULL,
  UNIQUE (device_id, date_key)
);

CREATE INDEX IF NOT EXISTS idx_scores_rank
  ON scores (date_key, average DESC, savings DESC, created_at ASC);

CREATE INDEX IF NOT EXISTS idx_scores_created
  ON scores (created_at);

-- 自創食譜分享
CREATE TABLE IF NOT EXISTS recipes (
  id TEXT PRIMARY KEY,
  creator_device TEXT NOT NULL,
  name TEXT NOT NULL,
  items_json TEXT NOT NULL,
  form TEXT NOT NULL DEFAULT 'plate',
  method TEXT NOT NULL DEFAULT 'pan_fry',
  colors_json TEXT NOT NULL DEFAULT '[]',
  like_count INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_recipes_likes
  ON recipes (like_count DESC, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_recipes_creator
  ON recipes (creator_device);

CREATE TABLE IF NOT EXISTS recipe_likes (
  recipe_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (recipe_id, device_id)
);

