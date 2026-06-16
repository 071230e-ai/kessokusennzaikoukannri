// GET  /api/shipments  出荷・使用履歴の取得（新しい順）
// POST /api/shipments  出荷・使用登録
import { Env, errorResponse, jsonResponse, parseJson, uuid } from './_utils';

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

  // 在庫不足チェック（サーバー側でも検証）
  const stockRow = await env.DB.prepare(
    `SELECT
       COALESCE((SELECT initial_stock FROM initial_stocks
                   WHERE item_id = ?1 AND location_id = ?2), 0) AS initial_stock,
       COALESCE((SELECT SUM(quantity) FROM delivery_records
                   WHERE item_id = ?1 AND location_id = ?2), 0) AS delivered,
       COALESCE((SELECT SUM(quantity) FROM shipping_records
                   WHERE item_id = ?1 AND location_id = ?2), 0) AS shipped`
  )
    .bind(item_id, location_id)
    .first<any>();
  const current =
    (stockRow?.initial_stock ?? 0) +
    (stockRow?.delivered ?? 0) -
    (stockRow?.shipped ?? 0);
  if (current < quantity) {
    return jsonResponse(
      { error: 'insufficient_stock', current_stock: current },
      409
    );
  }

  const id = uuid();
  await env.DB.prepare(
    `INSERT INTO shipping_records
       (id, item_id, location_id, shipping_date, quantity, destination, staff, note)
     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)`
  )
    .bind(
      id,
      item_id,
      location_id,
      shipping_date,
      quantity,
      body.destination ?? null,
      body.staff ?? null,
      body.note ?? null
    )
    .run();
  return jsonResponse({ id, ok: true }, 201);
};
