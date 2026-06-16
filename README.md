# 結束線・タイワイヤ 在庫管理 (wire_stock_manager)

## Project Overview
- **Name**: wire_stock_manager / kessokusen-zaiko
- **Goal**: 本社工場・第二工場の結束線（メッキ／18番含む）・タイワイヤ在庫を全端末で共有管理
- **Features**:
  - 19品目 × 2拠点の在庫管理
  - 初期在庫設定 / 納入登録 / 出荷・使用登録（**複数明細対応**）
  - 履歴閲覧（納入 / 出荷・使用）
  - Cloudflare D1 共有DBによる全端末データ共有
  - パスワード認証（`zaiko`）

## URLs
- **Production**: https://kessokusen-zaiko.pages.dev
- **Preview (sandbox)**: 別途 `GetServiceUrl` で発行

## API endpoints
| Method | Path | 説明 |
|---|---|---|
| GET | `/api/health` | ヘルスチェック |
| GET | `/api/items` | 品目マスター |
| GET | `/api/locations` | 保管場所マスター |
| GET | `/api/stocks` | 全在庫（current_stock 算出済み） |
| POST | `/api/initial-stock` | 初期在庫の upsert |
| GET | `/api/deliveries` | 納入履歴一覧 |
| POST | `/api/deliveries` | 納入記録 1件追加 |
| DELETE | `/api/deliveries/:id` | 納入記録削除 |
| GET | `/api/shipments` | 出荷・使用履歴一覧 |
| POST | `/api/shipments` | 出荷・使用記録 1件追加（在庫不足は HTTP 409） |
| DELETE | `/api/shipments/:id` | 出荷・使用記録削除 |

複数明細登録は、画面側で明細ごとに POST を行うシンプルな実装（順次送信）です。

## Data Architecture
- **Storage**: Cloudflare D1（SQLite at the edge）
- **Database**: `kessokusen-zaiko-db`
- **Tables**:
  - `locations` — 保管場所マスター（本社工場 / 第二工場）
  - `items` — 品目マスター（19品目）
  - `initial_stocks` — 拠点別初期在庫（UNIQUE(item_id, location_id)）
  - `delivery_records` — 納入履歴（UUID PK）
  - `shipping_records` — 出荷・使用履歴（UUID PK）
- **current_stock の算出**: `initial_stock + Σ deliveries - Σ shipments`（`/api/stocks` でSQL集計）

## User Guide
1. ブラウザでアプリにアクセス
2. パスワード `zaiko` でログイン
3. **初期在庫設定** → 拠点別の初期在庫を入力
4. **納入登録** → 共通項目（日付・保管場所・備考）+ 複数明細（品目・規格・数量）を一括登録
5. **出荷・使用登録** → 共通項目（日付・保管場所・出荷先・備考）+ 複数明細を一括登録（在庫不足チェックあり）
6. **在庫一覧** で現在庫を拠点別に確認
7. **履歴** で納入／出荷・使用の明細ごとの履歴を確認

## Tech Stack
- Frontend: Flutter Web 3.x（Provider）
- Backend: Cloudflare Pages Functions（TypeScript）
- Database: Cloudflare D1
- HTTP: `http: ^1.2.0`

## Deployment
- **Platform**: Cloudflare Pages
- **Status**: ✅ Active (v2.0 共有DB版)
- **Last Updated**: 2026-06-16
