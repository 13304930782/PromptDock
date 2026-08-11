const config = require('./config');
const db = require('./db');
const { createApp } = require('./app');

async function start() {
  if (!config.db.database || !config.db.user) {
    throw new Error('DB_NAME and DB_USER must be configured.');
  }
  await db.query('SELECT 1');
  const app = createApp();
  const server = app.listen(config.port, '127.0.0.1', () => {
    console.log(`[cuegrove] API listening on http://127.0.0.1:${config.port}`);
  });

  const shutdown = async () => {
    server.close(async () => {
      await db.end();
      process.exit(0);
    });
  };
  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);
}

start().catch((error) => {
  console.error('[cuegrove] Failed to start:', error.message);
  process.exit(1);
});
