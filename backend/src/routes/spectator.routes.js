const express = require('express');
const router = express.Router();
const spectatorService = require('../services/spectator.service');
const { authenticateToken } = require('../middlewares/auth.middleware');
const { successResponse, errorResponse } = require('../utils/response');

/**
 * @route   GET /api/spectate/duels
 * @desc    Get list of spectatable duels
 * @access  Private
 */
router.get('/duels', authenticateToken, async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 20;
    const duels = await spectatorService.getSpectatableDuels(limit);
    res.json(successResponse(duels, 'Spectatable duels retrieved'));
  } catch (error) {
    console.error('Get spectatable duels error:', error);
    res.status(500).json(errorResponse(error.message));
  }
});

/**
 * @route   GET /api/spectate/duels/:duelId
 * @desc    Get duel details for spectating
 * @access  Private
 */
router.get('/duels/:duelId', authenticateToken, async (req, res) => {
  try {
    const duelId = parseInt(req.params.duelId);
    const duelState = await spectatorService.joinSpectate(
      duelId,
      req.user.id,
      req.query.socketId || `http_${Date.now()}`
    );
    res.json(successResponse(duelState, 'Joined spectating'));
  } catch (error) {
    console.error('Join spectate error:', error);
    res.status(400).json(errorResponse(error.message));
  }
});

/**
 * @route   GET /api/spectate/duels/:duelId/spectators
 * @desc    Get list of spectators for a duel
 * @access  Private
 */
router.get('/duels/:duelId/spectators', authenticateToken, async (req, res) => {
  try {
    const duelId = parseInt(req.params.duelId);
    const spectators = await spectatorService.getSpectators(duelId);
    res.json(successResponse(spectators, 'Spectators retrieved'));
  } catch (error) {
    console.error('Get spectators error:', error);
    res.status(500).json(errorResponse(error.message));
  }
});

module.exports = router;
