const request = require('supertest');
const app = require('../../backend/src/server');

describe('LabFace API Integration Tests', () => {
  let professorToken;
  let studentToken;
  let classId;
  let sessionId;

  beforeAll(async () => {
    // Wait for services to be ready
    await new Promise(resolve => setTimeout(resolve, 5000));
  });

  describe('Health Checks', () => {
    test('Backend health check', async () => {
      const response = await request(app)
        .get('/api/health')
        .expect(200);

      expect(response.body).toHaveProperty('status');
      expect(response.body.status).toBe('healthy');
    });
  });

  describe('Authentication', () => {
    test('Professor registration', async () => {
      const professorData = {
        professor_id: 'PROF001',
        first_name: 'John',
        last_name: 'Doe',
        email: 'john.doe@university.edu',
        password: 'secure_password123'
      };

      const response = await request(app)
        .post('/api/auth/professor/register')
        .send(professorData)
        .expect(201);

      expect(response.body).toHaveProperty('message');
    });

    test('Professor login', async () => {
      const loginData = {
        email: 'john.doe@university.edu',
        password: 'secure_password123'
      };

      const response = await request(app)
        .post('/api/auth/professor/login')
        .send(loginData)
        .expect(200);

      expect(response.body).toHaveProperty('token');
      expect(response.body).toHaveProperty('user');
      professorToken = response.body.token;
    });

    test('Student registration', async () => {
      const studentData = {
        student_id: 'STU001',
        first_name: 'Jane',
        last_name: 'Smith',
        email: 'jane.smith@student.edu',
        password: 'secure_password123',
        course: 'Computer Science',
        year_level: 2
      };

      const response = await request(app)
        .post('/api/auth/student/register')
        .send(studentData)
        .expect(201);

      expect(response.body).toHaveProperty('message');
    });

    test('Student login', async () => {
      const loginData = {
        email: 'jane.smith@student.edu',
        password: 'secure_password123'
      };

      const response = await request(app)
        .post('/api/auth/student/login')
        .send(loginData)
        .expect(200);

      expect(response.body).toHaveProperty('token');
      expect(response.body).toHaveProperty('user');
      studentToken = response.body.token;
    });
  });

  describe('Classes Management', () => {
    test('Create class', async () => {
      const classData = {
        semester: 'Fall 2024',
        school_year: '2024-2025',
        subject: 'Computer Science 101',
        section: 'A'
      };

      const response = await request(app)
        .post('/api/classes')
        .set('Authorization', `Bearer ${professorToken}`)
        .send(classData)
        .expect(201);

      expect(response.body).toHaveProperty('class_id');
      classId = response.body.class_id;
    });

    test('Get classes', async () => {
      const response = await request(app)
        .get('/api/classes')
        .set('Authorization', `Bearer ${professorToken}`)
        .expect(200);

      expect(Array.isArray(response.body)).toBe(true);
    });

    test('Start session', async () => {
      const response = await request(app)
        .post(`/api/classes/${classId}/start`)
        .set('Authorization', `Bearer ${professorToken}`)
        .expect(201);

      expect(response.body).toHaveProperty('session_id');
      sessionId = response.body.session_id;
    });
  });

  describe('Attendance', () => {
    test('Check in', async () => {
      const checkinData = {
        session_id: sessionId,
        image_data: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/2wBDAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwA/8A8A'
      };

      const response = await request(app)
        .post('/api/attendance/checkin')
        .set('Authorization', `Bearer ${studentToken}`)
        .send(checkinData)
        .expect(200);

      expect(response.body).toHaveProperty('success');
    });

    test('Export attendance', async () => {
      const response = await request(app)
        .get(`/api/attendance/export?session_id=${sessionId}&format=csv`)
        .set('Authorization', `Bearer ${professorToken}`)
        .expect(200);

      expect(response.headers['content-type']).toContain('text/csv');
    });
  });

  describe('Presence Events', () => {
    test('Record presence event', async () => {
      const eventData = {
        session_id: sessionId,
        student_id: 'STU001',
        event_type: 'in',
        confidence: 0.95,
        details: {
          camera_id: 'CAM001',
          location: 'Room 101'
        }
      };

      const response = await request(app)
        .post('/api/presence_events')
        .set('Authorization', `Bearer ${professorToken}`)
        .send(eventData)
        .expect(201);

      expect(response.body).toHaveProperty('event_id');
    });

    test('Get presence events', async () => {
      const response = await request(app)
        .get(`/api/presence_events?session_id=${sessionId}`)
        .set('Authorization', `Bearer ${professorToken}`)
        .expect(200);

      expect(Array.isArray(response.body)).toBe(true);
    });
  });

  describe('MinIO Integration', () => {
    test('Get presigned URL', async () => {
      const response = await request(app)
        .post('/api/minio/presigned-url')
        .set('Authorization', `Bearer ${studentToken}`)
        .send({
          object_name: 'test-image.jpg',
          content_type: 'image/jpeg'
        })
        .expect(200);

      expect(response.body).toHaveProperty('upload_url');
      expect(response.body).toHaveProperty('object_url');
    });
  });

  describe('Camera Management', () => {
    test('Add camera', async () => {
      const cameraData = {
        camera_id: 'CAM001',
        name: 'Main Camera',
        rtsp_url: 'rtsp://192.168.1.100:554/stream',
        location: 'Room 101',
        is_active: true
      };

      const response = await request(app)
        .post('/api/cameras')
        .set('Authorization', `Bearer ${professorToken}`)
        .send(cameraData)
        .expect(201);

      expect(response.body).toHaveProperty('camera_id');
    });

    test('Get cameras', async () => {
      const response = await request(app)
        .get('/api/cameras')
        .set('Authorization', `Bearer ${professorToken}`)
        .expect(200);

      expect(Array.isArray(response.body)).toBe(true);
    });
  });

  describe('Error Handling', () => {
    test('Invalid authentication', async () => {
      await request(app)
        .get('/api/classes')
        .expect(401);
    });

    test('Invalid token', async () => {
      await request(app)
        .get('/api/classes')
        .set('Authorization', 'Bearer invalid_token')
        .expect(401);
    });

    test('Missing required fields', async () => {
      await request(app)
        .post('/api/auth/professor/register')
        .send({})
        .expect(400);
    });
  });

  describe('Rate Limiting', () => {
    test('Rate limiting on auth endpoints', async () => {
      const promises = [];
      
      // Make multiple requests to trigger rate limiting
      for (let i = 0; i < 10; i++) {
        promises.push(
          request(app)
            .post('/api/auth/professor/login')
            .send({
              email: 'john.doe@university.edu',
              password: 'wrong_password'
            })
        );
      }

      const responses = await Promise.all(promises);
      const rateLimited = responses.some(r => r.status === 429);
      
      // At least one request should be rate limited
      expect(rateLimited).toBe(true);
    });
  });

  afterAll(async () => {
    // Cleanup test data
    if (app && app.close) {
      await app.close();
    }
  });
});
