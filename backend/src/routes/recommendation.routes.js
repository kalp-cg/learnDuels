const express = require('express');
const router = express.Router();
const recommendationService = require('../services/recommendation.service');
const { authenticateToken } = require('../middlewares/auth.middleware');
const { successResponse, errorResponse } = require('../utils/response');

/**
 * @route   GET /api/recommendations/users
 * @desc    Get personalized user recommendations
 * @access  Private
 */
router.get('/users', authenticateToken, async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 10;
    const recommendations = await recommendationService.getUserRecommendations(
      req.user.id,
      limit
    );

    res.json(successResponse(recommendations, 'Recommendations retrieved successfully'));
  } catch (error) {
    console.error('Get recommendations error:', error);
    res.status(500).json(errorResponse(error.message));
  }
});

/**
 * @route   GET /api/recommendations/topics
 * @desc    Get topic recommendations
 * @access  Private
 */
router.get('/topics', authenticateToken, async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 5;
    const recommendations = await recommendationService.getTopicRecommendations(
      req.user.id,
      limit
    );

    res.json(successResponse(recommendations, 'Topic recommendations retrieved'));
  } catch (error) {
    console.error('Get topic recommendations error:', error);
    res.status(500).json(errorResponse(error.message));
  }
});

/**
 * @route   GET /api/recommendations/question-sets
 * @desc    Get question set recommendations
 * @access  Private
 */
router.get('/question-sets', authenticateToken, async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 10;
    const recommendations = await recommendationService.getQuestionSetRecommendations(
      req.user.id,
      limit
    );

    res.json(successResponse(recommendations, 'Question set recommendations retrieved'));
  } catch (error) {
    console.error('Get question set recommendations error:', error);
    res.status(500).json(errorResponse(error.message));
  }
});

module.exports = router;
