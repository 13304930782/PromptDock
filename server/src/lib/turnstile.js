const config = require('../config');

const SITEVERIFY_URL = 'https://challenges.cloudflare.com/turnstile/v0/siteverify';
const VERIFY_TIMEOUT_MS = 10000;

async function verifyTurnstile({
  token,
  remoteIp,
  secret = config.turnstileSecret,
  fetchImpl = globalThis.fetch,
}) {
  if (!secret) return { success: false, reason: 'missing-secret' };
  if (!token) return { success: false, reason: 'missing-response' };

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), VERIFY_TIMEOUT_MS);

  try {
    const response = await fetchImpl(SITEVERIFY_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        secret,
        response: token,
        remoteip: remoteIp,
      }),
      signal: controller.signal,
    });
    const result = await response.json();
    const success = response.ok && result.success === true;
    return {
      success,
      reason: success ? 'verified' : (response.ok ? 'rejected' : 'unavailable'),
      errorCodes: Array.isArray(result['error-codes']) ? result['error-codes'] : [],
    };
  } catch {
    return { success: false, reason: 'unavailable' };
  } finally {
    clearTimeout(timer);
  }
}

module.exports = {
  SITEVERIFY_URL,
  verifyTurnstile,
};
