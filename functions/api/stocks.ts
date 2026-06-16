// GET /api/stocks
// 全品目×全保管場所の在庫サマリーを返す
// current_stock = initial_stock + SUM(deliveries) - SUM(shipments)
import { Env, jsonResponse } from './_utils';

export const onRequestGet: PagesFunction<Env> = async ({ env }) => {
  const sql = `
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
      COALESCE((SELECT SUM(quantity) FROM delivery_records
                  WHERE item_id = i.id AND location_id = l.id), 0) AS total_delivered,
      COALESCE((SELECT SUM(quantity) FROM shipping_records
                  WHERE item_id = i.id AND location_id = l.id), 0) AS total_shipped
    FROM items i
    CROSS JOIN locations l
    LEFT JOIN initial_stocks s ON s.item_id = i.id AND s.location_id = l.id
    ORDER BY i.sort_order ASC, l.sort_order ASC
  `;
  const res = await env.DB.prepare(sql).all<any>();
  const rows = (res.results ?? []).map((r: any) => ({
    item_id: r.item_id,
    category: r.category,
    spec: r.spec,
    unit: r.unit,
    low_stock_threshold: r.low_stock_threshold,
    location_id: r.location_id,
    location: r.location,
    initial_stock: r.initial_stock,
    total_delivered: r.total_delivered,
    total_shipped: r.total_shipped,
    current_stock: r.initial_stock + r.total_delivered - r.total_shipped,
    note: r.note,
  }));
  return jsonResponse({ stocks: rows });
};
