import { Router } from 'express';
import { db } from '../config/database';
import { authenticateToken, requireProfessor, AuthRequest } from '../middleware/auth';
import { validateRequest, classSchemas } from '../middleware/validation';
import { broadcastSessionStatus } from '../config/socketio';
import { createError } from '../middleware/errorHandler';
import { logger } from '../utils/logger';

const router = Router();

// Get classes (professor-specific)
router.get('/', authenticateToken, async (req: AuthRequest, res, next) => {
  try {
    let query = db('classes')
      .select('classes.*', 'professors.first_name', 'professors.last_name')
      .leftJoin('professors', 'classes.professor_id', 'professors.professor_id');

    // If user is professor, only show their classes
    if (req.user?.type === 'professor') {
      query = query.where('classes.professor_id', req.user.id);
    }

    const classes = await query.orderBy('classes.created_at', 'desc');

    res.json(classes);
  } catch (error) {
    next(error);
  }
});

// Create class
router.post('/', authenticateToken, requireProfessor, validateRequest(classSchemas.createClass), async (req: AuthRequest, res, next) => {
  try {
    const { semester, school_year, subject, section } = req.body;

    const [classId] = await db('classes').insert({
      semester,
      school_year,
      subject,
      section,
      professor_id: req.user!.id
    });

    logger.info(`Class created: ${subject} by professor ${req.user!.id}`);

    res.status(201).json({ 
      message: 'Class created successfully',
      class_id: classId 
    });
  } catch (error) {
    next(error);
  }
});

// Update class
router.put('/:id', authenticateToken, requireProfessor, validateRequest(classSchemas.updateClass), async (req: AuthRequest, res, next) => {
  try {
    const classId = parseInt(req.params.id);
    const updates = req.body;

    // Verify class belongs to professor
    const existingClass = await db('classes')
      .where({ class_id: classId, professor_id: req.user!.id })
      .first();

    if (!existingClass) {
      return res.status(404).json({ error: 'Class not found' });
    }

    await db('classes')
      .where({ class_id: classId })
      .update(updates);

    logger.info(`Class updated: ${classId} by professor ${req.user!.id}`);

    res.json({ message: 'Class updated successfully' });
  } catch (error) {
    next(error);
  }
});

// Start attendance session
router.post('/:id/start', authenticateToken, requireProfessor, async (req: AuthRequest, res, next) => {
  try {
    const classId = parseInt(req.params.id);

    // Verify class belongs to professor
    const existingClass = await db('classes')
      .where({ class_id: classId, professor_id: req.user!.id })
      .first();

    if (!existingClass) {
      return res.status(404).json({ error: 'Class not found' });
    }

    // Check if there's already an active session
    const activeSession = await db('sessions')
      .where({ class_id: classId, status: 'open' })
      .first();

    if (activeSession) {
      return res.status(400).json({ error: 'Session already active for this class' });
    }

    // Create new session
    const [sessionId] = await db('sessions').insert({
      class_id: classId,
      session_date: new Date().toISOString().split('T')[0],
      start_ts: new Date(),
      status: 'open'
    });

    // Broadcast session started
    broadcastSessionStatus(req.app.get('io'), sessionId.toString(), 'started');

    logger.info(`Session started: ${sessionId} for class ${classId}`);

    res.status(201).json({ 
      message: 'Session started successfully',
      session_id: sessionId 
    });
  } catch (error) {
    next(error);
  }
});

// Stop attendance session
router.post('/:id/stop', authenticateToken, requireProfessor, async (req: AuthRequest, res, next) => {
  try {
    const classId = parseInt(req.params.id);

    // Find active session
    const activeSession = await db('sessions')
      .where({ class_id: classId, status: 'open' })
      .first();

    if (!activeSession) {
      return res.status(400).json({ error: 'No active session found' });
    }

    // Update session
    await db('sessions')
      .where({ session_id: activeSession.session_id })
      .update({
        end_ts: new Date(),
        status: 'closed'
      });

    // Broadcast session stopped
    broadcastSessionStatus(req.app.get('io'), activeSession.session_id.toString(), 'stopped');

    logger.info(`Session stopped: ${activeSession.session_id} for class ${classId}`);

    res.json({ message: 'Session stopped successfully' });
  } catch (error) {
    next(error);
  }
});

// Get session history
router.get('/:id/sessions', authenticateToken, requireProfessor, async (req: AuthRequest, res, next) => {
  try {
    const classId = parseInt(req.params.id);

    // Verify class belongs to professor
    const existingClass = await db('classes')
      .where({ class_id: classId, professor_id: req.user!.id })
      .first();

    if (!existingClass) {
      return res.status(404).json({ error: 'Class not found' });
    }

    const sessions = await db('sessions')
      .where({ class_id: classId })
      .orderBy('created_at', 'desc');

    res.json(sessions);
  } catch (error) {
    next(error);
  }
});

// Force absent computation
router.post('/sessions/:session_id/force-absent', authenticateToken, requireProfessor, async (req: AuthRequest, res, next) => {
  try {
    const sessionId = parseInt(req.params.session_id);

    // Get session details
    const session = await db('sessions')
      .join('classes', 'sessions.class_id', 'classes.class_id')
      .where('sessions.session_id', sessionId)
      .andWhere('classes.professor_id', req.user!.id)
      .first();

    if (!session) {
      return res.status(404).json({ error: 'Session not found' });
    }

    // Get all enrolled students
    const enrolledStudents = await db('class_students')
      .where('class_id', session.class_id)
      .select('student_id');

    // Get students who have checked in
    const presentStudents = await db('attendance')
      .where('session_id', sessionId)
      .whereIn('status', ['present', 'late'])
      .select('student_id');

    const presentStudentIds = presentStudents.map(s => s.student_id);

    // Mark absent students
    const absentStudents = enrolledStudents.filter(
      s => !presentStudentIds.includes(s.student_id)
    );

    if (absentStudents.length > 0) {
      const attendanceRecords = absentStudents.map(student => ({
        session_id: sessionId,
        student_id: student.student_id,
        status: 'absent',
        checkin_ts: new Date()
      }));

      await db('attendance').insert(attendanceRecords);
    }

    logger.info(`Force absent completed for session ${sessionId}: ${absentStudents.length} students marked absent`);

    res.json({ 
      message: 'Absent computation completed',
      absent_count: absentStudents.length 
    });
  } catch (error) {
    next(error);
  }
});

export default router;
