import { Router } from 'express';
import { getMinIOClient } from '../config/minio';
import { authenticateToken, AuthRequest } from '../middleware/auth';
import { createError } from '../middleware/errorHandler';
import { logger } from '../utils/logger';

const router = Router();

// Get presigned URL for upload
router.get('/presign-upload', authenticateToken, async (req: AuthRequest, res, next) => {
  try {
    const { key, contentType = 'image/jpeg' } = req.query;

    if (!key) {
      return res.status(400).json({ error: 'Key parameter required' });
    }

    const minioClient = getMinIOClient();
    
    // Generate presigned URL for PUT operation (7 days expiry)
    const presignedUrl = await minioClient.presignedPutObject(
      'labface',
      key as string,
      7 * 24 * 60 * 60 // 7 days in seconds
    );

    logger.info(`Generated presigned URL for key: ${key}`);

    res.json({
      presigned_url: presignedUrl,
      key: key,
      content_type: contentType
    });
  } catch (error) {
    next(error);
  }
});

// Get presigned URL for download
router.get('/presign-download', authenticateToken, async (req: AuthRequest, res, next) => {
  try {
    const { key } = req.query;

    if (!key) {
      return res.status(400).json({ error: 'Key parameter required' });
    }

    const minioClient = getMinIOClient();
    
    // Generate presigned URL for GET operation (1 hour expiry)
    const presignedUrl = await minioClient.presignedGetObject(
      'labface',
      key as string,
      60 * 60 // 1 hour in seconds
    );

    res.json({
      presigned_url: presignedUrl,
      key: key
    });
  } catch (error) {
    next(error);
  }
});

// Upload file directly (alternative to presigned URLs)
router.post('/upload', authenticateToken, async (req: AuthRequest, res, next) => {
  try {
    const { key, data, contentType = 'image/jpeg' } = req.body;

    if (!key || !data) {
      return res.status(400).json({ error: 'Key and data required' });
    }

    const minioClient = getMinIOClient();
    const buffer = Buffer.from(data, 'base64');
    
    await minioClient.putObject('labface', key, buffer, {
      'Content-Type': contentType
    });

    const objectUrl = `${process.env.MINIO_ENDPOINT}/labface/${key}`;

    logger.info(`File uploaded: ${key}`);

    res.json({
      success: true,
      url: objectUrl,
      key: key
    });
  } catch (error) {
    next(error);
  }
});

// Delete file
router.delete('/delete', authenticateToken, async (req: AuthRequest, res, next) => {
  try {
    const { key } = req.body;

    if (!key) {
      return res.status(400).json({ error: 'Key parameter required' });
    }

    const minioClient = getMinIOClient();
    await minioClient.removeObject('labface', key);

    logger.info(`File deleted: ${key}`);

    res.json({
      success: true,
      message: 'File deleted successfully'
    });
  } catch (error) {
    next(error);
  }
});

export default router;
