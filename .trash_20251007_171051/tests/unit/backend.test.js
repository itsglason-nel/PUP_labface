const request = require('supertest');
const app = require('../../backend/src/server');

describe('LabFace Backend Unit Tests', () => {
  describe('Authentication Middleware', () => {
    test('Should reject requests without token', async () => {
      const response = await request(app)
        .get('/api/classes')
        .expect(401);

      expect(response.body).toHaveProperty('error');
      expect(response.body.error).toContain('token');
    });

    test('Should reject requests with invalid token', async () => {
      const response = await request(app)
        .get('/api/classes')
        .set('Authorization', 'Bearer invalid_token')
        .expect(401);

      expect(response.body).toHaveProperty('error');
    });

    test('Should accept requests with valid token', async () => {
      // This test would require a valid JWT token
      // In a real test, you would generate a test token
      const response = await request(app)
        .get('/api/classes')
        .set('Authorization', 'Bearer valid_test_token')
        .expect(200);

      expect(Array.isArray(response.body)).toBe(true);
    });
  });

  describe('Input Validation', () => {
    test('Should validate professor registration data', async () => {
      const invalidData = {
        // Missing required fields
        email: 'invalid-email'
      };

      const response = await request(app)
        .post('/api/auth/professor/register')
        .send(invalidData)
        .expect(400);

      expect(response.body).toHaveProperty('error');
    });

    test('Should validate student registration data', async () => {
      const invalidData = {
        student_id: 'STU001',
        email: 'invalid-email',
        year_level: 'invalid'
      };

      const response = await request(app)
        .post('/api/auth/student/register')
        .send(invalidData)
        .expect(400);

      expect(response.body).toHaveProperty('error');
    });

    test('Should validate class creation data', async () => {
      const invalidData = {
        // Missing required fields
        subject: 'CS101'
      };

      const response = await request(app)
        .post('/api/classes')
        .set('Authorization', 'Bearer valid_test_token')
        .send(invalidData)
        .expect(400);

      expect(response.body).toHaveProperty('error');
    });
  });

  describe('Password Hashing', () => {
    test('Should hash passwords securely', async () => {
      const bcrypt = require('bcrypt');
      const password = 'test_password';
      const hashedPassword = await bcrypt.hash(password, 10);

      expect(hashedPassword).not.toBe(password);
      expect(hashedPassword).toMatch(/^\$2[aby]\$\d+\$/);
    });

    test('Should verify passwords correctly', async () => {
      const bcrypt = require('bcrypt');
      const password = 'test_password';
      const hashedPassword = await bcrypt.hash(password, 10);
      const isValid = await bcrypt.compare(password, hashedPassword);

      expect(isValid).toBe(true);
    });
  });

  describe('JWT Token Generation', () => {
    test('Should generate valid JWT tokens', () => {
      const jwt = require('jsonwebtoken');
      const payload = { user_id: '123', role: 'professor' };
      const secret = 'test_secret';
      const token = jwt.sign(payload, secret, { expiresIn: '1h' });

      expect(token).toBeDefined();
      expect(typeof token).toBe('string');
    });

    test('Should verify JWT tokens correctly', () => {
      const jwt = require('jsonwebtoken');
      const payload = { user_id: '123', role: 'professor' };
      const secret = 'test_secret';
      const token = jwt.sign(payload, secret, { expiresIn: '1h' });
      const decoded = jwt.verify(token, secret);

      expect(decoded.user_id).toBe('123');
      expect(decoded.role).toBe('professor');
    });
  });

  describe('Database Connection', () => {
    test('Should connect to database', async () => {
      const knex = require('knex')({
        client: 'mysql2',
        connection: {
          host: process.env.DB_HOST || 'localhost',
          user: process.env.DB_USER || 'root',
          password: process.env.DB_PASSWORD || '',
          database: process.env.DB_NAME || 'labface'
        }
      });

      const result = await knex.raw('SELECT 1 as test');
      expect(result[0][0].test).toBe(1);
    });
  });

  describe('MinIO Connection', () => {
    test('Should connect to MinIO', async () => {
      const Minio = require('minio');
      const minioClient = new Minio.Client({
        endPoint: process.env.MINIO_ENDPOINT || 'localhost',
        port: parseInt(process.env.MINIO_PORT || '9000'),
        useSSL: false,
        accessKey: process.env.MINIO_ACCESS_KEY || 'minioadmin',
        secretKey: process.env.MINIO_SECRET_KEY || 'minioadmin'
      });

      // Test connection by listing buckets
      const buckets = await minioClient.listBuckets();
      expect(Array.isArray(buckets)).toBe(true);
    });
  });

  describe('Socket.IO Integration', () => {
    test('Should initialize Socket.IO server', () => {
      const io = require('socket.io')(app);
      expect(io).toBeDefined();
    });

    test('Should handle connection events', (done) => {
      const io = require('socket.io')(app);
      const client = require('socket.io-client')('http://localhost:4000');

      client.on('connect', () => {
        expect(client.connected).toBe(true);
        client.disconnect();
        done();
      });
    });
  });

  describe('Error Handling', () => {
    test('Should handle database errors gracefully', async () => {
      // Mock database error
      const originalQuery = require('../../backend/src/config/database').knex.raw;
      require('../../backend/src/config/database').knex.raw = jest.fn().mockRejectedValue(new Error('Database error'));

      const response = await request(app)
        .get('/api/classes')
        .set('Authorization', 'Bearer valid_test_token')
        .expect(500);

      expect(response.body).toHaveProperty('error');
    });

    test('Should handle MinIO errors gracefully', async () => {
      // Mock MinIO error
      const originalGetObject = require('../../backend/src/config/minio').minioClient.getObject;
      require('../../backend/src/config/minio').minioClient.getObject = jest.fn().mockRejectedValue(new Error('MinIO error'));

      const response = await request(app)
        .post('/api/minio/presigned-url')
        .set('Authorization', 'Bearer valid_test_token')
        .send({
          object_name: 'test.jpg',
          content_type: 'image/jpeg'
        })
        .expect(500);

      expect(response.body).toHaveProperty('error');
    });
  });

  describe('Rate Limiting', () => {
    test('Should apply rate limiting to auth endpoints', async () => {
      const promises = [];
      
      // Make multiple requests to trigger rate limiting
      for (let i = 0; i < 10; i++) {
        promises.push(
          request(app)
            .post('/api/auth/professor/login')
            .send({
              email: 'test@example.com',
              password: 'password'
            })
        );
      }

      const responses = await Promise.all(promises);
      const rateLimited = responses.some(r => r.status === 429);
      
      expect(rateLimited).toBe(true);
    });
  });

  describe('CORS Configuration', () => {
    test('Should handle CORS preflight requests', async () => {
      const response = await request(app)
        .options('/api/classes')
        .set('Origin', 'http://localhost:3000')
        .set('Access-Control-Request-Method', 'GET')
        .set('Access-Control-Request-Headers', 'Authorization')
        .expect(200);

      expect(response.headers['access-control-allow-origin']).toBeDefined();
    });
  });

  describe('Logging', () => {
    test('Should log requests correctly', () => {
      const logger = require('../../backend/src/utils/logger');
      const logSpy = jest.spyOn(logger, 'info');
      
      logger.info('Test log message');
      
      expect(logSpy).toHaveBeenCalledWith('Test log message');
    });
  });

  describe('Environment Variables', () => {
    test('Should load environment variables correctly', () => {
      expect(process.env.NODE_ENV).toBeDefined();
      expect(process.env.PORT).toBeDefined();
      expect(process.env.DB_HOST).toBeDefined();
      expect(process.env.MINIO_ENDPOINT).toBeDefined();
    });
  });

  describe('API Endpoints Structure', () => {
    test('Should have all required routes', () => {
      const routes = app._router.stack
        .filter(layer => layer.route)
        .map(layer => layer.route.path);

      expect(routes).toContain('/api/health');
      expect(routes).toContain('/api/auth/professor/register');
      expect(routes).toContain('/api/auth/professor/login');
      expect(routes).toContain('/api/auth/student/register');
      expect(routes).toContain('/api/auth/student/login');
      expect(routes).toContain('/api/classes');
      expect(routes).toContain('/api/attendance/checkin');
      expect(routes).toContain('/api/presence_events');
      expect(routes).toContain('/api/minio/presigned-url');
      expect(routes).toContain('/api/cameras');
    });
  });
});
