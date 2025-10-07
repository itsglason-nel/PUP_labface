import { Router } from 'express';
import { db } from '../config/database';
import { authenticateToken, AuthRequest } from '../middleware/auth';
import { validateRequest, attendanceSchemas } from '../middleware/validation';
import { broadcastPresenceEvent } from '../config/socketio';
import { getMinIOClient } from '../config/minio';
import { createError } from '../middleware/errorHandler';
import { logger } from '../utils/logger';
import axios from 'axios';

const router = Router();

// Check-in via selfie/face recognition
router.post('/checkin', authenticateToken, validateRequest(attendanceSchemas.checkin), async (req: AuthRequest, res, next) => {
  try {
    const { session_id, image_data } = req.body;

    // Verify session exists and is active
    const session = await db('sessions')
      .where({ session_id, status: 'open' })
      .first();

    if (!session) {
      return res.status(400).json({ error: 'Session not found or not active' });
    }

    // Upload image to MinIO
    const imageBuffer = Buffer.from(image_data, 'base64');
    const imageKey = `checkins/${session_id}/${req.user!.id}_${Date.now()}.jpg`;
    
    const minioClient = getMinIOClient();
    await minioClient.putObject('labface', imageKey, imageBuffer, {
      'Content-Type': 'image/jpeg'
    });

    const imageUrl = `${process.env.MINIO_ENDPOINT}/labface/${imageKey}`;

    // Call ML service for face matching
    try {
      const mlResponse = await axios.post(`${process.env.ML_SERVICE_URL || 'http://ml-service:8000'}/match`, {
        image_url: imageUrl,
        session_id: session_id
      });

      if (mlResponse.data.matched && mlResponse.data.student_id === req.user!.id) {
        // Face match confirmed
        const isLate = isStudentLate(session.start_ts);
        const status = isLate ? 'late' : 'present';

        // Create or update attendance record
        await db('attendance')
          .insert({
            session_id,
            student_id: req.user!.id,
            status,
            checkin_ts: new Date(),
            selfie_url: imageUrl
          })
          .onConflict(['session_id', 'student_id'])
          .merge();

        // Create presence event
        await db('presence_events').insert({
          session_id,
          student_id: req.user!.id,
          event_type: 'in',
          source: 'face',
          details: JSON.stringify({
            image_url: imageUrl,
            score: mlResponse.data.score,
            confidence: mlResponse.data.confidence
          })
        });

        // Broadcast presence event
        broadcastPresenceEvent(req.app.get('io'), session_id.toString(), {
          student_id: req.user!.id,
          event_type: 'in',
          timestamp: new Date(),
          source: 'face',
          score: mlResponse.data.score,
          image_url: imageUrl
        });

        logger.info(`Student ${req.user!.id} checked in to session ${session_id} (${status})`);

        res.json({
          success: true,
          status,
          message: isLate ? 'Checked in late' : 'Checked in successfully'
        });
      } else {
        // Face match failed
        res.status(400).json({
          success: false,
          error: 'Face recognition failed. Please try again or contact support.'
        });
      }
    } catch (mlError) {
      logger.error('ML service error:', mlError);
      res.status(500).json({
        success: false,
        error: 'Face recognition service unavailable'
      });
    }
  } catch (error) {
    next(error);
  }
});

// Export attendance data
router.get('/export', authenticateToken, async (req: AuthRequest, res, next) => {
  try {
    const { session_id, format = 'csv' } = req.query;

    if (!session_id) {
      return res.status(400).json({ error: 'Session ID required' });
    }

    // Get session details
    const session = await db('sessions')
      .join('classes', 'sessions.class_id', 'classes.class_id')
      .where('sessions.session_id', session_id)
      .first();

    if (!session) {
      return res.status(404).json({ error: 'Session not found' });
    }

    // Get attendance data
    const attendance = await db('attendance')
      .join('students', 'attendance.student_id', 'students.student_id')
      .where('attendance.session_id', session_id)
      .select(
        'students.student_id',
        'students.first_name',
        'students.last_name',
        'students.email',
        'attendance.status',
        'attendance.checkin_ts',
        'attendance.checkout_ts',
        'attendance.presence_minutes'
      );

    if (format === 'csv') {
      // Generate CSV
      const csvHeader = 'Student ID,First Name,Last Name,Email,Status,Check-in Time,Check-out Time,Presence Minutes\n';
      const csvRows = attendance.map(record => 
        `${record.student_id},${record.first_name},${record.last_name},${record.email},${record.status},${record.checkin_ts || ''},${record.checkout_ts || ''},${record.presence_minutes || ''}`
      ).join('\n');

      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', `attachment; filename="attendance_${session_id}.csv"`);
      res.send(csvHeader + csvRows);
    } else {
      // Return JSON
      res.json({
        session: {
          session_id: session.session_id,
          subject: session.subject,
          section: session.section,
          session_date: session.session_date,
          start_ts: session.start_ts,
          end_ts: session.end_ts
        },
        attendance
      });
    }
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
