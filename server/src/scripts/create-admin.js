const bcrypt = require('bcryptjs');
const db = require('../db');
const { isEmail, normalizeEmail, passwordError, string } = require('../lib/validation');

function argument(name) {
  const index = process.argv.indexOf(`--${name}`);
  return index >= 0 ? process.argv[index + 1] : '';
}

async function run() {
  const name = string(argument('name'), 80);
  const email = normalizeEmail(argument('email'));
  const role = argument('role') === 'admin' ? 'admin' : 'owner';
  const password = process.env.CUEGROVE_ADMIN_PASSWORD || '';

  if (!name || !isEmail(email)) {
    throw new Error('Usage: npm run create-admin -- --name "Owner" --email owner@example.com [--role owner|admin]');
  }
  const invalidPassword = passwordError(password);
  if (invalidPassword) {
    throw new Error(`Set CUEGROVE_ADMIN_PASSWORD for this one command. ${invalidPassword}`);
  }

  const passwordHash = await bcrypt.hash(password, 12);
  await db.query(
    `INSERT INTO admin_users (name, email, password_hash, role, status)
     VALUES (?, ?, ?, ?, 'active')
     ON DUPLICATE KEY UPDATE name=VALUES(name), password_hash=VALUES(password_hash), role=VALUES(role), status='active', failed_login_count=0, locked_until=NULL, token_version=token_version+1`,
    [name, email, passwordHash, role],
  );
  delete process.env.CUEGROVE_ADMIN_PASSWORD;
  console.log(`[create-admin] ${role} account ready for ${email}`);
  await db.end();
}

run().catch(async (error) => {
  console.error('[create-admin] failed:', error.message);
  await db.end().catch(() => undefined);
  process.exit(1);
});
