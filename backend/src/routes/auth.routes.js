/**
 * Authentication Routes
 * Routes for user authentication and authorization
 */

const express = require('express');
const { body } = require('express-validator');
const { authenticateToken, authRateLimit } = require('../middlewares/auth.middleware');
const { handleValidationErrors, userValidation } = require('../utils/validators');
const authController = require('../controllers/auth.controller');

const router = express.Router();

// POST /api/auth/signup
router.post(
  '/signup',
  authRateLimit(5, 15 * 60 * 1000), // 5 attempts per 15 minutes
  userValidation.signup,
  handleValidationErrors,
  authController.signup
);

// POST /api/auth/register (alias for signup)
router.post(
  '/register',
  authRateLimit(5, 15 * 60 * 1000), // 5 attempts per 15 minutes
  userValidation.signup,
  handleValidationErrors,
  authController.signup
);

// POST /api/auth/login
router.post(
  '/login',
  authRateLimit(5, 15 * 60 * 1000), // 5 attempts per 15 minutes
  userValidation.login,
  handleValidationErrors,
  authController.login
);

// POST /api/auth/google
router.post(
  '/google',
  authRateLimit(5, 15 * 60 * 1000), // 5 attempts per 15 minutes
  authController.googleLogin
);

// POST /api/auth/logout
router.post('/logout', authenticateToken, authController.logout);

// POST /api/auth/refresh-token
router.post(
  '/refresh-token',
  [
    body('refreshToken')
      .notEmpty()
      .withMessage('Refresh token is required'),
  ],
  handleValidationErrors,
  authController.refreshToken
);

// POST /api/auth/refresh (alias)
router.post(
  '/refresh',
  [
    body('refreshToken')
      .notEmpty()
      .withMessage('Refresh token is required'),
  ],
  handleValidationErrors,
  authController.refreshToken
);

// POST /api/auth/change-password
router.post(
  '/change-password',
  authenticateToken,
  [
    body('currentPassword')
      .optional()
      .notEmpty()
      .withMessage('Current password is required'),
    body('oldPassword')
      .optional()
      .notEmpty()
      .withMessage('Old password is required'),
    body('newPassword')
      .isLength({ min: 8 })
      .withMessage('New password must be at least 8 characters long')
      .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
      .withMessage('New password must contain at least one lowercase letter, one uppercase letter, and one number'),
  ],
  handleValidationErrors,
  authController.changePassword
);

// POST /api/auth/forgot-password
router.post(
  '/forgot-password',
  authRateLimit,
  [
    body('email').isEmail().withMessage('Valid email is required'),
  ],
  handleValidationErrors,
  authController.forgotPassword
);

// POST /api/auth/reset-password
router.post(
  '/reset-password',
  authRateLimit,
  [
    body('token').notEmpty().withMessage('Token is required'),
    body('newPassword')
      .isLength({ min: 8 })
      .withMessage('Password must be at least 8 characters long')
      .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
      .withMessage('Password must contain at least one lowercase letter, one uppercase letter, and one number'),
  ],
  handleValidationErrors,
  authController.resetPassword
);

// GET /api/auth/me - Get current user
router.get('/me', authenticateToken, authController.getMe);

// Google OAuth Routes
const googleAuthRoutes = require('./googleAuth.routes');
router.use('/google', googleAuthRoutes);

module.exports = router;
