# Project agent instructions

## Deployment handoff

- After completing changes that can be deployed, always include copyable deployment commands in the final response.
- The CueGrove production application is managed as the `cuegrove-api` Node project in the BaoTa panel.
- Never run, recommend, or include PM2 lifecycle or persistence commands for this project, including `pm2 start`, `pm2 stop`, `pm2 restart`, `pm2 reload`, `pm2 startOrReload`, `pm2 delete`, and `pm2 save`.
- Deployment commands should cover only the applicable code update, dependency installation, database migration, tests, frontend build, and health checks.
- After the server-side build is complete, explicitly tell the user: `请在宝塔面板中手动重启 Node 项目 cuegrove-api。`
- Run or suggest public API health checks only after the user has restarted the project in BaoTa. The health endpoint is `https://cuegroveapp.com/api/health`.
- Only include Nginx validation or reload commands when Nginx configuration changed as part of the task.

The standard CueGrove server update commands are:

```bash
cd /www/wwwroot/cuegrove
git pull --ff-only origin codex/cuegrove-site
pnpm install --frozen-lockfile
pnpm --dir server migrate
pnpm test
pnpm build
```

Then tell the user to restart `cuegrove-api` manually in BaoTa. Do not append PM2 commands.
