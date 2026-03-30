const express = require('express');
const router = express.Router();
const challengeService = require('../services/challenge.service');
const { authenticate } = require('../middlewares/auth.middleware');

/**
 * Challenge Routes - Async and instant challenges
 */

// Get user's challenges
router.get('/', authenticate, async (req, res, next) => {
  try {
    const { status, type, page, limit } = req.query;
    const result = await challengeService.getUserChallenges(req.user.id, {
      status,
      type,
      page: page ? parseInt(page) : undefined,
      limit: limit ? parseInt(limit) : undefined,
    });
    res.json({ success: true, ...result });
  } catch (error) {
    next(error);
  }
});

// Get user's challenge statistics
router.get('/stats', authenticate, async (req, res, next) => {
  try {
    const stats = await challengeService.getUserChallengeStats(req.user.id);
    res.json({ success: true, data: stats });
  } catch (error) {
    next(error);
  }
});

// Get challenge by ID
router.get('/:id', authenticate, async (req, res, next) => {
  try {
    const challenge = await challengeService.getChallengeById(req.params.id, req.user.id);
    res.json({ success: true, data: challenge });
  } catch (error) {
    next(error);
  }
});

// Create a challenge
router.post('/', authenticate, async (req, res, next) => {
  try {
    const challenge = await challengeService.createChallenge(req.body, req.user.id);
    res.status(201).json({ success: true, data: challenge });
  } catch (error) {
    next(error);
  }
});

// Accept a challenge
router.post('/:id/accept', authenticate, async (req, res, next) => {
  try {
    const challenge = await challengeService.acceptChallenge(req.params.id, req.user.id);
    res.json({ success: true, data: challenge });
  } catch (error) {
    next(error);
  }
});

// Decline a challenge
router.post('/:id/decline', authenticate, async (req, res, next) => {
  try {
    const result = await challengeService.declineChallenge(req.params.id, req.user.id);
    res.json({ success: true, ...result });
  } catch (error) {
    next(error);
  }
});

// Submit challenge result
router.post('/:id/result', authenticate, async (req, res, next) => {
  try {
    const challenge = await challengeService.submitResult(
      req.params.id,
      req.user.id,
      req.body
    );
    res.json({ success: true, data: challenge });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
