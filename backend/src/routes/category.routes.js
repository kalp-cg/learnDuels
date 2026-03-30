/**
 * Category Routes
 * Routes for managing categories and difficulty levels
 */

const express = require('express');
const { body } = require('express-validator');
const { authenticateToken, requireAdmin } = require('../middlewares/auth.middleware');
const { handleValidationErrors } = require('../utils/validators');
const { asyncHandler } = require('../middlewares/error.middleware');

const router = express.Router();

// Import category service
const categoryService = require('../services/category.service');

const categoryController = {
  getAllCategories: asyncHandler(async (req, res) => {
    const categories = await categoryService.getAllCategories();
    res.json({
      success: true,
      message: 'Categories retrieved successfully',
      data: categories,
    });
  }),

  createCategory: asyncHandler(async (req, res) => {
    const category = await categoryService.createCategory(req.body.name);
    res.status(201).json({
      success: true,
      message: 'Category created successfully',
      data: category,
    });
  }),

  getAllDifficulties: asyncHandler(async (req, res) => {
    const difficulties = await categoryService.getAllDifficulties();
    res.json({
      success: true,
      message: 'Difficulties retrieved successfully',
      data: difficulties,
    });
  }),

  createDifficulty: asyncHandler(async (req, res) => {
    const difficulty = await categoryService.createDifficulty(req.body.level);
    res.status(201).json({
      success: true,
      message: 'Difficulty level created successfully',
      data: difficulty,
    });
  }),
};

// GET /api/categories - Get all categories
router.get('/', categoryController.getAllCategories);

// POST /api/categories - Create new category (admin only)
router.post(
  '/',
  authenticateToken,
  requireAdmin,
  [
    body('name')
      .notEmpty()
      .withMessage('Category name is required')
      .isLength({ min: 2, max: 50 })
      .withMessage('Category name must be between 2 and 50 characters'),
  ],
  handleValidationErrors,
  categoryController.createCategory
);

// GET /api/categories/difficulties - Get all difficulty levels
router.get('/difficulties', categoryController.getAllDifficulties);

// POST /api/categories/difficulties - Create new difficulty (admin only)
router.post(
  '/difficulties',
  authenticateToken,
  requireAdmin,
  [
    body('level')
      .notEmpty()
      .withMessage('Difficulty level is required')
      .isLength({ min: 2, max: 20 })
      .withMessage('Difficulty level must be between 2 and 20 characters'),
  ],
  handleValidationErrors,
  categoryController.createDifficulty
);

module.exports = router;
