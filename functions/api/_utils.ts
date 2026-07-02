// 共通ユーティリティ
export interface Env {
  DB: D1Database;
}

export function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}

export function errorResponse(message: string, status = 400): Response {
  return jsonResponse({ error: message }, status);
}

export async function parseJson<T = any>(request: Request): Promise<T | null> {
  try {
    return (await request.json()) as T;
  } catch {
    return null;
  }
}

/** RFC4122 v4 UUID */
export function uuid(): string {
  return crypto.randomUUID();
}

/**
 * 取引日時 (transaction_at) を正規化して JST '+09:00' 付き ISO8601 文字列を返す。
 *
 * - 'YYYY-MM-DD' のみが渡された場合: 'YYYY-MM-DDT00:00:00+09:00' として扱う
 *   （JST基準の当日0時。履歴編集で日付だけを変えた場合の標準的な扱い）
 * - 既に 'T' や '+' を含む ISO 文字列: そのまま返す
 * - 空文字 / null: null を返す（呼び出し側でエラー処理）
 *
 * この関数はサーバ側でのみ使い、クライアントは delivery_date (YYYY-MM-DD) を
 * 送るだけで良い。呼び出し側で毎回同じ変換をするための共通化。
 */
export function normalizeTransactionAt(date: string | null | undefined): string | null {
  if (!date) return null;
  const s = date.trim();
  if (!s) return null;
  // 既に時刻・タイムゾーンを含む
  if (s.includes('T') || s.includes(' ')) {
    // 'YYYY-MM-DD HH:MM:SS' 形式（SQLite 標準）は 'YYYY-MM-DDTHH:MM:SS+09:00' に変換
    if (s.includes(' ') && !s.includes('T')) {
      const noTz = s.replace(' ', 'T');
      if (!/[+\-Z]/.test(noTz.slice(10))) {
        return `${noTz}+09:00`;
      }
      return noTz;
    }
    // 'T' はあるがタイムゾーンなし → +09:00 を付与
    if (!/[+\-Z]/.test(s.slice(10))) {
      return `${s}+09:00`;
    }
    return s;
  }
  // 'YYYY-MM-DD' のみ → JST 0時に補完
  // 日付部分の妥当性チェックは最小限（10文字あればそのまま利用）
  const datePart = s.length >= 10 ? s.slice(0, 10) : s;
  return `${datePart}T00:00:00+09:00`;
}
