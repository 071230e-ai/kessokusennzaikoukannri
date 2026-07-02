// PUT    /api/shipments/:id  出荷・使用履歴の更新
// DELETE /api/shipments/:id  出荷・使用履歴の削除
//
// 在庫不足チェックは POST と同じく「最新の在庫修正を基準」に計算する。
// ただし編集対象レコード自身の旧数量は差し引かない状態で判定するため、
// SUM から自身の id を除外して現在庫を求める。
// 比較は transaction_at ベース。
import {
  Env,
  errorResponse,
  jsonResponse,
  parseJson,
  normalizeTransactionAt,
} from '../_utils';

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
  const txnAt = normalizeTransactionAt(shipping_date);
  if (!txnAt) return errorResponse('invalid shipping_date');

  const existing = await env.DB.prepare(
    `SELECT id FROM shipping_records WHERE id = ?1`
  ).bind(id).first<any>();
  if (!existing) {
    return errorResponse('not found', 404);
  }

  // 在庫不足チェック
  // 「編集対象を一度取り除いた」状態での現在庫を計算し、新しい数量と比較する。
  // POST と同じく最新の在庫修正が存在する場合はそれを基準にする。
  //
  // ここでは編集後の transaction_at が「adjusted_at より後」に該当するかを
  // 判定に含める。編集前の日付が修正前だった (=在庫計算に寄与していなかった)
  // レコードを修正後にずらしても、新しい日付側で数量が加減される。
  //
  // 具体的には:
  //   available = base
  //             + Σ delivery.quantity WHERE txn > adj_at
  //             - Σ shipping.quantity WHERE txn > adj_at AND id != this_id
  //   （最新修正なしの場合は全期間で計算し、id != this_id を差し引く）
  //   新しい quantity は「新しい transaction_at が adj_at より後の場合のみ」
  //   available から引き算対象となる。
  //
  // ただし「available < quantity（新しい数量）」の判定は、
  // 新しい取引が計算対象になる場合のみ必要。計算対象外の場合は
  // 在庫を減らさないので不足判定はしなくてよい（0以上ならOK）。
  const stockRow = await env.DB.prepare(
    `SELECT
       (SELECT adjusted_stock FROM stock_adjustments
         WHERE item_id = ?1 AND location_id = ?2
         ORDER BY adjusted_at DESC LIMIT 1) AS adjusted_stock,
       (SELECT adjusted_at    FROM stock_adjustments
         WHERE item_id = ?1 AND location_id = ?2
         ORDER BY adjusted_at DESC LIMIT 1) AS adjusted_at,
       COALESCE((SELECT initial_stock FROM initial_stocks
                   WHERE item_id = ?1 AND location_id = ?2), 0) AS initial_stock`
  )
    .bind(item_id, location_id)
    .first<any>();

  let availableBeforeThis: number;
  const adjAt = stockRow?.adjusted_at as string | null;
  const newTxnIsAfterAdj = adjAt ? txnAt > adjAt : true; // 単純な文字列比較でも ISO なら OK

  if (adjAt) {
    const sinceRow = await env.DB.prepare(
      `SELECT
         COALESCE((SELECT SUM(quantity) FROM delivery_records d
                     WHERE d.item_id = ?1 AND d.location_id = ?2
                       AND datetime(
                             COALESCE(d.transaction_at, d.delivery_date || 'T00:00:00+09:00')
                           ) > datetime(?3)), 0) AS delivered_since,
         COALESCE((SELECT SUM(quantity) FROM shipping_records sp
                     WHERE sp.item_id = ?1 AND sp.location_id = ?2
                       AND sp.id != ?4
                       AND datetime(
                             COALESCE(sp.transaction_at, sp.shipping_date || 'T00:00:00+09:00')
                           ) > datetime(?3)), 0) AS shipped_since`
    )
      .bind(item_id, location_id, adjAt, id)
      .first<any>();
    availableBeforeThis =
      (stockRow!.adjusted_stock as number) +
      (sinceRow?.delivered_since ?? 0) -
      (sinceRow?.shipped_since ?? 0);
  } else {
    const allRow = await env.DB.prepare(
      `SELECT
         COALESCE((SELECT SUM(quantity) FROM delivery_records
                     WHERE item_id = ?1 AND location_id = ?2), 0) AS delivered,
         COALESCE((SELECT SUM(quantity) FROM shipping_records
                     WHERE item_id = ?1 AND location_id = ?2
                       AND id != ?3), 0) AS shipped`
    )
      .bind(item_id, location_id, id)
      .first<any>();
    availableBeforeThis =
      (stockRow?.initial_stock ?? 0) +
      (allRow?.delivered ?? 0) -
      (allRow?.shipped ?? 0);
  }

  // 新しい取引日が最新修正以降なら在庫を減らす → 不足チェック要
  // 新しい取引日が最新修正以前なら現在庫に影響しない → 数量は自由
  if (newTxnIsAfterAdj && availableBeforeThis < quantity) {
    return jsonResponse(
      { error: 'insufficient_stock', current_stock: availableBeforeThis },
      409
    );
  }

  await env.DB.prepare(
    `UPDATE shipping_records
        SET item_id        = ?1,
            location_id    = ?2,
            shipping_date  = ?3,
            transaction_at = ?4,
            quantity       = ?5,
            destination    = ?6,
            staff          = ?7,
            note           = ?8
      WHERE id = ?9`
  )
    .bind(
      item_id,
      location_id,
      shipping_date,
      txnAt,
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
