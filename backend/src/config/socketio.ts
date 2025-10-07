import { Server } from 'socket.io';
import { logger } from '../utils/logger';

export function initializeSocketIO(io: Server) {
  io.on('connection', (socket) => {
    logger.info(`Client connected: ${socket.id}`);

    // Join attendance room for a specific session
    socket.on('join-attendance', (sessionId: string) => {
      socket.join(`attendance:${sessionId}`);
      logger.info(`Client ${socket.id} joined attendance room for session ${sessionId}`);
    });

    // Leave attendance room
    socket.on('leave-attendance', (sessionId: string) => {
      socket.leave(`attendance:${sessionId}`);
      logger.info(`Client ${socket.id} left attendance room for session ${sessionId}`);
    });

    // Handle disconnection
    socket.on('disconnect', () => {
      logger.info(`Client disconnected: ${socket.id}`);
    });
  });

  return io;
}

// Helper function to broadcast presence events
export function broadcastPresenceEvent(io: Server, sessionId: string, event: any) {
  io.to(`attendance:${sessionId}`).emit('presence-event', event);
  logger.info(`Broadcasted presence event to session ${sessionId}:`, event);
}

// Helper function to broadcast session status changes
export function broadcastSessionStatus(io: Server, sessionId: string, status: string) {
  io.to(`attendance:${sessionId}`).emit('session-status', { sessionId, status });
  logger.info(`Broadcasted session status to session ${sessionId}: ${status}`);
}
