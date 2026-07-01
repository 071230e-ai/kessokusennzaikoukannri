// GET  /api/inventory-checks                    全在庫確認記録（新しい順）
// GET  /api/inventory-checks?year=YYYY&month=MM 指定月のみ
// POST /api/inventory-checks                    在庫確認完了の登録（upsert）
//
// 完了行のみを保存する設計：DBに行が存在する=完了済み、行が無い=未完了。
// 同一 (target_year, target_month, location_id) は UNIQUE 制約により1件のみ。
import { Env, errorResponse, jsonResponse, parseJson } from './_utils';

interface CheckPostPayload {
  target_year?: number;
  target_month?: number;
  location_id?: number;
  checked_at?: string | null; // ISO8601（クライアントの日本時間）
  checked_by?: string | null;
  note?: string | null;
}

export const onRequestGet: PagesFunction<Env> = async ({ env, request }) => {
  const url = new URL(request.url);
  const yearStr = url.searchParams.get('year');
  const monthStr = url.searchParams.get('month');

  let sql = `SELECT
       c.id            AS id,
       c.target_year   AS target_year,
       c.target_month  AS target_month,
       c.location_id   AS location_id,
       l.name          AS location,
       c.status        AS status,
       c.checked_at    AS checked_at,
       c.checked_by    AS checked_by,
       c.note          AS note,
       c.created_at    AS created_at,
       c.updated_at    AS updated_at
     FROM inventory_checks c
     JOIN locations l ON l.id = c.location_id`;

  const params: any[] = [];
  if (yearStr && monthStr) {
    sql += ` WHERE c.target_year = ?1 AND c.target_month = ?2`;
    params.push(Number(yearStr), Number(monthStr));
  }
  sql += ` ORDER BY c.target_year DESC, c.target_month DESC, c.location_id ASC`;

  const stmt = env.DB.prepare(sql);
  const res = params.length > 0
    ? await stmt.bind(...params).all()
    : await stmt.all();

  return jsonResponse({ checks: res.results ?? [] });
};

export const onRequestPost: PagesFunction<Env> = async ({ request, env }) => {
  const body = await parseJson<CheckPostPayload>(request);
  if (!body) return errorResponse('invalid json');

  const { target_year, target_month, location_id } = body;
  if (
    typeof target_year !== 'number' ||
    !Number.isInteger(target_year) ||
    target_year < 2000 ||
    target_year > 2100
  ) {
    return errorResponse('invalid target_year');
  }
  if (
    typeof target_month !== 'number' ||
    !Number.isInteger(target_month) ||
    target_month < 1 ||
    target_month > 12
  ) {
    return errorResponse('invalid target_month');
  }
  if (typeof location_id !== 'number') {
    return errorResponse('invalid location_id');
  }

  // location_id の存在チェック
  const loc = await env.DB.prepare(
    `SELECT id FROM locations WHERE id = ?1`
  ).bind(location_id).first<any>();
  if (!loc) return errorResponse('location not found', 404);

  // ISO8601。クライアントから渡されなければサーバ時刻を fallback。
  const checkedAt = body.checked_at ?? new Date().toISOString();

  // upsert（同じ年月・同じ場所が既に完了済みだった場合は最新値で更新）
  await env.DB.prepare(
    `INSERT INTO inventory_checks
       (target_year, target_month, location_id, status, checked_at, checked_by, note, updated_at)
     VALUES (?1, ?2, ?3, 'completed', ?4, ?5, ?6, datetime('now'))
     ON CONFLICT(target_year, target_month, location_id) DO UPDATE SET
       status     = 'completed',
       checked_at = excluded.checked_at,
       checked_by = excluded.checked_by,
       note       = excluded.note,
       updated_at = datetime('now')`
  )
    .bind(
      target_year,
      target_month,
      location_id,
      checkedAt,
      body.checked_by ?? null,
      body.note ?? null
    )
    .run();

  return jsonResponse({ ok: true }, 201);
};
