/**
 * Feed Routes
 * Routes for activity feed
 */

const express = require('express');
const { authenticateToken } = require('../middlewares/auth.middleware');
const { asyncHandler } = require('../middlewares/error.middleware');
const feedService = require('../services/feed.service');

const router = express.Router();

// GET /api/feed - Get user's activity feed
router.get('/', authenticateToken, asyncHandler(async (req, res) => {
  const { page = 1, limit = 20 } = req.query;
  const result = await feedService.getFeed(req.userId, {
    page: parseInt(page),
    limit: parseInt(limit),
  });
  
  res.json({
    success: true,
    message: 'Feed retrieved successfully',
    data: result.activities,
    pagination: result.pagination,
  });
}));

module.exports = router;
