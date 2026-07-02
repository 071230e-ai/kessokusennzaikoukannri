-- 0004_stock_adjustments.sql
--
-- 在庫修正（実在庫との一括照合）を記録するテーブル。
-- 「アプリ上の在庫」と「実際の在庫」の差異を解消したいときに使用する。
--
-- 現在庫計算では、同じ工場・同じ品目の最新 adjusted_at を基準にし、
-- その adjusted_at より後に登録された納入・出荷だけを加減する。
--
-- 既存テーブル（items / locations / initial_stocks / delivery_records /
-- shipping_records / inventory_checks）には一切変更を加えない。

CREATE TABLE IF NOT EXISTS stock_adjustments (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  adjustment_group_id TEXT    NOT NULL,           -- 一括修正の識別子（同じ保存操作内で同じ値）
  location_id         INTEGER NOT NULL,           -- locations.id
  item_id             INTEGER NOT NULL,           -- items.id
  previous_stock      REAL    NOT NULL,           -- 修正前のアプリ在庫（保存時点のスナップショット）
  adjusted_stock      REAL    NOT NULL,           -- 修正後の実在庫（利用者が入力した値）
  difference          REAL    NOT NULL,           -- adjusted_stock - previous_stock
  adjusted_at         TEXT    NOT NULL,           -- ISO8601（JST + '+09:00' 付き）
  adjusted_by         TEXT,                       -- 修正者（任意）
  note                TEXT,                       -- 備考（任意）
  created_at          TEXT    NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (location_id) REFERENCES locations(id),
  FOREIGN KEY (item_id)     REFERENCES items(id)
);

-- 現在庫計算の SQL パフォーマンス確保：
--   (item_id, location_id) ごとに MAX(adjusted_at) を高速に取れるように索引を張る。
CREATE INDEX IF NOT EXISTS idx_stock_adj_item_loc
  ON stock_adjustments(item_id, location_id, adjusted_at DESC);

-- 一括修正の一覧表示用（グループ単位でまとめて履歴を見せる）
CREATE INDEX IF NOT EXISTS idx_stock_adj_group
  ON stock_adjustments(adjustment_group_id);

-- 履歴画面用（新しい順）
CREATE INDEX IF NOT EXISTS idx_stock_adj_adjusted_at
  ON stock_adjustments(adjusted_at DESC);
