// PM2 設定: Cloudflare Pages + Functions + D1 をローカル実行
//
// `wrangler pages dev` は build/web の静的ファイルを配信しつつ、
// functions/ ディレクトリ配下を /api/* として処理し、
// --d1=DB によりローカル SQLite が DB バインドにマップされる。
module.exports = {
  apps: [
    {
      name: 'wire-stock-manager',
      script: 'npx',
      args:
        'wrangler pages dev build/web --ip 0.0.0.0 --port 3000',
      env: { NODE_ENV: 'development' },
      watch: false,
      instances: 1,
      exec_mode: 'fork',
    },
  ],
};
