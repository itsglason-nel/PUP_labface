import { Router } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { db } from '../config/database';
import { validateRequest, authSchemas } from '../middleware/validation';
import { createError } from '../middleware/errorHandler';
import { logger } from '../utils/logger';

const router = Router();

// Professor registration
router.post('/professor/register', validateRequest(authSchemas.professorRegister), async (req, res, next) => {
  try {
    const { professor_id, first_name, last_name, email, password } = req.body;

    // Check if professor already exists
    const existingProfessor = await db('professors').where({ email }).first();
    if (existingProfessor) {
      return res.status(400).json({ error: 'Professor with this email already exists' });
    }

    // Hash password
    const password_hash = await bcrypt.hash(password, 12);

    // Create professor
    await db('professors').insert({
      professor_id,
      first_name,
      last_name,
      email,
      password_hash
    });

    logger.info(`Professor registered: ${email}`);

    res.status(201).json({ 
      message: 'Professor registered successfully',
      professor_id 
    });
  } catch (error) {
    next(error);
  }
});

// Professor login
router.post('/professor/login', validateRequest(authSchemas.professorLogin), async (req, res, next) => {
  try {
    const { email, password } = req.body;

    // Find professor
    const professor = await db('professors').where({ email }).first();
    if (!professor) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Verify password
    const isValidPassword = await bcrypt.compare(password, professor.password_hash);
    if (!isValidPassword) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Generate JWT
    const token = jwt.sign(
      { 
        id: professor.professor_id, 
        type: 'professor', 
        email: professor.email 
      },
      process.env.JWT_SECRET || 'change_me',
      { expiresIn: '24h' }
    );

    logger.info(`Professor logged in: ${email}`);

    res.json({
      token,
      user: {
        id: professor.professor_id,
        type: 'professor',
        email: professor.email,
        first_name: professor.first_name,
        last_name: professor.last_name
      }
    });
  } catch (error) {
    next(error);
  }
});

// Student registration (3-step process)
router.post('/student/register', validateRequest(authSchemas.studentRegister), async (req, res, next) => {
  try {
    const { 
      student_id, 
      first_name, 
      middle_name, 
      last_name, 
      course, 
      year_level, 
      email, 
      mobile, 
      password 
    } = req.body;

    // Check if student already exists
    const existingStudent = await db('students').where({ email }).first();
    if (existingStudent) {
      return res.status(400).json({ error: 'Student with this email already exists' });
    }

    // Hash password
    const password_hash = await bcrypt.hash(password, 12);

    // Create student
    await db('students').insert({
      student_id,
      first_name,
      middle_name,
      last_name,
      course,
      year_level,
      email,
      mobile,
      password_hash
    });

    logger.info(`Student registered: ${email}`);

    res.status(201).json({ 
      message: 'Student registered successfully',
      student_id 
    });
  } catch (error) {
    next(error);
  }
});

// Student login
router.post('/student/login', validateRequest(authSchemas.studentLogin), async (req, res, next) => {
  try {
    const { email, password } = req.body;

    // Find student
    const student = await db('students').where({ email }).first();
    if (!student) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Verify password
    const isValidPassword = await bcrypt.compare(password, student.password_hash);
    if (!isValidPassword) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Generate JWT
    const token = jwt.sign(
      { 
        id: student.student_id, 
        type: 'student', 
        email: student.email 
      },
      process.env.JWT_SECRET || 'change_me',
      { expiresIn: '24h' }
    );

    logger.info(`Student logged in: ${email}`);

    res.json({
      token,
      user: {
        id: student.student_id,
        type: 'student',
        email: student.email,
        first_name: student.first_name,
        last_name: student.last_name
      }
    });
  } catch (error) {
    next(error);
  }
});

export default router;
