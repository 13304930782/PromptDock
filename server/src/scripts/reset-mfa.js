const db = require('../db');
const { isEmail, normalizeEmail } = require('../lib/validation');

function argument(name) {
  const index = process.argv.indexOf(`--${name}`);
  return index >= 0 ? process.argv[index + 1] : '';
}

async function run() {
  const email = normalizeEmail(argument('email'));
  if (!isEmail(email)) {
    throw new Error('Usage: pnpm reset-mfa -- --email owner@example.com');
  }
  if (process.env.CUEGROVE_RESET_MFA !== 'YES') {
    throw new Error('Set CUEGROVE_RESET_MFA=YES for this one emergency recovery command.');
  }
  const [result] = await db.query(
    `UPDATE admin_users
     SET mfa_secret_encrypted=NULL, mfa_setup_expires_at=NULL, mfa_enabled_at=NULL,
         mfa_recovery_hashes=NULL, mfa_last_used_step=NULL
     WHERE email=?`,
    [email],
  );
  if (!result.affectedRows) throw new Error(`No administrator account found for ${email}.`);
  delete process.env.CUEGROVE_RESET_MFA;
  console.log(`[reset-mfa] multi-factor authentication removed for ${email}`);
  await db.end();
}

run().catch(async (error) => {
  console.error('[reset-mfa] failed:', error.message);
  await db.end().catch(() => undefined);
  process.exit(1);
});
