// GET  /api/shipments  出荷・使用履歴の取得（新しい順）
// POST /api/shipments  出荷・使用登録
//
// 【transaction_at】
// deliveries.ts と同じく、shipping_date から transaction_at を生成し保存する。
// 在庫チェック時は最新の stock_adjustments.adjusted_at と
// transaction_at を datetime() で比較して計算する。
import {
  Env,
  errorResponse,
  jsonResponse,
  parseJson,
  uuid,
  normalizeTransactionAt,
} from './_utils';

interface ShipmentPayload {
  item_id?: number;
  location_id?: number;
  shipping_date?: string;
  quantity?: number;
  destination?: string | null;
  staff?: string | null;
  note?: string | null;
}

export const onRequestGet: PagesFunction<Env> = async ({ env }) => {
  const res = await env.DB.prepare(
    `SELECT
        s.id                  AS id,
        s.item_id             AS item_id,
        i.category            AS category,
        i.spec                AS spec,
        i.unit                AS unit,
        s.location_id         AS location_id,
        l.name                AS location,
        s.shipping_date       AS shipping_date,
        s.transaction_at      AS transaction_at,
        s.quantity            AS quantity,
        s.destination         AS destination,
        s.staff               AS staff,
        s.note                AS note,
        s.created_at          AS created_at
       FROM shipping_records s
       JOIN items i     ON i.id = s.item_id
       JOIN locations l ON l.id = s.location_id
      ORDER BY s.shipping_date DESC, s.created_at DESC`
  ).all();
  return jsonResponse({ shipments: res.results ?? [] });
};

export const onRequestPost: PagesFunction<Env> = async ({ request, env }) => {
  const body = await parseJson<ShipmentPayload>(request);
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
  const txnAt = normalizeTransactionAt(shipping_date);
  if (!txnAt) return errorResponse('invalid shipping_date');

  // 在庫不足チェック（サーバー側でも検証）
  // 最新の在庫修正 (stock_adjustments) を基準とし、その adjusted_at より後の
  // 納入・出荷だけを加減する（GET /api/stocks と同じロジック）。
  // 比較は transaction_at ベース。
  const stockRow = await env.DB.prepare(
    `SELECT
       (SELECT adjusted_stock FROM stock_adjustments
         WHERE item_id = ?1 AND location_id = ?2
         ORDER BY adjusted_at DESC LIMIT 1) AS adjusted_stock,
       (SELECT adjusted_at    FROM stock_adjustments
         WHERE item_id = ?1 AND location_id = ?2
         ORDER BY adjusted_at DESC LIMIT 1) AS adjusted_at,
       COALESCE((SELECT initial_stock FROM initial_stocks
                   WHERE item_id = ?1 AND location_id = ?2), 0) AS initial_stock,
       COALESCE((SELECT SUM(quantity) FROM delivery_records
                   WHERE item_id = ?1 AND location_id = ?2), 0) AS delivered_all,
       COALESCE((SELECT SUM(quantity) FROM shipping_records
                   WHERE item_id = ?1 AND location_id = ?2), 0) AS shipped_all`
  )
    .bind(item_id, location_id)
    .first<any>();

  let current: number;
  if (stockRow?.adjusted_at) {
    const sinceRow = await env.DB.prepare(
      `SELECT
         COALESCE((SELECT SUM(quantity) FROM delivery_records d
                     WHERE d.item_id = ?1 AND d.location_id = ?2
                       AND datetime(
                             COALESCE(d.transaction_at, d.delivery_date || 'T00:00:00+09:00')
                           ) > datetime(?3)), 0) AS delivered_since,
         COALESCE((SELECT SUM(quantity) FROM shipping_records sp
                     WHERE sp.item_id = ?1 AND sp.location_id = ?2
                       AND datetime(
                             COALESCE(sp.transaction_at, sp.shipping_date || 'T00:00:00+09:00')
                           ) > datetime(?3)), 0) AS shipped_since`
    )
      .bind(item_id, location_id, stockRow.adjusted_at)
      .first<any>();
    current =
      (stockRow.adjusted_stock as number) +
      (sinceRow?.delivered_since ?? 0) -
      (sinceRow?.shipped_since ?? 0);
  } else {
    current =
      (stockRow?.initial_stock ?? 0) +
      (stockRow?.delivered_all ?? 0) -
      (stockRow?.shipped_all ?? 0);
  }
  if (current < quantity) {
    return jsonResponse(
      { error: 'insufficient_stock', current_stock: current },
      409
    );
  }

  const id = uuid();
  await env.DB.prepare(
    `INSERT INTO shipping_records
       (id, item_id, location_id, shipping_date, transaction_at, quantity, destination, staff, note)
     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)`
  )
    .bind(
      id,
      item_id,
      location_id,
      shipping_date,
      txnAt,
      quantity,
      body.destination ?? null,
      body.staff ?? null,
      body.note ?? null
    )
    .run();
  return jsonResponse({ id, ok: true }, 201);
};
