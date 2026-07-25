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
};

async function getSetting(key) {
  const fallback = defaults[key];
  if (!fallback) throw new Error(`Unknown setting: ${key}`);
  const [rows] = await db.query('SELECT setting_value FROM site_settings WHERE setting_key=? LIMIT 1', [key]);
  if (!rows[0]) return { ...fallback };
  try {
    return { ...fallback, ...JSON.parse(rows[0].setting_value) };
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

module.exports = { defaults, getSetting, saveSetting };
