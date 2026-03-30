const express = require('express');
const router = express.Router();
const attemptService = require('../services/attempt.service');
const { authenticate } = require('../middlewares/auth.middleware');

/**
 * Attempt Routes - Quiz/QuestionSet attempts
 */

// Get user's attempts
router.get('/', authenticate, async (req, res, next) => {
  try {
    const { questionSetId, status, page, limit } = req.query;
    const result = await attemptService.getUserAttempts(req.user.id, {
      questionSetId: questionSetId ? parseInt(questionSetId) : undefined,
      status,
      page: page ? parseInt(page) : undefined,
      limit: limit ? parseInt(limit) : undefined,
    });
    res.json({ success: true, ...result });
  } catch (error) {
    next(error);
  }
});

// Get user's attempt statistics
router.get('/stats', authenticate, async (req, res, next) => {
  try {
    const stats = await attemptService.getUserAttemptStats(req.user.id);
    res.json({ success: true, data: stats });
  } catch (error) {
    next(error);
  }
});

// Get attempt by ID
router.get('/:id', authenticate, async (req, res, next) => {
  try {
    const attempt = await attemptService.getAttemptById(req.params.id, req.user.id);
    res.json({ success: true, data: attempt });
  } catch (error) {
    next(error);
  }
});

// Start a new attempt
router.post('/', authenticate, async (req, res, next) => {
  try {
    const { questionSetId } = req.body;
    if (!questionSetId) {
      return res.status(400).json({ success: false, message: 'questionSetId is required' });
    }
    const attempt = await attemptService.startAttempt(req.user.id, questionSetId);
    res.status(201).json({ success: true, data: attempt });
  } catch (error) {
    next(error);
  }
});

// Start a practice attempt
router.post('/practice', authenticate, async (req, res, next) => {
  try {
    const { topicId, difficulty, limit } = req.body;
    if (!topicId) {
      return res.status(400).json({ success: false, message: 'topicId is required' });
    }
    const result = await attemptService.startPracticeAttempt(
      req.user.id, 
      topicId, 
      difficulty || 'MEDIUM',
      limit ? parseInt(limit) : 10
    );
    res.status(201).json({ success: true, data: result });
  } catch (error) {
    next(error);
  }
});

// Submit an answer
router.post('/:id/answer', authenticate, async (req, res, next) => {
  try {
    const { questionId, answerIndex, timeTaken } = req.body;
    
    if (!questionId || answerIndex === undefined) {
      return res.status(400).json({ 
        success: false, 
        message: 'questionId and answerIndex are required' 
      });
    }

    const result = await attemptService.submitAnswer(
      req.params.id,
      req.user.id,
      { questionId, answerIndex, timeTaken: timeTaken || 0 }
    );
    
    res.json({ success: true, data: result });
  } catch (error) {
    next(error);
  }
});

// Complete an attempt
router.post('/:id/complete', authenticate, async (req, res, next) => {
  try {
    const attempt = await attemptService.completeAttempt(req.params.id, req.user.id);
    res.json({ success: true, data: attempt });
  } catch (error) {
    next(error);
  }
});

// Get question set leaderboard
router.get('/leaderboard/:questionSetId', async (req, res, next) => {
  try {
    const { limit = 10 } = req.query;
    const leaderboard = await attemptService.getQuestionSetLeaderboard(
      req.params.questionSetId,
      parseInt(limit)
    );
    res.json({ success: true, data: leaderboard });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
