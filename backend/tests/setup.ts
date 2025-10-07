import { db } from '../src/config/database';

// Test database setup
beforeAll(async () => {
  // Initialize test database connection
  await db.raw('SELECT 1');
});

afterAll(async () => {
  // Close database connection
  await db.destroy();
});

// Clean up after each test
afterEach(async () => {
  // Clean up test data if needed
  // await db('test_table').del();
});
