// GET /api/locations  保管場所一覧
import { Env, jsonResponse } from './_utils';

export const onRequestGet: PagesFunction<Env> = async ({ env }) => {
  const result = await env.DB.prepare(
    `SELECT id, name, sort_order FROM locations ORDER BY sort_order ASC`
  ).all();
  return jsonResponse({ locations: result.results ?? [] });
};
