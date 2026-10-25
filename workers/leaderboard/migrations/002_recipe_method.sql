-- 已部署舊版食譜表時，補上煮法欄位。
-- 新安裝可以直接用 schema.sql（已經包含 method）。
ALTER TABLE recipes ADD COLUMN method TEXT NOT NULL DEFAULT 'pan_fry';
