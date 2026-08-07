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
- the existing Cloudflare Turnstile widget secret as `TURNSTILE_SECRET`;
- a unique secure cookie name and `COOKIE_SECURE=true`;
- optional initial SMTP host and credentials. After the first owner signs in,
  SMTP can be moved into the encrypted database-backed settings page.

Never commit `server/.env`.

The Turnstile site key is public and embedded in the Early Access form. Its
secret must exist only in `server/.env` as `TURNSTILE_SECRET`. Submissions fail
closed if the secret is missing or Cloudflare cannot verify the browser token.
The application sends the requesting IP to Cloudflare `siteverify` for abuse
verification but does not store the IP in CueGrove's database.

`DB_PASSWORD`, `JWT_SECRET`, cookie security, and the API port are boot-level
settings and intentionally remain in `server/.env`. The website never returns
these values to a browser. The SMTP password saved in the administrator UI is
encrypted with a key derived from `JWT_SECRET`; if `JWT_SECRET` is rotated,
re-enter the SMTP password in the UI.

### Google Workspace SMTP relay

For a server with a fixed public IP, Google Workspace can authenticate SMTP relay
traffic by IP without storing a Google account password. Add the server IP in
Google Admin Console under **Apps > Google Workspace > Gmail > Routing > SMTP
relay service**, restrict senders to your domain, and require TLS. Then use:

```dotenv
MAIL_ENABLED=true
SMTP_HOST=smtp-relay.gmail.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_AUTH_REQUIRED=false
SMTP_TIMEOUT_MS=20000
SMTP_HELO_NAME=mail.cuegroveapp.com
SMTP_USER=
SMTP_PASS=
SMTP_FROM=CueGrove <mooncci@cuegroveapp.com>
SMTP_REPLY_TO=mooncci@cuegroveapp.com
```

Keep `SMTP_AUTH_REQUIRED=true` for providers that authenticate with a username
and password.

For reliable Google relay delivery, create a DNS-only `A` record for the EHLO
hostname that points to the server public IP, and configure the server
provider's reverse DNS/PTR for that IP to the same hostname. Google can
temporarily reject connections whose EHLO name is not a fully qualified domain
name or whose forward and reverse DNS do not match.

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
If the live site already has a Content Security Policy, allow
`https://challenges.cloudflare.com` in `script-src`, `connect-src`, and
`frame-src` so the Turnstile widget can load and complete verification.

## 4. Finish setup in the administrator UI

Sign in at `/admin/login`, open Settings, and configure:

1. the current cohort;
2. the real PromptDock download URL;
3. the feedback URL;
4. the administrator notification email;
5. whether new applications should trigger notification email;
6. SMTP host, port, connection security, mailbox credentials, sender, and
   reply-to address.

Approvals remain disabled until the download URL is present. Use **Send test email** before reviewing applicants.

Owners can open **Administrators** to create or disable administrator accounts,
change `owner/admin` roles, clear login locks, and set a new password. At least
one active owner is always required. Public registration is intentionally not
available: visitors submit Early Access applications without creating an
account.

Environment SMTP values are used only as a fallback until an owner saves the
SMTP form. Passwords are encrypted at rest and are never displayed again.

## Updating an existing BaoTa deployment

From the project directory, update the same branch and apply all new migrations:

```bash
cd /www/wwwroot/cuegrove
git pull origin codex/cuegrove-site
pnpm install --frozen-lockfile
pnpm --dir server migrate
pnpm build
```

Then restart the `cuegrove-api` Node/PM2 project in BaoTa. Nginx should continue
serving `/www/wwwroot/cuegrove/dist` and proxying `/api/` to
`http://127.0.0.1:3001`. No new public registration route is required.

## Backup and recovery

- Back up the CueGrove MySQL database daily and retain at least 14 daily copies.
- Back up `server/.env` separately in an encrypted secrets manager.
- The static frontend can be recreated with `pnpm build`; do not treat `dist/` as the primary backup.
- Test a database restore before opening applications, and again after schema migrations.
- A failed result email does not undo a review decision. Open the application in the admin dashboard and use **Retry decision email**.
