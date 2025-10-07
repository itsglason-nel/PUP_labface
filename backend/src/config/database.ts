import knex from 'knex';
import { logger } from '../utils/logger';

const db = knex({
  client: 'mysql2',
  connection: {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '3307'),
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || 'root123',
    database: process.env.DB_NAME || 'labface_db'
  },
  pool: {
    min: 2,
    max: 10
  }
});

export async function initializeDatabase() {
  try {
    // Test database connection
    await db.raw('SELECT 1');
    logger.info('Database connection established');
    
    // Run migrations if needed
    // Note: In production, migrations should be run separately
    // await db.migrate.latest();
    
    return db;
  } catch (error) {
    logger.error('Database connection failed:', error);
    throw error;
  }
}

export { db };
