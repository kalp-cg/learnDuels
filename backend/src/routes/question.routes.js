/**
 * Question Routes
 * Routes for question management and retrieval
 */

const express = require('express');
const { query, param } = require('express-validator');
const { authenticateToken, optionalAuth } = require('../middlewares/auth.middleware');
const { handleValidationErrors, questionValidation, commonValidation } = require('../utils/validators');
const { asyncHandler } = require('../middlewares/error.middleware');

const router = express.Router();

// Import question service
const questionService = require('../services/question.service');

// Placeholder controllers
const questionController = {
  createQuestion: asyncHandler(async (req, res) => {
    const question = await questionService.createQuestion(req.body, req.userId);
    res.status(201).json({
      success: true,
      message: 'Question created successfully',
      data: question,
    });
  }),

  getQuestionById: asyncHandler(async (req, res) => {
    const { includeAnswer } = req.query;
    const question = await questionService.getQuestionById(
      req.params.id, 
      req.userId, 
      includeAnswer === 'true'
    );
    res.json({
      success: true,
      message: 'Question retrieved successfully',
      data: question,
    });
  }),

  getQuestions: asyncHandler(async (req, res) => {
    const { topicId, difficulty, type, status, authorId, page, limit, sortBy, sortOrder, includeAnswer } = req.query;
    
    const filters = {
      topicId,
      difficulty,
      type,
      status,
      authorId,
    };
    
    const options = {
      page: parseInt(page) || 1,
      limit: parseInt(limit) || 20,
      sortBy: sortBy || 'createdAt',
      sortOrder: sortOrder || 'desc',
      includeAnswer: includeAnswer === 'true',
    };

    const result = await questionService.getQuestions(filters, options);
    res.json({
      success: true,
      message: 'Questions retrieved successfully',
      data: result.questions,
      pagination: result.pagination,
    });
  }),

  updateQuestion: asyncHandler(async (req, res) => {
    const question = await questionService.updateQuestion(req.params.id, req.body, req.userId);
    res.json({
      success: true,
      message: 'Question updated successfully',
      data: question,
    });
  }),

  deleteQuestion: asyncHandler(async (req, res) => {
    await questionService.deleteQuestion(req.params.id, req.userId);
    res.json({
      success: true,
      message: 'Question deleted successfully',
    });
  }),

  searchQuestions: asyncHandler(async (req, res) => {
    const { q, topicId, difficulty, page, limit } = req.query;
    
    const filters = { topicId, difficulty };
    const options = { 
      page: parseInt(page) || 1, 
      limit: parseInt(limit) || 20 
    };

    const result = await questionService.searchQuestions(q, filters, options);
    res.json({
      success: true,
      message: 'Question search completed successfully',
      data: result.questions,
      pagination: result.pagination,
    });
  }),
};

// POST /api/questions - Create new question
router.post(
  '/',
  authenticateToken,
  questionValidation.create,
  handleValidationErrors,
  questionController.createQuestion
);

// GET /api/questions - Get questions with filters
router.get(
  '/',
  optionalAuth,
  [
    query('categoryId')
      .optional()
      .isInt({ min: 1 })
      .withMessage('Category ID must be a valid integer'),
    query('difficultyId')
      .optional()
      .isInt({ min: 1 })
      .withMessage('Difficulty ID must be a valid integer'),
    query('authorId')
      .optional()
      .isInt({ min: 1 })
      .withMessage('Author ID must be a valid integer'),
    query('sortBy')
      .optional()
      .isIn(['createdAt', 'updatedAt'])
      .withMessage('Sort by must be createdAt or updatedAt'),
    query('sortOrder')
      .optional()
      .isIn(['asc', 'desc'])
      .withMessage('Sort order must be asc or desc'),
    ...commonValidation.pagination,
  ],
  handleValidationErrors,
  questionController.getQuestions
);

// GET /api/questions/search - Search questions
router.get(
  '/search',
  optionalAuth,
  [
    query('q')
      .notEmpty()
      .withMessage('Search query is required')
      .isLength({ min: 3 })
      .withMessage('Search query must be at least 3 characters'),
    query('categoryId')
      .optional()
      .isInt({ min: 1 })
      .withMessage('Category ID must be a valid integer'),
    query('difficultyId')
      .optional()
      .isInt({ min: 1 })
      .withMessage('Difficulty ID must be a valid integer'),
    ...commonValidation.pagination,
  ],
  handleValidationErrors,
  questionController.searchQuestions
);

// GET /api/questions/:id - Get question by ID
router.get(
  '/:id',
  optionalAuth,
  [
    param('id')
      .isInt({ min: 1 })
      .withMessage('Valid question ID is required'),
  ],
  handleValidationErrors,
  questionController.getQuestionById
);

// PUT /api/questions/:id - Update question
router.put(
  '/:id',
  authenticateToken,
  [
    param('id')
      .isInt({ min: 1 })
      .withMessage('Valid question ID is required'),
    ...questionValidation.update
  ],
  handleValidationErrors,
  questionController.updateQuestion
);

// DELETE /api/questions/:id - Delete question
router.delete(
  '/:id',
  authenticateToken,
  [
    param('id')
      .isInt({ min: 1 })
      .withMessage('Valid question ID is required'),
  ],
  handleValidationErrors,
  questionController.deleteQuestion
);

module.exports = router;