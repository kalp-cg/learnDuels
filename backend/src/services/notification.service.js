/**
 * Notification Service
 * Handles user notifications
 */

const { prisma } = require('../config/db');
const { createError } = require('../middlewares/error.middleware');
const pushNotificationService = require('./push-notification.service');

/**
 * Create notification
 */
async function createNotification(userId, message, type = 'general', data = null) {
  try {
    const notification = await prisma.notification.create({
      data: {
        userId: parseInt(userId),
        message,
        type,
        data: data || {},
      },
    });

    // Send Push Notification
    try {
      await pushNotificationService.sendToUser(parseInt(userId), {
        title: 'LearnDuels',
        body: message,
        data: {
          type,
          notificationId: String(notification.id),
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          ...(data ? Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])) : {})
        }
      });
    } catch (pushError) {
      console.error('Failed to send push notification:', pushError.message);
      // Don't fail the main operation
    }

    return notification;
  } catch (error) {
    console.error('Create notification error:', error);
    throw createError.internal('Failed to create notification');
  }
}

/**
 * Get user notifications
 */
async function getUserNotifications(userId, options = {}) {
  const { page = 1, limit = 20, unreadOnly = false } = options;
  const skip = (page - 1) * limit;

  try {
    const where = {
      userId: parseInt(userId),
    };

    if (unreadOnly) {
      where.isRead = false;
    }

    const [notifications, totalCount] = await Promise.all([
      prisma.notification.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      prisma.notification.count({ where }),
    ]);

    return {
      notifications,
      pagination: {
        total: totalCount,
        page,
        limit,
        totalPages: Math.ceil(totalCount / limit),
      },
    };
  } catch (error) {
    throw createError.internal('Failed to fetch notifications');
  }
}

/**
 * Mark notification as read
 */
async function markAsRead(notificationId, userId) {
  try {
    const notification = await prisma.notification.findFirst({
      where: {
        id: parseInt(notificationId),
        userId: parseInt(userId),
      },
    });

    if (!notification) {
      throw createError.notFound('Notification not found');
    }

    await prisma.notification.update({
      where: { id: parseInt(notificationId) },
      data: { isRead: true },
    });

    return { success: true };
  } catch (error) {
    if (error.isOperational) throw error;
    throw createError.internal('Failed to mark notification as read');
  }
}

/**
 * Mark all notifications as read
 */
async function markAllAsRead(userId) {
  try {
    await prisma.notification.updateMany({
      where: {
        userId: parseInt(userId),
        isRead: false,
      },
      data: { isRead: true },
    });

    return { success: true };
  } catch (error) {
    throw createError.internal('Failed to mark all notifications as read');
  }
}

/**
 * Delete notification
 */
async function deleteNotification(notificationId, userId) {
  try {
    const notification = await prisma.notification.findFirst({
      where: {
        id: parseInt(notificationId),
        userId: parseInt(userId),
      },
    });

    if (!notification) {
      throw createError.notFound('Notification not found');
    }

    await prisma.notification.delete({
      where: { id: parseInt(notificationId) },
    });

    return { success: true };
  } catch (error) {
    if (error.isOperational) throw error;
    throw createError.internal('Failed to delete notification');
  }
}

module.exports = {
  createNotification,
  getUserNotifications,
  markAsRead,
  markAllAsRead,
  deleteNotification,
};
