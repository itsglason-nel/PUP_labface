import { Client } from 'minio';
import { logger } from '../utils/logger';

let minioClient: Client;

export async function initializeMinIO() {
  try {
    minioClient = new Client({
      endPoint: process.env.MINIO_ENDPOINT?.split(':')[0] || 'localhost',
      port: parseInt(process.env.MINIO_ENDPOINT?.split(':')[1] || '9000'),
      useSSL: false,
      accessKey: process.env.MINIO_ACCESS_KEY || 'minioadmin',
      secretKey: process.env.MINIO_SECRET_KEY || 'minioadmin'
    });

    // Test connection
    await minioClient.bucketExists('labface');
    
    // Create bucket if it doesn't exist
    const bucketExists = await minioClient.bucketExists('labface');
    if (!bucketExists) {
      await minioClient.makeBucket('labface', 'us-east-1');
      logger.info('Created MinIO bucket: labface');
    }

    logger.info('MinIO connection established');
    return minioClient;
  } catch (error) {
    logger.error('MinIO connection failed:', error);
    throw error;
  }
}

export function getMinIOClient(): Client {
  if (!minioClient) {
    throw new Error('MinIO client not initialized');
  }
  return minioClient;
}
