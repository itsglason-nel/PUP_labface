import request from 'supertest';
import { app } from '../src/server';

describe('Authentication API', () => {
  describe('POST /api/auth/professor/register', () => {
    it('should register a new professor', async () => {
      const professorData = {
        professor_id: 'PROF001',
        first_name: 'John',
        last_name: 'Doe',
        email: 'john.doe@university.edu',
        password: 'secure_password123'
      };

      const response = await request(app)
        .post('/api/auth/professor/register')
        .send(professorData);

      expect(response.status).toBe(201);
      expect(response.body.message).toBe('Professor registered successfully');
    });

    it('should reject duplicate email', async () => {
      const professorData = {
        professor_id: 'PROF002',
        first_name: 'Jane',
        last_name: 'Smith',
        email: 'john.doe@university.edu', // Duplicate email
        password: 'secure_password123'
      };

      const response = await request(app)
        .post('/api/auth/professor/register')
        .send(professorData);

      expect(response.status).toBe(400);
      expect(response.body.error).toBe('Professor with this email already exists');
    });
  });

  describe('POST /api/auth/professor/login', () => {
    it('should login with valid credentials', async () => {
      const loginData = {
        email: 'john.doe@university.edu',
        password: 'secure_password123'
      };

      const response = await request(app)
        .post('/api/auth/professor/login')
        .send(loginData);

      expect(response.status).toBe(200);
      expect(response.body.token).toBeDefined();
      expect(response.body.user.type).toBe('professor');
    });

    it('should reject invalid credentials', async () => {
      const loginData = {
        email: 'john.doe@university.edu',
        password: 'wrong_password'
      };

      const response = await request(app)
        .post('/api/auth/professor/login')
        .send(loginData);

      expect(response.status).toBe(401);
      expect(response.body.error).toBe('Invalid credentials');
    });
  });

  describe('POST /api/auth/student/register', () => {
    it('should register a new student', async () => {
      const studentData = {
        student_id: 'STU001',
        first_name: 'Alice',
        last_name: 'Johnson',
        email: 'alice.johnson@student.edu',
        password: 'secure_password123',
        course: 'Computer Science',
        year_level: 2
      };

      const response = await request(app)
        .post('/api/auth/student/register')
        .send(studentData);

      expect(response.status).toBe(201);
      expect(response.body.message).toBe('Student registered successfully');
    });
  });
});
