/**
 * Notification Routes
 * Routes for managing user notifications
 */

const express = require('express');
const { param } = require('express-validator');
const { authenticateToken } = require('../middlewares/auth.middleware');
const { handleValidationErrors, commonValidation } = require('../utils/validators');
const { asyncHandler } = require('../middlewares/error.middleware');

const router = express.Router();

// Import services
const notificationService = require('../services/notification.service');
const pushNotificationService = require('../services/push-notification.service');

const notificationController = {
  // Register device for push notifications
  registerDevice: asyncHandler(async (req, res) => {
    const { token, platform } = req.body;
    if (!token) {
      return res.status(400).json({ success: false, message: 'Device token is required' });
    }
    
    await pushNotificationService.registerDeviceToken(
      req.userId,
      token,
      platform || 'web'
    );
    
    res.json({
      success: true,
      message: 'Device registered for push notifications'
    });
  }),

  getUserNotifications: asyncHandler(async (req, res) => {
    const { page = 1, limit = 20 } = req.query;
    const result = await notificationService.getUserNotifications(req.userId, {
      page: parseInt(page),
      limit: parseInt(limit),
    });
    res.json({
      success: true,
      message: 'Notifications retrieved successfully',
      data: result.notifications,
      pagination: result.pagination,
    });
  }),

  markAsRead: asyncHandler(async (req, res) => {
    await notificationService.markAsRead(parseInt(req.params.id), req.userId);
    res.json({
      success: true,
      message: 'Notification marked as read',
    });
  }),

  markAllAsRead: asyncHandler(async (req, res) => {
    const count = await notificationService.markAllAsRead(req.userId);
    res.json({
      success: true,
      message: 'All notifications marked as read',
      data: { count },
    });
  }),

  deleteNotification: asyncHandler(async (req, res) => {
    await notificationService.deleteNotification(parseInt(req.params.id), req.userId);
    res.json({
      success: true,
      message: 'Notification deleted successfully',
    });
  }),
};

// GET /api/notifications - Get user's notifications
router.get(
  '/',
  authenticateToken,
  commonValidation.pagination,
  handleValidationErrors,
  notificationController.getUserNotifications
);

// PUT /api/notifications/read-all - Mark all as read
router.put(
  '/read-all',
  authenticateToken,
  notificationController.markAllAsRead
);

// PUT /api/notifications/:id/read - Mark notification as read
router.put(
  '/:id/read',
  authenticateToken,
  [
    param('id')
      .isInt({ min: 1 })
      .withMessage('Valid notification ID is required'),
  ],
  handleValidationErrors,
  notificationController.markAsRead
);

// DELETE /api/notifications/:id - Delete notification
router.delete(
  '/:id',
  authenticateToken,
  [
    param('id')
      .isInt({ min: 1 })
      .withMessage('Valid notification ID is required'),
  ],
  handleValidationErrors,
  notificationController.deleteNotification
);

// POST /api/notifications/register-device - Register device token
router.post(
  '/register-device',
  authenticateToken,
  notificationController.registerDevice
);

module.exports = router;
