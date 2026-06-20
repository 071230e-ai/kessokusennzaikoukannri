// PUT    /api/deliveries/:id  納入履歴の更新
// DELETE /api/deliveries/:id  納入履歴の削除
import { Env, errorResponse, jsonResponse, parseJson } from '../_utils';

interface DeliveryUpdatePayload {
  item_id?: number;
  location_id?: number;
  delivery_date?: string;
  quantity?: number;
  supplier?: string | null;
  staff?: string | null;
  note?: string | null;
}

export const onRequestPut: PagesFunction<Env> = async ({ request, env, params }) => {
  const id = params.id as string;
  if (!id) return errorResponse('id required');

  const body = await parseJson<DeliveryUpdatePayload>(request);
  if (!body) return errorResponse('invalid json');

  const { item_id, location_id, delivery_date, quantity } = body;
  if (
    typeof item_id !== 'number' ||
    typeof location_id !== 'number' ||
    !delivery_date ||
    typeof quantity !== 'number' ||
    !Number.isFinite(quantity) ||
    quantity <= 0
  ) {
    return errorResponse('invalid parameters');
  }

  // 対象レコードが存在するかチェック
  const existing = await env.DB.prepare(
    `SELECT id FROM delivery_records WHERE id = ?1`
  ).bind(id).first<any>();
  if (!existing) {
    return errorResponse('not found', 404);
  }

  // UPDATE 実行（在庫は GET /api/stocks 時に都度計算されるため、ここでの再計算は不要）
  await env.DB.prepare(
    `UPDATE delivery_records
        SET item_id       = ?1,
            location_id   = ?2,
            delivery_date = ?3,
            quantity      = ?4,
            supplier      = ?5,
            staff         = ?6,
            note          = ?7
      WHERE id = ?8`
  )
    .bind(
      item_id,
      location_id,
      delivery_date,
      quantity,
      body.supplier ?? null,
      body.staff ?? null,
      body.note ?? null,
      id
    )
    .run();

  return jsonResponse({ id, ok: true });
};

export const onRequestDelete: PagesFunction<Env> = async ({ env, params }) => {
  const id = params.id as string;
  if (!id) return errorResponse('id required');
  await env.DB.prepare(`DELETE FROM delivery_records WHERE id = ?1`)
    .bind(id)
    .run();
  return jsonResponse({ ok: true });
};
