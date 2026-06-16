module.exports = {
  apps: [
    {
      name: 'wire-stock-manager',
      script: 'npx',
      args: 'http-server build/web -p 3000 -a 0.0.0.0 -c-1 --cors',
      cwd: '/home/user/webapp',
      env: {
        NODE_ENV: 'development',
        PORT: 3000
      },
      watch: false,
      instances: 1,
      exec_mode: 'fork'
    }
  ]
}
