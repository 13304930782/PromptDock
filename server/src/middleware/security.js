const config = require('../config');

function requireSameOrigin(req, res, next) {
  if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) return next();
  const origin = req.get('origin');
  if (!origin || !config.allowedOrigins.has(origin)) {
    return res.status(403).json({ message: 'This request did not come from an allowed site origin.' });
  }
  next();
}

module.exports = { requireSameOrigin };
