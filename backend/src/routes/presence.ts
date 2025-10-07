import { Router } from 'express';
import { db } from '../config/database';
import { authenticateToken, AuthRequest } from '../middleware/auth';
import { broadcastPresenceEvent } from '../config/socketio';
import { createError } from '../middleware/errorHandler';
import { logger } from '../utils/logger';

const router = Router();

// Record presence event (from CCTV/ML pipeline)
router.post('/', async (req, res, next) => {
  try {
    const { session_id, student_id, event_type, source, details } = req.body;

    // Validate required fields
    if (!session_id || !student_id || !event_type) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    // Verify session exists
    const session = await db('sessions')
      .where({ session_id, status: 'open' })
      .first();

    if (!session) {
      return res.status(400).json({ error: 'Session not found or not active' });
    }

    // Create presence event
    const [eventId] = await db('presence_events').insert({
      session_id,
      student_id,
      event_type,
      source: source || 'cctv',
      details: details ? JSON.stringify(details) : null
    });

    // Update attendance record based on event type
    if (event_type === 'in') {
      // Check if student is late
      const isLate = isStudentLate(session.start_ts);
      const status = isLate ? 'late' : 'present';

      await db('attendance')
        .insert({
          session_id,
          student_id,
          status,
          checkin_ts: new Date(),
          selfie_url: details?.image_url || null
        })
        .onConflict(['session_id', 'student_id'])
        .merge();
    } else if (event_type === 'out') {
      // Update checkout time
      await db('attendance')
        .where({ session_id, student_id })
        .update({
          checkout_ts: new Date()
        });
    }

    // Broadcast presence event
    broadcastPresenceEvent(req.app.get('io'), session_id.toString(), {
      event_id: eventId,
      student_id,
      event_type,
      timestamp: new Date(),
      source: source || 'cctv',
      details
    });

    logger.info(`Presence event recorded: ${event_type} for student ${student_id} in session ${session_id}`);

    res.status(201).json({
      success: true,
      event_id: eventId,
      message: 'Presence event recorded'
    });
  } catch (error) {
    next(error);
  }
});

// Get presence events for a session
router.get('/', authenticateToken, async (req: AuthRequest, res, next) => {
  try {
    const { session_id } = req.query;

    if (!session_id) {
      return res.status(400).json({ error: 'Session ID required' });
    }

    // Get presence events
    const events = await db('presence_events')
      .join('students', 'presence_events.student_id', 'students.student_id')
      .where('presence_events.session_id', session_id)
      .select(
        'presence_events.*',
        'students.first_name',
        'students.last_name',
        'students.email'
      )
      .orderBy('presence_events.event_ts', 'desc');

    res.json(events);
  } catch (error) {
    next(error);
  }
});

// Get real-time presence events (WebSocket alternative)
router.get('/realtime/:session_id', authenticateToken, async (req: AuthRequest, res, next) => {
  try {
    const sessionId = req.params.session_id;

    // Get recent events (last 100)
    const events = await db('presence_events')
      .join('students', 'presence_events.student_id', 'students.student_id')
      .where('presence_events.session_id', sessionId)
      .select(
        'presence_events.*',
        'students.first_name',
        'students.last_name',
        'students.email'
      )
      .orderBy('presence_events.event_ts', 'desc')
      .limit(100);

    res.json(events);
  } catch (error) {
    next(error);
  }
});

// Helper function to check if student is late
function isStudentLate(sessionStart: Date): boolean {
  const lateThresholdMinutes = parseInt(process.env.LATE_THRESHOLD_MINUTES || '30');
  const now = new Date();
  const sessionStartTime = new Date(sessionStart);
  const diffMinutes = (now.getTime() - sessionStartTime.getTime()) / (1000 * 60);
  
  return diffMinutes > lateThresholdMinutes;
}

export default router;
