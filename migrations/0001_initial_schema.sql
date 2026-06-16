-- =====================================================================
-- 結束線・タイワイヤ在庫管理 共有DBスキーマ
-- =====================================================================

-- 保管場所マスター
CREATE TABLE IF NOT EXISTS locations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 品目マスター
CREATE TABLE IF NOT EXISTS items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  category TEXT NOT NULL,
  spec TEXT NOT NULL,                -- '350mm' / '-' など
  unit TEXT NOT NULL,                -- 'kg' or '個'
  low_stock_threshold REAL NOT NULL DEFAULT 0,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(category, spec)
);

-- 初期在庫（品目×保管場所のペアごと）
CREATE TABLE IF NOT EXISTS initial_stocks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  item_id INTEGER NOT NULL,
  location_id INTEGER NOT NULL,
  initial_stock REAL NOT NULL DEFAULT 0,
  note TEXT,
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (item_id) REFERENCES items(id),
  FOREIGN KEY (location_id) REFERENCES locations(id),
  UNIQUE(item_id, location_id)
);

-- 納入履歴
CREATE TABLE IF NOT EXISTS delivery_records (
  id TEXT PRIMARY KEY,               -- UUID（クライアント生成も許可）
  item_id INTEGER NOT NULL,
  location_id INTEGER NOT NULL,
  delivery_date TEXT NOT NULL,       -- ISO8601 (YYYY-MM-DD or full)
  quantity REAL NOT NULL,
  supplier TEXT,
  staff TEXT,
  note TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (item_id) REFERENCES items(id),
  FOREIGN KEY (location_id) REFERENCES locations(id)
);
CREATE INDEX IF NOT EXISTS idx_delivery_date ON delivery_records(delivery_date);
CREATE INDEX IF NOT EXISTS idx_delivery_item_loc ON delivery_records(item_id, location_id);

-- 出荷・使用履歴
CREATE TABLE IF NOT EXISTS shipping_records (
  id TEXT PRIMARY KEY,
  item_id INTEGER NOT NULL,
  location_id INTEGER NOT NULL,
  shipping_date TEXT NOT NULL,
  quantity REAL NOT NULL,
  destination TEXT,
  staff TEXT,
  note TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (item_id) REFERENCES items(id),
  FOREIGN KEY (location_id) REFERENCES locations(id)
);
CREATE INDEX IF NOT EXISTS idx_shipping_date ON shipping_records(shipping_date);
CREATE INDEX IF NOT EXISTS idx_shipping_item_loc ON shipping_records(item_id, location_id);
