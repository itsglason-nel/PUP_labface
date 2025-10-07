import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { createError } from './errorHandler';

export interface AuthRequest extends Request {
  user?: {
    id: string;
    type: 'student' | 'professor';
    email: string;
  };
}

export function authenticateToken(req: AuthRequest, res: Response, next: NextFunction): void {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    res.status(401).json({ error: 'Access token required' });
    return;
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'change_me') as any;
    req.user = {
      id: decoded.id,
      type: decoded.type,
      email: decoded.email
    };
    next();
  } catch (error) {
    res.status(403).json({ error: 'Invalid or expired token' });
    return;
  }
}

export function requireProfessor(req: AuthRequest, res: Response, next: NextFunction): void {
  if (req.user?.type !== 'professor') {
    res.status(403).json({ error: 'Professor access required' });
    return;
  }
  next();
}

export function requireStudent(req: AuthRequest, res: Response, next: NextFunction): void {
  if (req.user?.type !== 'student') {
    res.status(403).json({ error: 'Student access required' });
    return;
  }
  next();
}
