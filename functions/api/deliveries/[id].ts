// PUT    /api/deliveries/:id  納入履歴の更新
// DELETE /api/deliveries/:id  納入履歴の削除
//
// PUT では delivery_date の変更に合わせて transaction_at も再生成する。
// これにより「在庫修正日時の前後に取引日を付け替える」履歴編集が
// 現在庫に正しく反映されるようになる。
import {
  Env,
  errorResponse,
  jsonResponse,
  parseJson,
  normalizeTransactionAt,
} from '../_utils';

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
  const txnAt = normalizeTransactionAt(delivery_date);
  if (!txnAt) return errorResponse('invalid delivery_date');

  const existing = await env.DB.prepare(
    `SELECT id FROM delivery_records WHERE id = ?1`
  ).bind(id).first<any>();
  if (!existing) {
    return errorResponse('not found', 404);
  }

  // delivery_date と transaction_at の両方を更新する。
  // created_at は不変（監査目的で「レコード作成時刻」を保持）。
  await env.DB.prepare(
    `UPDATE delivery_records
        SET item_id        = ?1,
            location_id    = ?2,
            delivery_date  = ?3,
            transaction_at = ?4,
            quantity       = ?5,
            supplier       = ?6,
            staff          = ?7,
            note           = ?8
      WHERE id = ?9`
  )
    .bind(
      item_id,
      location_id,
      delivery_date,
      txnAt,
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
