const ALLOWED_ROLES = new Set(['student', 'creator', 'developer', 'researcher', 'product', 'other']);

function string(value, max = 1000) {
  return String(value == null ? '' : value).trim().slice(0, max);
}

function normalizeEmail(value) {
  return string(value, 160).toLowerCase();
}

function isEmail(value) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function isHttpUrl(value, allowEmpty = true) {
  if (!value) return allowEmpty;
  try {
    const parsed = new URL(value);
    return parsed.protocol === 'https:' || parsed.protocol === 'http:';
  } catch {
    return false;
  }
}

function passwordError(password) {
  if (typeof password !== 'string' || password.length < 8 || password.length > 200) {
    return 'Password must be between 8 and 200 characters.';
  }
  if (!/[A-Za-z]/.test(password) || !/\d/.test(password)) {
    return 'Password must include both letters and numbers.';
  }
  return '';
}

function validateApplication(body = {}) {
  const value = {
    fullName: string(body.full_name, 80),
    email: normalizeEmail(body.email),
    role: string(body.role, 40),
    useCase: string(body.use_case, 1500),
    motivation: string(body.motivation, 1500),
    locale: body.locale === 'en' ? 'en' : 'zh',
    consent: body.consent === true,
    honeypot: string(body.company_website, 300),
  };

  if (value.honeypot) return { ok: false, silent: true, value };
  if (!value.fullName || value.fullName.length < 2) return { ok: false, message: 'Please provide your name.', value };
  if (!isEmail(value.email)) return { ok: false, message: 'Please provide a valid email address.', value };
  if (!ALLOWED_ROLES.has(value.role)) return { ok: false, message: 'Please select a role.', value };
  if (value.useCase.length < 10) return { ok: false, message: 'Please tell us a little more about your use case.', value };
  if (value.motivation.length < 10) return { ok: false, message: 'Please tell us a little more about your motivation.', value };
  if (!value.consent) return { ok: false, message: 'Please accept the privacy notice.', value };
  return { ok: true, value };
}

module.exports = {
  ALLOWED_ROLES,
  isEmail,
  isHttpUrl,
  normalizeEmail,
  passwordError,
  string,
  validateApplication,
};
