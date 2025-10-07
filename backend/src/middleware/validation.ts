import { Request, Response, NextFunction } from 'express';
import Joi from 'joi';
import { createError } from './errorHandler';

export function validateRequest(schema: Joi.ObjectSchema) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const { error } = schema.validate(req.body);
    if (error) {
      res.status(400).json({ 
        error: 'Validation error', 
        details: error.details.map(d => d.message) 
      });
      return;
    }
    next();
  };
}

// Common validation schemas
export const authSchemas = {
  professorRegister: Joi.object({
    professor_id: Joi.string().required(),
    first_name: Joi.string().required(),
    last_name: Joi.string().required(),
    email: Joi.string().email().required(),
    password: Joi.string().min(6).required()
  }),
  
  professorLogin: Joi.object({
    email: Joi.string().email().required(),
    password: Joi.string().required()
  }),
  
  studentRegister: Joi.object({
    student_id: Joi.string().required(),
    first_name: Joi.string().required(),
    middle_name: Joi.string().allow(''),
    last_name: Joi.string().required(),
    course: Joi.string().allow(''),
    year_level: Joi.number().integer().min(1).max(10).allow(null),
    email: Joi.string().email().required(),
    mobile: Joi.string().allow(''),
    password: Joi.string().min(6).required()
  }),
  
  studentLogin: Joi.object({
    email: Joi.string().email().required(),
    password: Joi.string().required()
  })
};

export const classSchemas = {
  createClass: Joi.object({
    semester: Joi.string().required(),
    school_year: Joi.string().required(),
    subject: Joi.string().required(),
    section: Joi.string().allow('')
  }),
  
  updateClass: Joi.object({
    semester: Joi.string(),
    school_year: Joi.string(),
    subject: Joi.string(),
    section: Joi.string().allow('')
  })
};

export const attendanceSchemas = {
  checkin: Joi.object({
    session_id: Joi.number().integer().required(),
    image_data: Joi.string().base64().required()
  }),
  
  export: Joi.object({
    session_id: Joi.number().integer().required(),
    format: Joi.string().valid('csv', 'json').default('csv')
  })
};
