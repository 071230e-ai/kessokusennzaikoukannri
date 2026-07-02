-- =====================================================================
-- 取引日時カラム transaction_at を delivery_records / shipping_records に追加
-- =====================================================================
--
-- 目的:
--   在庫修正 (stock_adjustments) との日時比較は「取引日時」ベースで行う必要がある。
--   従来は created_at (レコード作成日時) で比較していたが、履歴編集で
--   delivery_date / shipping_date を変更しても created_at が変わらないため
--   在庫計算の切り替えが起きない不具合があった。
--
-- 方針:
--   1. delivery_records.transaction_at TEXT (ISO8601, JST '+09:00') を追加
--   2. shipping_records.transaction_at TEXT (ISO8601, JST '+09:00') を追加
--   3. 既存データは delivery_date / shipping_date (YYYY-MM-DD) から
--      'YYYY-MM-DDT00:00:00+09:00' として初期化
--      → 過去データを壊さず、JST基準の始端0時として登録
--   4. NOT NULL 制約は付けない (SQLite ALTER TABLE の制約から)。
--      アプリケーション側では transaction_at がある場合はそれを、
--      無い場合は delivery_date / shipping_date から生成した値を使う。
--   5. transaction_at にインデックスを張り、在庫計算 CTE の高速化を図る。
--
-- 冪等性: ALTER TABLE ADD COLUMN は「既に存在する」場合エラーになるため、
-- migrations フォルダは既存マイグレーションを二度当てない前提。
-- 手動再適用時は SQLite に IF NOT EXISTS がないため、
-- 事前に PRAGMA table_info で確認してから当てること。

ALTER TABLE delivery_records ADD COLUMN transaction_at TEXT;
ALTER TABLE shipping_records ADD COLUMN transaction_at TEXT;

-- 既存レコードは delivery_date / shipping_date (YYYY-MM-DD) を
-- JST 0時のフルISO文字列に変換して埋める。
-- delivery_date が万一 'YYYY-MM-DDTHH:MM:SS' 形式で入っていた場合は
-- そのまま '+09:00' を付ける（SUBSTR で日付部10文字取ったあと、時刻部を付与）。
UPDATE delivery_records
   SET transaction_at = SUBSTR(delivery_date, 1, 10) || 'T00:00:00+09:00'
 WHERE transaction_at IS NULL;

UPDATE shipping_records
   SET transaction_at = SUBSTR(shipping_date, 1, 10) || 'T00:00:00+09:00'
 WHERE transaction_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_delivery_txn_at
  ON delivery_records(item_id, location_id, transaction_at);
CREATE INDEX IF NOT EXISTS idx_shipping_txn_at
  ON shipping_records(item_id, location_id, transaction_at);
