// POST /api/initial-stock
// Body: { item_id, location_id, initial_stock, note? }
// 単一品目×場所の初期在庫を upsert する
import { Env, errorResponse, jsonResponse, parseJson } from './_utils';

interface InitialStockPayload {
  item_id?: number;
  location_id?: number;
  initial_stock?: number;
  note?: string | null;
}

export const onRequestPost: PagesFunction<Env> = async ({ request, env }) => {
  const body = await parseJson<InitialStockPayload>(request);
  if (!body) return errorResponse('invalid json');
  const { item_id, location_id, initial_stock, note } = body;
  if (
    typeof item_id !== 'number' ||
    typeof location_id !== 'number' ||
    typeof initial_stock !== 'number' ||
    !Number.isFinite(initial_stock) ||
    initial_stock < 0
  ) {
    return errorResponse('invalid parameters');
  }
  await env.DB.prepare(
    `INSERT INTO initial_stocks (item_id, location_id, initial_stock, note, updated_at)
     VALUES (?1, ?2, ?3, ?4, datetime('now'))
     ON CONFLICT(item_id, location_id) DO UPDATE SET
        initial_stock = excluded.initial_stock,
        note          = excluded.note,
        updated_at    = excluded.updated_at`
  )
    .bind(item_id, location_id, initial_stock, note ?? null)
    .run();
  return jsonResponse({ ok: true });
};
