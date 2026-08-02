const db = require('../db');
const readline = require('node:readline/promises');
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
  if (!process.stdin.isTTY || !process.stdout.isTTY) {
    throw new Error('This emergency command must be confirmed in an interactive terminal.');
  }
  const prompt = readline.createInterface({ input: process.stdin, output: process.stdout });
  const confirmation = normalizeEmail(await prompt.question(`Type ${email} to confirm MFA removal: `));
  prompt.close();
  if (confirmation !== email) throw new Error('Confirmation did not match the administrator email.');
  const [result] = await db.query(
    `UPDATE admin_users
     SET mfa_secret_encrypted=NULL, mfa_setup_expires_at=NULL, mfa_enabled_at=NULL,
         mfa_recovery_hashes=NULL, mfa_last_used_step=NULL,
         token_version=token_version+1
     WHERE email=?`,
    [email],
  );
  if (!result.affectedRows) throw new Error(`No administrator account found for ${email}.`);
  console.log(`[reset-mfa] ${new Date().toISOString()} MFA removed for ${email} by ${process.env.USER || 'unknown user'}`);
  await db.end();
}

run().catch(async (error) => {
  console.error('[reset-mfa] failed:', error.message);
  await db.end().catch(() => undefined);
  process.exit(1);
});
