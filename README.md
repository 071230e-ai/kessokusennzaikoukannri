# 結束線・タイワイヤ 在庫管理 (wire_stock_manager)

## Project Overview
- **Name**: wire_stock_manager / kessokusen-zaiko
- **Goal**: 本社工場・第二工場の結束線（メッキ／18番含む）・タイワイヤ在庫を全端末で共有管理
- **Features**:
  - 19品目 × 2拠点の在庫管理
  - 初期在庫設定 / 納入登録 / 出荷・使用登録（**複数明細対応**）
  - 履歴閲覧（納入 / 出荷・使用）
  - **履歴編集機能**（納入・出荷ともに日付／保管場所／品目／規格／数量／担当者／備考／仕入先/使用先を修正可能）
  - **期間集計**（任意期間の納入数量・出荷数量・差引数量を品目別に集計）
  - 修正後の在庫自動再計算・期間集計への自動反映
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
| PUT | `/api/deliveries/:id` | 納入記録の更新 |
| DELETE | `/api/deliveries/:id` | 納入記録削除 |
| GET | `/api/shipments` | 出荷・使用履歴一覧 |
| POST | `/api/shipments` | 出荷・使用記録 1件追加（在庫不足は HTTP 409） |
| PUT | `/api/shipments/:id` | 出荷・使用記録の更新（在庫不足は HTTP 409） |
| DELETE | `/api/shipments/:id` | 出荷・使用記録削除 |

複数明細登録は、画面側で明細ごとに POST を行うシンプルな実装（順次送信）です。
履歴の編集（PUT）は単一 UPDATE 文で実行され、在庫は `/api/stocks` 取得時に都度計算される
ため、PUT 1回で「旧数量取消＋新数量反映」が同時に成立します。出荷の編集時はサーバ側 SQL の
`WHERE id != ?` により編集対象自身の旧数量を除外して在庫判定するため、「変更前の数量を一度
戻した状態」での判定になります。

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
7. **履歴** で納入／出荷・使用の明細ごとの履歴を確認、必要に応じて「編集」ボタンから修正
8. **期間集計** で任意期間の納入・出荷・差引の集計を確認

## Tech Stack
- Frontend: Flutter Web 3.x（Provider）
- Backend: Cloudflare Pages Functions（TypeScript）
- Database: Cloudflare D1
- HTTP: `http: ^1.2.0`

## Deployment
- **Platform**: Cloudflare Pages
- **Status**: ✅ Active (v2.1 履歴編集対応)
- **Last Updated**: 2026-06-20
