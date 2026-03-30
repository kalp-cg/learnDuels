/**
 * Error Handling Middleware
 * Centralized error handling for the application
 */

const config = require('../config/env');
const { errorResponse } = require('../utils/response');

/**
 * Global error handler middleware
 * @param {Error} err - Error object
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next function
 */
function errorHandler(err, req, res, next) {
  console.error('Error occurred:', {
    message: err.message,
    stack: err.stack,
    url: req.url,
    method: req.method,
    ip: req.ip,
    userAgent: req.get('User-Agent'),
    timestamp: new Date().toISOString(),
  });

  // Prisma errors
  if (err.code && err.code.startsWith('P')) {
    return handlePrismaError(err, res);
  }

  // JWT errors
  if (err.name === 'JsonWebTokenError') {
    return errorResponse(res, 'Invalid token', 401);
  }

  if (err.name === 'TokenExpiredError') {
    return errorResponse(res, 'Token has expired', 401);
  }

  // Validation errors
  if (err.name === 'ValidationError') {
    return errorResponse(res, 'Validation failed', 400, err.details);
  }

  // Cast errors (invalid ObjectId, UUID, etc.)
  if (err.name === 'CastError') {
    return errorResponse(res, 'Invalid ID format', 400);
  }

  // Duplicate key errors
  if (err.code === 11000 || err.code === 'ER_DUP_ENTRY') {
    return handleDuplicateKeyError(err, res);
  }

  // Rate limit errors
  if (err.status === 429) {
    return errorResponse(res, 'Too many requests', 429);
  }

  // Default to 500 server error
  const statusCode = err.statusCode || err.status || 500;
  const message = err.isOperational ? err.message : 'Internal server error';
  
  // In production, don't leak error details
  const details = config.NODE_ENV === 'development' ? {
    stack: err.stack,
    ...err.details,
  } : undefined;

  return errorResponse(res, message, statusCode, details);
}

/**
 * Handle Prisma database errors
 * @param {Error} err - Prisma error
 * @param {Object} res - Express response object
 */
function handlePrismaError(err, res) {
  const { code, message } = err;

  switch (code) {
    case 'P2002': // Unique constraint violation
      const target = err.meta?.target || 'field';
      return errorResponse(res, `${target} already exists`, 409);
      
    case 'P2025': // Record not found
      return errorResponse(res, 'Record not found', 404);
      
    case 'P2003': // Foreign key constraint violation
      return errorResponse(res, 'Related record not found', 400);
      
    case 'P2004': // Constraint violation
      return errorResponse(res, 'Database constraint violation', 400);
      
    case 'P1001': // Cannot reach database
      console.error('Database connection error:', message);
      return errorResponse(res, 'Database connection failed', 503);
      
    case 'P1008': // Operations timed out
      return errorResponse(res, 'Database operation timed out', 408);
      
    default:
      console.error('Unhandled Prisma error:', { code, message });
      return errorResponse(res, 'Database error occurred', 500);
  }
}

/**
 * Handle duplicate key errors
 * @param {Error} err - Error object
 * @param {Object} res - Express response object
 */
function handleDuplicateKeyError(err, res) {
  // Extract field name from error message if possible
  let field = 'field';
  
  if (err.keyValue) {
    field = Object.keys(err.keyValue)[0];
  } else if (err.message.includes('email')) {
    field = 'email';
  } else if (err.message.includes('username')) {
    field = 'username';
  }

  return errorResponse(res, `${field} already exists`, 409);
}

/**
 * Handle 404 errors for undefined routes
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next function
 */
function notFoundHandler(req, res, next) {
  const message = `Route ${req.method} ${req.originalUrl} not found`;
  return errorResponse(res, message, 404);
}

/**
 * Async error wrapper
 * Wraps async route handlers to catch and pass errors to error handler
 * @param {Function} fn - Async function to wrap
 * @returns {Function} Wrapped function
 */
function asyncHandler(fn) {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

/**
 * Custom application error class
 */
class AppError extends Error {
  constructor(message, statusCode, isOperational = true) {
    super(message);
    
    this.statusCode = statusCode;
    this.status = statusCode >= 400 && statusCode < 500 ? 'fail' : 'error';
    this.isOperational = isOperational;
    
    Error.captureStackTrace(this, this.constructor);
  }
}

/**
 * Create operational errors
 */
const createError = {
  badRequest: (message = 'Bad request') => new AppError(message, 400),
  unauthorized: (message = 'Unauthorized') => new AppError(message, 401),
  forbidden: (message = 'Forbidden') => new AppError(message, 403),
  notFound: (message = 'Not found') => new AppError(message, 404),
  conflict: (message = 'Conflict') => new AppError(message, 409),
  tooManyRequests: (message = 'Too many requests') => new AppError(message, 429),
  internal: (message = 'Internal server error') => new AppError(message, 500),
};

module.exports = {
  errorHandler,
  notFoundHandler,
  asyncHandler,
  AppError,
  createError,
};