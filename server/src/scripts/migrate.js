const fs = require('fs/promises');
const path = require('path');
const mysql = require('mysql2/promise');
const config = require('../config');

async function run() {
  const connection = await mysql.createConnection({
    ...config.db,
    multipleStatements: true,
    charset: 'utf8mb4',
    timezone: 'Z',
  });
  const directory = path.resolve(__dirname, '..', '..', 'database', 'migrations');
  const files = (await fs.readdir(directory)).filter((name) => name.endsWith('.sql')).sort();
  await connection.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      migration_name VARCHAR(255) NOT NULL PRIMARY KEY,
      applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  for (const file of files) {
    const [rows] = await connection.query(
      'SELECT migration_name FROM schema_migrations WHERE migration_name=? LIMIT 1',
      [file],
    );
    if (rows[0]) {
      console.log(`[migrate] already applied: ${file}`);
      continue;
    }
    const sql = await fs.readFile(path.join(directory, file), 'utf8');
    await connection.beginTransaction();
    try {
      await connection.query(sql);
      await connection.query('INSERT INTO schema_migrations (migration_name) VALUES (?)', [file]);
      await connection.commit();
      console.log(`[migrate] applied: ${file}`);
    } catch (error) {
      await connection.rollback();
      throw error;
    }
  }
  await connection.end();
}

run().catch((error) => {
  console.error('[migrate] failed:', error.message);
  process.exit(1);
});
