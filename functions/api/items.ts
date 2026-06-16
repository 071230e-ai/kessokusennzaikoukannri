// GET /api/items  品目マスター一覧
import { Env, jsonResponse } from './_utils';

export const onRequestGet: PagesFunction<Env> = async ({ env }) => {
  const result = await env.DB.prepare(
    `SELECT id, category, spec, unit, low_stock_threshold, sort_order
       FROM items
      ORDER BY sort_order ASC`
  ).all();
  return jsonResponse({ items: result.results ?? [] });
};
