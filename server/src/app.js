const express = require('express');
const cookieParser = require('cookie-parser');
const helmet = require('helmet');
const authRoutes = require('./routes/auth');
const earlyAccessRoutes = require('./routes/earlyAccess');
const adminRoutes = require('./routes/admin');
const feedbackRoutes = require('./routes/feedback');
const rollAccessRoutes = require('./routes/rollAccess');
const { requireSameOrigin } = require('./middleware/security');
const config = require('./config');

function createApp() {
  const app = express();
  app.set('trust proxy', config.trustProxyHops);
  app.use(helmet({
    crossOriginResourcePolicy: { policy: 'same-site' },
    contentSecurityPolicy: {
      useDefaults: false,
      directives: {
        defaultSrc: ["'none'"],
        baseUri: ["'none'"],
        formAction: ["'none'"],
        frameAncestors: ["'none'"],
      },
    },
  }));
  app.use(express.json({ limit: '32kb' }));
  app.use(cookieParser());
  app.use('/api', requireSameOrigin);
  app.get('/api/health', (_req, res) => res.json({ ok: true, service: 'cuegrove' }));
  app.use('/api/auth', authRoutes);
  app.use('/api/early-access', earlyAccessRoutes);
  app.use('/api/feedback', feedbackRoutes.router);
  app.use('/api/roll-access', rollAccessRoutes.publicRouter);
  app.use('/api/admin/feedback', feedbackRoutes.adminRouter);
  app.use('/api/admin/roll-access-keys', rollAccessRoutes.adminRouter);
  app.use('/api/admin', adminRoutes);

  app.use((req, res) => {
    res.status(404).json({ message: 'API route not found.' });
  });

  app.use((error, _req, res, _next) => {
    console.error('[server]', error);
    if (error.type === 'entity.parse.failed') {
      return res.status(400).json({ message: 'Request body must contain valid JSON.' });
    }
    if (['ER_NO_SUCH_TABLE', 'ER_BAD_DB_ERROR', 'ER_BAD_FIELD_ERROR'].includes(error.code)) {
      return res.status(503).json({ message: 'Database is not ready. Run the CueGrove migration.' });
    }
    return res.status(500).json({ message: 'The server could not complete this request.' });
  });
  return app;
}

module.exports = { createApp };
