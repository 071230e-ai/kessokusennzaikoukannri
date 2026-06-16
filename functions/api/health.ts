// GET /api/health  動作確認用
import { Env, jsonResponse } from './_utils';

export const onRequestGet: PagesFunction<Env> = async ({ env }) => {
  const result = await env.DB.prepare('SELECT 1 AS ok').first<any>();
  return jsonResponse({
    ok: result?.ok === 1,
    time: new Date().toISOString(),
  });
};
