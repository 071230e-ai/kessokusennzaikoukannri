// GET  /api/stock-adjustments        全在庫修正の履歴（新しい順）
// POST /api/stock-adjustments        複数品目を1リクエストで一括修正
//
// 1リクエストで複数品目を保存する場合は同じ adjustment_group_id を付与し、
// D1 の batch API で原子的に書き込むことで「一部だけ保存される」状態を防ぐ。

import { Env, errorResponse, jsonResponse, parseJson, uuid } from './_utils';

interface AdjustmentInputItem {
  item_id?: number;
  previous_stock?: number;
  adjusted_stock?: number;
}

interface AdjustmentPostPayload {
  location_id?: number;
  adjusted_at?: string | null; // ISO8601 (JST '+09:00' 付き)
  adjusted_by?: string | null;
  note?: string | null;
  items?: AdjustmentInputItem[];
  /** 単一品目呼び出し互換 */
  item_id?: number;
  previous_stock?: number;
  adjusted_stock?: number;
}

export const onRequestGet: PagesFunction<Env> = async ({ env }) => {
  const res = await env.DB.prepare(
    `SELECT
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
     JOIN locations l ON l.id = a.location_id
     JOIN items i     ON i.id = a.item_id
     ORDER BY datetime(a.adjusted_at) DESC, a.id DESC`
  ).all();
  return jsonResponse({ adjustments: res.results ?? [] });
};

export const onRequestPost: PagesFunction<Env> = async ({ request, env }) => {
  const body = await parseJson<AdjustmentPostPayload>(request);
  if (!body) return errorResponse('invalid json');

  const { location_id } = body;
  if (typeof location_id !== 'number') {
    return errorResponse('invalid location_id');
  }
  // location_id の存在チェック
  const loc = await env.DB.prepare(`SELECT id FROM locations WHERE id = ?1`)
    .bind(location_id)
    .first<any>();
  if (!loc) return errorResponse('location not found', 404);

  // items 配列を正規化（単一形式も items 1件として扱う）
  const inputs: AdjustmentInputItem[] = Array.isArray(body.items)
    ? body.items
    : (typeof body.item_id === 'number'
        ? [{
            item_id: body.item_id,
            previous_stock: body.previous_stock,
            adjusted_stock: body.adjusted_stock,
          }]
        : []);

  if (inputs.length === 0) {
    return errorResponse('no items to adjust');
  }

  // 各行を厳密検証
  const normalized: {
    item_id: number;
    previous_stock: number;
    adjusted_stock: number;
    difference: number;
  }[] = [];
  const seenItems = new Set<number>();
  for (const it of inputs) {
    if (
      typeof it.item_id !== 'number' ||
      typeof it.adjusted_stock !== 'number' ||
      !Number.isFinite(it.adjusted_stock) ||
      it.adjusted_stock < 0
    ) {
      return errorResponse('invalid item entry');
    }
    if (seenItems.has(it.item_id)) {
      return errorResponse('duplicate item_id');
    }
    seenItems.add(it.item_id);
    const prev =
      typeof it.previous_stock === 'number' && Number.isFinite(it.previous_stock)
        ? it.previous_stock
        : 0;
    normalized.push({
      item_id: it.item_id,
      previous_stock: prev,
      adjusted_stock: it.adjusted_stock,
      difference: it.adjusted_stock - prev,
    });
  }

  // 全 item_id が items テーブルに存在するか確認
  const placeholders = normalized.map((_, i) => `?${i + 1}`).join(',');
  const itemCheck = await env.DB.prepare(
    `SELECT id FROM items WHERE id IN (${placeholders})`
  )
    .bind(...normalized.map((n) => n.item_id))
    .all<any>();
  const existingIds = new Set(
    (itemCheck.results ?? []).map((r: any) => r.id as number)
  );
  for (const n of normalized) {
    if (!existingIds.has(n.item_id)) {
      return errorResponse(`item_id ${n.item_id} not found`, 404);
    }
  }

  const groupId = uuid();
  // adjusted_at はクライアント（JST）から '+09:00' 付き ISO で送られる。
  // 無ければサーバー時刻を +09:00 に変換して補う。
  const adjustedAt = body.adjusted_at ?? toJstIso(new Date());

  const stmt = env.DB.prepare(
    `INSERT INTO stock_adjustments
       (adjustment_group_id, location_id, item_id,
        previous_stock, adjusted_stock, difference,
        adjusted_at, adjusted_by, note)
     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)`
  );
  const batch = normalized.map((n) =>
    stmt.bind(
      groupId,
      location_id,
      n.item_id,
      n.previous_stock,
      n.adjusted_stock,
      n.difference,
      adjustedAt,
      body.adjusted_by ?? null,
      body.note ?? null
    )
  );
  // D1 batch は暗黙にトランザクションで実行される。
  await env.DB.batch(batch);

  return jsonResponse(
    { ok: true, adjustment_group_id: groupId, count: normalized.length },
    201
  );
};

/** サーバ時刻（UTC）を JST '+09:00' 付き ISO8601 に変換 */
function toJstIso(d: Date): string {
  const jst = new Date(d.getTime() + 9 * 60 * 60 * 1000);
  const y = jst.getUTCFullYear().toString().padStart(4, '0');
  const mo = (jst.getUTCMonth() + 1).toString().padStart(2, '0');
  const da = jst.getUTCDate().toString().padStart(2, '0');
  const h = jst.getUTCHours().toString().padStart(2, '0');
  const mi = jst.getUTCMinutes().toString().padStart(2, '0');
  const s = jst.getUTCSeconds().toString().padStart(2, '0');
  return `${y}-${mo}-${da}T${h}:${mi}:${s}+09:00`;
}
