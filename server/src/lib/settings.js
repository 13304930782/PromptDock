const db = require('../db');

const defaults = {
  early_access: {
    applications_open: true,
    cohort: 'promptdock-early-access-1',
    download_url: '',
    feedback_url: '',
    notify_email: '',
    notify_on_new_application: false,
  },
  mail_transport: {
    configured: false,
    enabled: false,
    host: '',
    port: 587,
    secure: false,
    auth_required: true,
    timeout_ms: 20000,
    helo_name: '',
    user: '',
    password_encrypted: '',
    from: '',
    reply_to: '',
  },
};

function parseSettingValue(value) {
  let parsed = value;
  if (Buffer.isBuffer(parsed)) parsed = parsed.toString('utf8');
  if (typeof parsed === 'string') parsed = JSON.parse(parsed);
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new Error('Stored setting must be a JSON object.');
  }
  return parsed;
}

async function getSetting(key) {
  const fallback = defaults[key];
  if (!fallback) throw new Error(`Unknown setting: ${key}`);
  const [rows] = await db.query('SELECT setting_value FROM site_settings WHERE setting_key=? LIMIT 1', [key]);
  if (!rows[0]) return { ...fallback };
  try {
    return { ...fallback, ...parseSettingValue(rows[0].setting_value) };
  } catch {
    return { ...fallback };
  }
}

async function saveSetting(key, value) {
  await db.query(
    `INSERT INTO site_settings (setting_key, setting_value)
     VALUES (?, ?)
     ON DUPLICATE KEY UPDATE setting_value=VALUES(setting_value), updated_at=CURRENT_TIMESTAMP`,
    [key, JSON.stringify(value)],
  );
  return value;
}

module.exports = { defaults, getSetting, parseSettingValue, saveSetting };
