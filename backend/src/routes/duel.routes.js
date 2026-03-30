/**
 * Duel Routes
 * Routes for managing duels and duel gameplay
 */

const express = require('express');
const { body, param, query } = require('express-validator');
const { authenticateToken } = require('../middlewares/auth.middleware');
const { handleValidationErrors, commonValidation } = require('../utils/validators');
const { asyncHandler } = require('../middlewares/error.middleware');

const router = express.Router();

// Import duel service
const duelService = require('../services/duel.service');

const duelController = {
  createDuel: asyncHandler(async (req, res) => {
    const { opponentId, categoryId, difficultyId, questionCount, timeLimit } = req.body;
    const duel = await duelService.createDuel(
      req.userId,
      opponentId,
      { categoryId, difficultyId, questionCount, timeLimit }
    );
    res.status(201).json({
      success: true,
      message: 'Duel created successfully',
      data: duel,
    });
  }),

  getDuelById: asyncHandler(async (req, res) => {
    const duel = await duelService.getDuelById(req.params.id, req.userId);
    res.json({
      success: true,
      message: 'Duel retrieved successfully',
      data: duel,
    });
  }),

  getUserDuels: asyncHandler(async (req, res) => {
    const { status, page = 1, limit = 20 } = req.query;
    const result = await duelService.getUserDuels(req.userId, {
      status,
      page: parseInt(page),
      limit: parseInt(limit),
    });
    res.json({
      success: true,
      message: 'User duels retrieved successfully',
      data: result.duels,
      pagination: result.pagination,
    });
  }),

  submitAnswer: asyncHandler(async (req, res) => {
    const result = await duelService.submitAnswer(
      parseInt(req.params.duelId),
      req.userId,
      parseInt(req.params.questionId),
      req.body.selectedOption,
      req.body.timeTaken || 0
    );
    res.json({
      success: true,
      message: 'Answer submitted successfully',
      data: result,
    });
  }),

  findMatch: asyncHandler(async (req, res) => {
    const { categoryId } = req.body;
    const duel = await duelService.findMatch(req.userId, categoryId);
    res.json({
      success: true,
      message: 'Match found and duel created',
      data: duel,
    });
  }),
};

// POST /api/duels/matchmaking - Find a match
router.post(
  '/matchmaking',
  authenticateToken,
  [
    body('categoryId')
      .isInt({ min: 1 })
      .withMessage('Valid category ID is required'),
  ],
  handleValidationErrors,
  duelController.findMatch
);

// POST /api/duels - Create a new duel
router.post(
  '/',
  authenticateToken,
  [
    body('opponentId')
      .isInt({ min: 1 })
      .withMessage('Valid opponent ID is required'),
    body('categoryId')
      .isInt({ min: 1 })
      .withMessage('Valid category ID is required'),
    body('difficultyId')
      .isInt({ min: 1 })
      .withMessage('Valid difficulty ID is required'),
    body('questionCount')
      .optional()
      .isInt({ min: 1, max: 20 })
      .withMessage('Question count must be between 1 and 20'),
    body('timeLimit')
      .optional()
      .isInt({ min: 10 })
      .withMessage('Time limit must be at least 10 seconds'),
  ],
  handleValidationErrors,
  duelController.createDuel
);

// GET /api/duels/my - Get current user's duels
router.get(
  '/my',
  authenticateToken,
  [
    query('status')
      .optional()
      .isIn(['pending', 'active', 'completed'])
      .withMessage('Invalid status'),
    ...commonValidation.pagination,
  ],
  handleValidationErrors,
  duelController.getUserDuels
);

// GET /api/duels/:id - Get duel by ID
router.get(
  '/:id',
  authenticateToken,
  [
    param('id')
      .isInt({ min: 1 })
      .withMessage('Valid duel ID is required'),
  ],
  handleValidationErrors,
  duelController.getDuelById
);

// POST /api/duels/:duelId/questions/:questionId/answer - Submit answer
router.post(
  '/:duelId/questions/:questionId/answer',
  authenticateToken,
  [
    param('duelId')
      .isInt({ min: 1 })
      .withMessage('Valid duel ID is required'),
    param('questionId')
      .isInt({ min: 1 })
      .withMessage('Valid question ID is required'),
    body('selectedOption')
      .isIn(['A', 'B', 'C', 'D'])
      .withMessage('Selected option must be A, B, C, or D'),
  ],
  handleValidationErrors,
  duelController.submitAnswer
);

module.exports = router;
