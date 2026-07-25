# CueGrove website deployment

The CueGrove website is isolated from the PromptDock app and from Mooncci. It uses a Vite static frontend, a PM2-managed Express API, MySQL, and SMTP.

## 1. Prepare isolated services

Create a new MySQL database and user for CueGrove. Do not reuse Mooncci tables or credentials.

```sql
CREATE DATABASE cuegrove CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'cuegrove'@'127.0.0.1' IDENTIFIED BY 'replace-with-a-strong-password';
GRANT ALL PRIVILEGES ON cuegrove.* TO 'cuegrove'@'127.0.0.1';
FLUSH PRIVILEGES;
```

Copy `server/.env.example` to `server/.env` and configure:

- the production `SITE_URL` and `ALLOWED_ORIGINS`;
- the isolated database credentials;
- a random `JWT_SECRET` of at least 32 characters;
- a unique secure cookie name and `COOKIE_SECURE=true`;
- SMTP host, credentials, verified CueGrove sender, and optional reply-to address.

Never commit `server/.env`.

## 2. Install, migrate, and create the owner

```bash
pnpm install
pnpm --dir server migrate
read -s CUEGROVE_ADMIN_PASSWORD
export CUEGROVE_ADMIN_PASSWORD
pnpm --dir server create-admin -- --name "CueGrove Owner" --email owner@example.com --role owner
unset CUEGROVE_ADMIN_PASSWORD
pnpm build
```

The owner bootstrap command hashes the password with bcrypt and never writes it to a file.

## 3. Run behind Nginx

Copy `dist/` to the site root, start the API with:

```bash
pm2 start server/ecosystem.config.cjs
pm2 save
```

Adapt `server/nginx.cuegrove.conf.example`, enable HTTPS, then reload Nginx. The frontend and `/api` must share one origin for the administrator cookie and origin checks.

## 4. Finish Early Access setup

Sign in at `/admin/login`, open Settings, and configure:

1. the current cohort;
2. the real PromptDock download URL;
3. the feedback URL;
4. the administrator notification email;
5. whether new applications should trigger notification email.

Approvals remain disabled until the download URL is present. Use **Send test email** before reviewing applicants.

## Backup and recovery

- Back up the CueGrove MySQL database daily and retain at least 14 daily copies.
- Back up `server/.env` separately in an encrypted secrets manager.
- The static frontend can be recreated with `pnpm build`; do not treat `dist/` as the primary backup.
- Test a database restore before opening applications, and again after schema migrations.
- A failed result email does not undo a review decision. Open the application in the admin dashboard and use **Retry decision email**.
