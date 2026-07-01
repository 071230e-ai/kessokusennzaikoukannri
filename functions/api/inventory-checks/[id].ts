// DELETE /api/inventory-checks/:id  在庫確認完了状態の取り消し（行を削除＝未完了に戻す）
import { Env, errorResponse, jsonResponse } from '../_utils';

export const onRequestDelete: PagesFunction<Env> = async ({ env, params }) => {
  const idStr = params.id as string;
  if (!idStr) return errorResponse('id required');
  const id = Number(idStr);
  if (!Number.isInteger(id) || id <= 0) {
    return errorResponse('invalid id');
  }
  await env.DB.prepare(`DELETE FROM inventory_checks WHERE id = ?1`)
    .bind(id)
    .run();
  return jsonResponse({ ok: true });
};
