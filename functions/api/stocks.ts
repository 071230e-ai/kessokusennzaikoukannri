// GET /api/stocks
// 全品目×全保管場所の在庫サマリーを返す。
//
// 【現在庫の計算式】
//
// 1. その (item_id, location_id) に対する最新の在庫修正 (stock_adjustments) を取得。
// 2. 最新修正が存在する場合:
//      current_stock = adjusted_stock
//                    + SUM(deliveries.quantity  WHERE transaction_at > adjusted_at)
//                    - SUM(shipments.quantity   WHERE transaction_at > adjusted_at)
// 3. 最新修正が存在しない場合（従来動作）:
//      current_stock = initial_stock
//                    + SUM(deliveries.quantity)
//                    - SUM(shipments.quantity)
//
// 【なぜ transaction_at で比較するか】
// 履歴編集で delivery_date / shipping_date を変更した場合、created_at は
// 変わらない。ユーザが「取引日を修正日時の前後に付け替える」操作を行った際に
// 現在庫の反映がリアルタイムに切り替わることが仕様。したがって取引日時
// (transaction_at) を基準に比較する必要がある。
//
// 【transaction_at の値】
// - INSERT/UPDATE 時にサーバ側で
//     - 'YYYY-MM-DDTHH:MM:SS+09:00' (client指定の日付+JST0時) として保存
//     - もしくは client が full ISO を送った場合はそのまま保存
// - 既存レコードは migration 0005 で
//     'YYYY-MM-DDT00:00:00+09:00' に初期化済み
// - adjusted_at も JST '+09:00' 付き ISO なので、
//   datetime() で正規化すれば SQLite 上で同一時系列で正しく比較できる。
//
// 【念のためのフォールバック】
// もし transaction_at が NULL のレコードが残っていた場合に備えて、
// SQL 側で COALESCE(transaction_at, delivery_date || 'T00:00:00+09:00') を
// 使い、必ず datetime() 比較が動くようにする。

import { Env, jsonResponse } from './_utils';

export const onRequestGet: PagesFunction<Env> = async ({ env }) => {
  const sql = `
    WITH latest_adj AS (
      SELECT
        item_id,
        location_id,
        MAX(adjusted_at) AS max_adjusted_at
      FROM stock_adjustments
      GROUP BY item_id, location_id
    ),
    adj_pick AS (
      SELECT
        a.item_id,
        a.location_id,
        a.adjusted_stock,
        a.adjusted_at
      FROM stock_adjustments a
      JOIN latest_adj la
        ON la.item_id     = a.item_id
       AND la.location_id = a.location_id
       AND la.max_adjusted_at = a.adjusted_at
    )
    SELECT
      i.id            AS item_id,
      i.category      AS category,
      i.spec          AS spec,
      i.unit          AS unit,
      i.low_stock_threshold AS low_stock_threshold,
      i.sort_order    AS item_sort,
      l.id            AS location_id,
      l.name          AS location,
      l.sort_order    AS loc_sort,
      COALESCE(s.initial_stock, 0) AS initial_stock,
      COALESCE(s.note, '')         AS note,
      ap.adjusted_stock            AS adjusted_stock,
      ap.adjusted_at               AS adjusted_at,
      -- 修正後の納入合計 (transaction_at ベース)
      COALESCE((
        SELECT SUM(quantity) FROM delivery_records d
         WHERE d.item_id = i.id
           AND d.location_id = l.id
           AND (
             ap.adjusted_at IS NULL
             OR datetime(
                  COALESCE(d.transaction_at, d.delivery_date || 'T00:00:00+09:00')
                ) > datetime(ap.adjusted_at)
           )
      ), 0) AS delivered_since,
      -- 修正後の出荷合計 (transaction_at ベース)
      COALESCE((
        SELECT SUM(quantity) FROM shipping_records sp
         WHERE sp.item_id = i.id
           AND sp.location_id = l.id
           AND (
             ap.adjusted_at IS NULL
             OR datetime(
                  COALESCE(sp.transaction_at, sp.shipping_date || 'T00:00:00+09:00')
                ) > datetime(ap.adjusted_at)
           )
      ), 0) AS shipped_since,
      -- 全期間の合計（期間集計・デバッグ用に返す）
      COALESCE((
        SELECT SUM(quantity) FROM delivery_records
         WHERE item_id = i.id AND location_id = l.id
      ), 0) AS total_delivered,
      COALESCE((
        SELECT SUM(quantity) FROM shipping_records
         WHERE item_id = i.id AND location_id = l.id
      ), 0) AS total_shipped
    FROM items i
    CROSS JOIN locations l
    LEFT JOIN initial_stocks s ON s.item_id = i.id AND s.location_id = l.id
    LEFT JOIN adj_pick ap ON ap.item_id = i.id AND ap.location_id = l.id
    ORDER BY i.sort_order ASC, l.sort_order ASC
  `;

  const res = await env.DB.prepare(sql).all<any>();
  const rows = (res.results ?? []).map((r: any) => {
    const hasAdj = r.adjusted_at != null;
    const baseStock = hasAdj ? (r.adjusted_stock as number) : (r.initial_stock as number);
    const currentStock = baseStock + (r.delivered_since ?? 0) - (r.shipped_since ?? 0);
    return {
      item_id: r.item_id,
      category: r.category,
      spec: r.spec,
      unit: r.unit,
      low_stock_threshold: r.low_stock_threshold,
      location_id: r.location_id,
      location: r.location,
      initial_stock: hasAdj ? r.adjusted_stock : r.initial_stock,
      total_delivered: r.total_delivered ?? 0,
      total_shipped: r.total_shipped ?? 0,
      current_stock: currentStock,
      note: r.note,
      has_adjustment: hasAdj,
      adjusted_at: r.adjusted_at,
      adjusted_stock: r.adjusted_stock,
      delivered_since: r.delivered_since ?? 0,
      shipped_since: r.shipped_since ?? 0,
    };
  });
  return jsonResponse({ stocks: rows });
};
