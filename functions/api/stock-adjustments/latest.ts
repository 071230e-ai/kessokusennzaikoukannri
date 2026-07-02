// GET /api/stock-adjustments/latest
// 各 (item_id, location_id) の最新の在庫修正を返す。
// 現在庫の再計算基準となる情報を UI から取得するためのエンドポイント。

import { Env, jsonResponse } from '../_utils';

export const onRequestGet: PagesFunction<Env> = async ({ env }) => {
  const sql = `
    WITH latest_adj AS (
      SELECT
        item_id,
        location_id,
        MAX(adjusted_at) AS max_adjusted_at
      FROM stock_adjustments
      GROUP BY item_id, location_id
    )
    SELECT
      a.id                  AS id,
      a.adjustment_group_id AS adjustment_group_id,
      a.location_id         AS location_id,
      l.name                AS location,
      a.item_id             AS item_id,
      i.category            AS category,
      i.spec                AS spec,
      i.unit                AS unit,
      a.previous_stock      AS previous_stock,
      a.adjusted_stock      AS adjusted_stock,
      a.difference          AS difference,
      a.adjusted_at         AS adjusted_at,
      a.adjusted_by         AS adjusted_by,
      a.note                AS note,
      a.created_at          AS created_at
    FROM stock_adjustments a
    JOIN latest_adj la
      ON la.item_id     = a.item_id
     AND la.location_id = a.location_id
     AND la.max_adjusted_at = a.adjusted_at
    JOIN locations l ON l.id = a.location_id
    JOIN items i     ON i.id = a.item_id
    ORDER BY l.sort_order ASC, i.sort_order ASC
  `;
  const res = await env.DB.prepare(sql).all();
  return jsonResponse({ latest: res.results ?? [] });
};
