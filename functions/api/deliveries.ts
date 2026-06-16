// GET  /api/deliveries  納入履歴の取得（新しい順）
// POST /api/deliveries  納入登録
import { Env, errorResponse, jsonResponse, parseJson, uuid } from './_utils';

interface DeliveryPayload {
  item_id?: number;
  location_id?: number;
  delivery_date?: string; // YYYY-MM-DD or ISO
  quantity?: number;
  supplier?: string | null;
  staff?: string | null;
  note?: string | null;
}

export const onRequestGet: PagesFunction<Env> = async ({ env }) => {
  const res = await env.DB.prepare(
    `SELECT
        d.id                  AS id,
        d.item_id             AS item_id,
        i.category            AS category,
        i.spec                AS spec,
        i.unit                AS unit,
        d.location_id         AS location_id,
        l.name                AS location,
        d.delivery_date       AS delivery_date,
        d.quantity            AS quantity,
        d.supplier            AS supplier,
        d.staff               AS staff,
        d.note                AS note,
        d.created_at          AS created_at
       FROM delivery_records d
       JOIN items i     ON i.id = d.item_id
       JOIN locations l ON l.id = d.location_id
      ORDER BY d.delivery_date DESC, d.created_at DESC`
  ).all();
  return jsonResponse({ deliveries: res.results ?? [] });
};

export const onRequestPost: PagesFunction<Env> = async ({ request, env }) => {
  const body = await parseJson<DeliveryPayload>(request);
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
  const id = uuid();
  await env.DB.prepare(
    `INSERT INTO delivery_records
       (id, item_id, location_id, delivery_date, quantity, supplier, staff, note)
     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)`
  )
    .bind(
      id,
      item_id,
      location_id,
      delivery_date,
      quantity,
      body.supplier ?? null,
      body.staff ?? null,
      body.note ?? null
    )
    .run();
  return jsonResponse({ id, ok: true }, 201);
};
