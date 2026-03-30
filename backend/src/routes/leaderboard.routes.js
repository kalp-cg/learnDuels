/**
 * Leaderboard Routes
 * Routes for leaderboards, rankings, and user statistics
 */

const express = require('express');
const { query } = require('express-validator');
const { authenticateToken, optionalAuth } = require('../middlewares/auth.middleware');
const { handleValidationErrors, commonValidation } = require('../utils/validators');
const { asyncHandler } = require('../middlewares/error.middleware');

const router = express.Router();

// Import leaderboard service
const leaderboardService = require('../services/leaderboard.service');

// Placeholder controllers
const leaderboardController = {
  getGlobalLeaderboard: asyncHandler(async (req, res) => {
    const { period, topicId, page, limit } = req.query;
    
    const filters = { period, topicId };
    const options = { 
      page: parseInt(page) || 1, 
      limit: parseInt(limit) || 20 
    };

    const result = await leaderboardService.getGlobalLeaderboard(filters, options);
    res.json({
      success: true,
      message: 'Global leaderboard retrieved successfully',
      data: result.leaderboard,
      pagination: result.pagination,
      metadata: {
        period: result.period,
        topicId: result.topicId,
      },
    });
  }),

  getTopicLeaderboard: asyncHandler(async (req, res) => {
    const { period, page, limit } = req.query;
    
    const filters = { period };
    const options = { 
      page: parseInt(page) || 1, 
      limit: parseInt(limit) || 20 
    };

    const result = await leaderboardService.getTopicLeaderboard(req.params.topicId, filters, options);
    res.json({
      success: true,
      message: 'Topic leaderboard retrieved successfully',
      data: result.leaderboard,
      pagination: result.pagination,
      metadata: {
        topic: result.topic,
        period: result.period,
      },
    });
  }),

  getUserRanking: asyncHandler(async (req, res) => {
    const { topicId } = req.query;
    const ranking = await leaderboardService.getUserRanking(req.userId, topicId);
    res.json({
      success: true,
      message: 'User ranking retrieved successfully',
      data: ranking,
    });
  }),

  getUserStats: asyncHandler(async (req, res) => {
    const { topicId } = req.query;
    const stats = await leaderboardService.getUserStats(req.userId, topicId);
    res.json({
      success: true,
      message: 'User statistics retrieved successfully',
      data: stats,
    });
  }),

  getLeaderboardAroundUser: asyncHandler(async (req, res) => {
    const { range, topicId } = req.query;
    const options = { 
      range: parseInt(range) || 5, 
      topicId 
    };

    const result = await leaderboardService.getLeaderboardAroundUser(req.userId, options);
    res.json({
      success: true,
      message: 'Leaderboard around user retrieved successfully',
      data: result.leaderboard,
      pagination: result.pagination,
      metadata: {
        userRank: result.userRank,
        range: result.range,
        topicId,
      },
    });
  }),
};

// GET /api/leaderboard/global - Get global leaderboard
router.get(
  '/global',
  optionalAuth,
  [
    query('period')
      .optional()
      .toUpperCase()
      .isIn(['DAILY', 'WEEKLY', 'MONTHLY', 'ALL_TIME'])
      .withMessage('Period must be DAILY, WEEKLY, MONTHLY, or ALL_TIME'),
    query('topicId')
      .optional()
      .isInt()
      .withMessage('Topic ID must be a valid integer'),
    ...commonValidation.pagination,
  ],
  handleValidationErrors,
  leaderboardController.getGlobalLeaderboard
);

// GET /api/leaderboards/topics/:topicId - Get topic-specific leaderboard
router.get(
  '/topics/:topicId',
  optionalAuth,
  [
    query('period')
      .optional()
      .toUpperCase()
      .isIn(['DAILY', 'WEEKLY', 'MONTHLY', 'ALL_TIME'])
      .withMessage('Period must be DAILY, WEEKLY, MONTHLY, or ALL_TIME'),
    ...commonValidation.pagination,
  ],
  handleValidationErrors,
  leaderboardController.getTopicLeaderboard
);

// GET /api/leaderboards/top - Get top performers
router.get(
  '/top',
  optionalAuth,
  [
    query('limit')
      .optional()
      .isInt({ min: 1, max: 100 })
      .withMessage('Limit must be between 1 and 100'),
  ],
  handleValidationErrors,
  asyncHandler(async (req, res) => {
    const leaderboardService = require('../services/leaderboard.service');
    const { limit } = req.query;
    const result = await leaderboardService.getTopPerformers(parseInt(limit) || 10);
    res.json({
      success: true,
      message: 'Top performers retrieved successfully',
      data: result,
    });
  })
);

// GET /api/leaderboards/my/rank - Get current user's ranking
router.get(
  '/my/rank',
  authenticateToken,
  [
    query('topicId')
      .optional()
      .isInt({ min: 1 })
      .withMessage('Topic ID must be a valid integer'),
  ],
  handleValidationErrors,
  leaderboardController.getUserRanking
);

// GET /api/leaderboards/my/stats - Get current user's statistics
router.get(
  '/my/stats',
  authenticateToken,
  [
    query('topicId')
      .optional()
      .isInt({ min: 1 })
      .withMessage('Topic ID must be a valid integer'),
  ],
  handleValidationErrors,
  leaderboardController.getUserStats
);

// GET /api/leaderboards/around-me - Get leaderboard around current user
router.get(
  '/around-me',
  authenticateToken,
  [
    query('range')
      .optional()
      .isInt({ min: 1, max: 20 })
      .withMessage('Range must be between 1 and 20'),
    query('topicId')
      .optional()
      .isInt({ min: 1 })
      .withMessage('Topic ID must be a valid integer'),
  ],
  handleValidationErrors,
  leaderboardController.getLeaderboardAroundUser
);

module.exports = router;