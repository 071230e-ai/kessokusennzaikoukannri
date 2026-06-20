// PUT    /api/shipments/:id  出荷・使用履歴の更新
// DELETE /api/shipments/:id  出荷・使用履歴の削除
import { Env, errorResponse, jsonResponse, parseJson } from '../_utils';

interface ShipmentUpdatePayload {
  item_id?: number;
  location_id?: number;
  shipping_date?: string;
  quantity?: number;
  destination?: string | null;
  staff?: string | null;
  note?: string | null;
}

export const onRequestPut: PagesFunction<Env> = async ({ request, env, params }) => {
  const id = params.id as string;
  if (!id) return errorResponse('id required');

  const body = await parseJson<ShipmentUpdatePayload>(request);
  if (!body) return errorResponse('invalid json');

  const { item_id, location_id, shipping_date, quantity } = body;
  if (
    typeof item_id !== 'number' ||
    typeof location_id !== 'number' ||
    !shipping_date ||
    typeof quantity !== 'number' ||
    !Number.isFinite(quantity) ||
    quantity <= 0
  ) {
    return errorResponse('invalid parameters');
  }

  // 対象レコードが存在するかチェック
  const existing = await env.DB.prepare(
    `SELECT id FROM shipping_records WHERE id = ?1`
  ).bind(id).first<any>();
  if (!existing) {
    return errorResponse('not found', 404);
  }

  // 在庫不足チェック：
  //   新しい (item_id, location_id) における在庫 =
  //       初期在庫
  //     + Σ deliveries (item_id, location_id)
  //     - Σ shipping_records (item_id, location_id) WHERE id != 編集対象id
  //     - 新しい数量
  //   が 0 未満なら 409 を返す。
  //   id != ? により、編集対象レコードの旧数量は除外されるため、
  //   「変更前の出荷を一度戻した状態」での判定になる。
  const stockRow = await env.DB.prepare(
    `SELECT
       COALESCE((SELECT initial_stock FROM initial_stocks
                   WHERE item_id = ?1 AND location_id = ?2), 0) AS initial_stock,
       COALESCE((SELECT SUM(quantity) FROM delivery_records
                   WHERE item_id = ?1 AND location_id = ?2), 0) AS delivered,
       COALESCE((SELECT SUM(quantity) FROM shipping_records
                   WHERE item_id = ?1 AND location_id = ?2 AND id != ?3), 0) AS shipped`
  )
    .bind(item_id, location_id, id)
    .first<any>();
  const available =
    (stockRow?.initial_stock ?? 0) +
    (stockRow?.delivered ?? 0) -
    (stockRow?.shipped ?? 0);
  if (available < quantity) {
    return jsonResponse(
      { error: 'insufficient_stock', current_stock: available },
      409
    );
  }

  await env.DB.prepare(
    `UPDATE shipping_records
        SET item_id       = ?1,
            location_id   = ?2,
            shipping_date = ?3,
            quantity      = ?4,
            destination   = ?5,
            staff         = ?6,
            note          = ?7
      WHERE id = ?8`
  )
    .bind(
      item_id,
      location_id,
      shipping_date,
      quantity,
      body.destination ?? null,
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
  await env.DB.prepare(`DELETE FROM shipping_records WHERE id = ?1`)
    .bind(id)
    .run();
  return jsonResponse({ ok: true });
};
