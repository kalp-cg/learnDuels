/**
 * User Routes
 * Routes for user profile management and social features
 */

const express = require('express');
const { param, query } = require('express-validator');
const { authenticateToken, optionalAuth } = require('../middlewares/auth.middleware');
const { handleValidationErrors, userValidation, commonValidation } = require('../utils/validators');
const { uploadSingle, handleUploadError } = require('../middlewares/upload.middleware');
const userController = require('../controllers/user.controller');

const router = express.Router();

// GET /api/users - Get all users (for finding friends)
router.get(
  '/',
  authenticateToken,
  [
    query('search').optional().isString(),
    query('sortBy').optional().isIn(['newest', 'rating', 'xp']),
    ...commonValidation.pagination,
  ],
  handleValidationErrors,
  userController.getAllUsers
);
// GET /api/users/me - Get current user profile
router.get('/me', authenticateToken, userController.getProfile);

// PUT /api/users/update - Update current user profile
router.put(
  '/update',
  authenticateToken,
  userValidation.updateProfile,
  handleValidationErrors,
  userController.updateProfile
);

// GET /api/users/me/followers - Get current user's followers
router.get(
  '/me/followers',
  authenticateToken,
  [...commonValidation.pagination],
  handleValidationErrors,
  userController.getFollowers
);

// GET /api/users/me/following - Get users current user is following
router.get(
  '/me/following',
  authenticateToken,
  [...commonValidation.pagination],
  handleValidationErrors,
  userController.getFollowing
);

// GET /api/users/search - Search users
router.get(
  '/search',
  optionalAuth,
  [
    query('q')
      .notEmpty()
      .withMessage('Search query is required')
      .isLength({ min: 2 })
      .withMessage('Search query must be at least 2 characters'),
    ...commonValidation.pagination,
  ],
  handleValidationErrors,
  userController.searchUsers
);

// GET /api/users/follow-requests - Get pending follow requests (MUST be before /:id routes)
router.get(
  '/follow-requests',
  authenticateToken,
  [...commonValidation.pagination],
  handleValidationErrors,
  userController.getPendingFollowRequests
);

// GET /api/users/:id - Get user profile by ID
router.get(
  '/:id',
  optionalAuth,
  [
    param('id')
      .isInt({ min: 1 })
      .withMessage('Valid user ID is required'),
  ],
  handleValidationErrors,
  userController.getUserById
);

// PUT /api/users/profile - Update current user's profile (with optional image)
router.put(
  '/profile',
  authenticateToken,
  uploadSingle,
  handleUploadError,
  userController.updateProfile
);

// POST /api/users/avatar - Upload/update avatar
router.post(
  '/avatar',
  authenticateToken,
  uploadSingle,
  handleUploadError,
  userController.uploadAvatar
);

// DELETE /api/users/avatar - Delete avatar
router.delete(
  '/avatar',
  authenticateToken,
  userController.deleteAvatar
);

// POST /api/users/:id/follow - Follow a user
router.post(
  '/:id/follow',
  authenticateToken,
  [
    param('id')
      .isInt({ min: 1 })
      .withMessage('Valid user ID is required'),
  ],
  handleValidationErrors,
  userController.followUser
);

// DELETE /api/users/:id/follow - Unfollow a user
router.delete(
  '/:id/follow',
  authenticateToken,
  [
    param('id')
      .isInt({ min: 1 })
      .withMessage('Valid user ID is required'),
  ],
  handleValidationErrors,
  userController.unfollowUser
);

// POST /api/users/:id/follow/accept - Accept follow request
router.post(
  '/:id/follow/accept',
  authenticateToken,
  [
    param('id')
      .isInt({ min: 1 })
      .withMessage('Valid user ID is required'),
  ],
  handleValidationErrors,
  userController.acceptFollowRequest
);

// POST /api/users/:id/follow/decline - Decline follow request
router.post(
  '/:id/follow/decline',
  authenticateToken,
  [
    param('id')
      .isInt({ min: 1 })
      .withMessage('Valid user ID is required'),
  ],
  handleValidationErrors,
  userController.declineFollowRequest
);

// GET /api/users/:id/followers - Get user's followers
router.get(
  '/:id/followers',
  optionalAuth,
  [
    param('id')
      .isInt({ min: 1 })
      .withMessage('Valid user ID is required'),
    ...commonValidation.pagination
  ],
  handleValidationErrors,
  userController.getFollowers
);

// GET /api/users/:id/following - Get users that user is following
router.get(
  '/:id/following',
  optionalAuth,
  [
    param('id')
      .isInt({ min: 1 })
      .withMessage('Valid user ID is required'),
    ...commonValidation.pagination
  ],
  handleValidationErrors,
  userController.getFollowing
);

module.exports = router;