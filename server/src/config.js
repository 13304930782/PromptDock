const path = require('path');
const dotenv = require('dotenv');

dotenv.config({ path: path.resolve(__dirname, '..', '.env') });

function bool(value, fallback = false) {
  if (value === undefined || value === null || value === '') return fallback;
  return String(value).toLowerCase() === 'true';
}

function int(value, fallback) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function cleanOrigin(value) {
  try {
    return new URL(value).origin;
  } catch {
    return '';
  }
}

const siteUrl = process.env.SITE_URL || 'http://localhost:5173';
const allowedOrigins = new Set(
  [siteUrl, ...(process.env.ALLOWED_ORIGINS || '').split(',')]
    .map((value) => cleanOrigin(value.trim()))
    .filter(Boolean),
);

module.exports = {
  env: process.env.NODE_ENV || 'development',
  port: int(process.env.PORT, 3001),
  siteUrl: cleanOrigin(siteUrl) || 'http://localhost:5173',
  allowedOrigins,
  db: {
    host: process.env.DB_HOST || '127.0.0.1',
    port: int(process.env.DB_PORT, 3306),
    user: process.env.DB_USER || '',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || '',
    connectionLimit: int(process.env.DB_CONNECTION_LIMIT, 10),
  },
  jwtSecret: process.env.JWT_SECRET || '',
  cookie: {
    name: process.env.COOKIE_NAME || 'cuegrove_admin',
    secure: bool(process.env.COOKIE_SECURE, process.env.NODE_ENV === 'production'),
    domain: (process.env.COOKIE_DOMAIN || '').trim(),
  },
  mail: {
    enabled: bool(process.env.MAIL_ENABLED),
    host: process.env.SMTP_HOST || '',
    port: int(process.env.SMTP_PORT, 465),
    secure: bool(process.env.SMTP_SECURE, true),
    authRequired: bool(process.env.SMTP_AUTH_REQUIRED, true),
    user: process.env.SMTP_USER || '',
    pass: process.env.SMTP_PASS || '',
    from: process.env.SMTP_FROM || process.env.SMTP_USER || '',
    replyTo: process.env.SMTP_REPLY_TO || '',
  },
  passwordResetMinutes: int(process.env.PASSWORD_RESET_MINUTES, 30),
};
