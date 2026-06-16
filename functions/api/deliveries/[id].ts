// DELETE /api/deliveries/:id  納入履歴の削除
import { Env, errorResponse, jsonResponse } from '../_utils';

export const onRequestDelete: PagesFunction<Env> = async ({ env, params }) => {
  const id = params.id as string;
  if (!id) return errorResponse('id required');
  await env.DB.prepare(`DELETE FROM delivery_records WHERE id = ?1`)
    .bind(id)
    .run();
  return jsonResponse({ ok: true });
};
