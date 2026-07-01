-- 0003_inventory_checks.sql
--
-- 月次の実在庫照合（在庫確認）状態を保存するテーブル。
-- 工場ごと（本社工場 / 第二工場）× 月ごと（target_year + target_month）に1行。
-- 同じ年月・同じ場所の重複は UNIQUE 制約で防ぐ。
--
-- 既存テーブル（items / locations / initial_stocks / delivery_records /
-- shipping_records）には一切変更を加えない。

CREATE TABLE IF NOT EXISTS inventory_checks (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  target_year   INTEGER NOT NULL,           -- 例: 2026
  target_month  INTEGER NOT NULL,           -- 1〜12
  location_id   INTEGER NOT NULL,           -- locations.id への参照
  status        TEXT    NOT NULL DEFAULT 'completed', -- 完了行のみ保存する想定だが将来拡張のため残す
  checked_at    TEXT,                       -- ISO8601（日本時間を文字列で保存）
  checked_by    TEXT,                       -- 確認者氏名（任意）
  note          TEXT,                       -- 備考（任意）
  created_at    TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at    TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (location_id) REFERENCES locations(id),
  UNIQUE (target_year, target_month, location_id)
);

CREATE INDEX IF NOT EXISTS idx_inventory_checks_year_month
  ON inventory_checks(target_year, target_month);
