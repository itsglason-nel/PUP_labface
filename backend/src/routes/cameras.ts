import { Router } from 'express';
import { db } from '../config/database';
import { authenticateToken, requireProfessor, AuthRequest } from '../middleware/auth';
import { createError } from '../middleware/errorHandler';
import { logger } from '../utils/logger';

const router = Router();

// Get all cameras
router.get('/', authenticateToken, async (req: AuthRequest, res, next) => {
  try {
    const cameras = await db('cameras')
      .where('is_active', true)
      .orderBy('created_at', 'desc');

    res.json(cameras);
  } catch (error) {
    next(error);
  }
});

// Create camera
router.post('/', authenticateToken, requireProfessor, async (req: AuthRequest, res, next) => {
  try {
    const { camera_id, label, rtsp_url, channel, subtype, location } = req.body;

    if (!camera_id || !label || !rtsp_url) {
      return res.status(400).json({ error: 'Camera ID, label, and RTSP URL are required' });
    }

    // Check if camera already exists
    const existingCamera = await db('cameras').where({ camera_id }).first();
    if (existingCamera) {
      return res.status(400).json({ error: 'Camera with this ID already exists' });
    }

    const [cameraId] = await db('cameras').insert({
      camera_id,
      label,
      rtsp_url,
      channel: channel || 1,
      subtype: subtype || 1,
      location: location || '',
      is_active: true
    });

    logger.info(`Camera created: ${camera_id} - ${label}`);

    res.status(201).json({
      message: 'Camera created successfully',
      camera_id: cameraId
    });
  } catch (error) {
    next(error);
  }
});

// Update camera
router.put('/:id', authenticateToken, requireProfessor, async (req: AuthRequest, res, next) => {
  try {
    const cameraId = req.params.id;
    const updates = req.body;

    // Check if camera exists
    const existingCamera = await db('cameras').where({ camera_id: cameraId }).first();
    if (!existingCamera) {
      return res.status(404).json({ error: 'Camera not found' });
    }

    await db('cameras')
      .where({ camera_id: cameraId })
      .update(updates);

    logger.info(`Camera updated: ${cameraId}`);

    res.json({ message: 'Camera updated successfully' });
  } catch (error) {
    next(error);
  }
});

// Delete camera
router.delete('/:id', authenticateToken, requireProfessor, async (req: AuthRequest, res, next) => {
  try {
    const cameraId = req.params.id;

    // Check if camera exists
    const existingCamera = await db('cameras').where({ camera_id: cameraId }).first();
    if (!existingCamera) {
      return res.status(404).json({ error: 'Camera not found' });
    }

    await db('cameras')
      .where({ camera_id: cameraId })
      .update({ is_active: false });

    logger.info(`Camera deactivated: ${cameraId}`);

    res.json({ message: 'Camera deactivated successfully' });
  } catch (error) {
    next(error);
  }
});

// Test camera connection
router.post('/:id/test', authenticateToken, requireProfessor, async (req: AuthRequest, res, next) => {
  try {
    const cameraId = req.params.id;

    const camera = await db('cameras').where({ camera_id: cameraId }).first();
    if (!camera) {
      return res.status(404).json({ error: 'Camera not found' });
    }

    // Here you would implement actual RTSP connection testing
    // For now, we'll just return a success response
    logger.info(`Camera connection test requested for: ${cameraId}`);

    res.json({
      success: true,
      message: 'Camera connection test initiated',
      camera_id: cameraId,
      rtsp_url: camera.rtsp_url
    });
  } catch (error) {
    next(error);
  }
});

export default router;
