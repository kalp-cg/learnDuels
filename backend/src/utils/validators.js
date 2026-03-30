/**
 * Validation Utilities
 * Common validation functions and schemas
 */

const { body, param, query, validationResult } = require('express-validator');

/**
 * Handle validation errors
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next function
 */
const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array(),
    });
  }
  next();
};

// User validation schemas
const userValidation = {
  signup: [
    body('username')
      .isLength({ min: 2, max: 50 })
      .withMessage('Username must be between 2 and 50 characters')
      .trim(),

    body('email')
      .isEmail()
      .withMessage('Please provide a valid email address')
      .normalizeEmail(),

    body('password')
      .isLength({ min: 8 })
      .withMessage('Password must be at least 8 characters long')
      .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).*$/)
      .withMessage('Password must contain at least one lowercase letter, one uppercase letter, and one number'),
  ],

  login: [
    body('email')
      .isEmail()
      .withMessage('Please provide a valid email address')
      .normalizeEmail(),

    body('password')
      .notEmpty()
      .withMessage('Password is required'),
  ],

  updateProfile: [
    body('username')
      .optional()
      .isLength({ min: 2, max: 50 })
      .withMessage('Username must be between 2 and 50 characters')
      .trim(),

    body('avatarUrl')
      .optional({ nullable: true, checkFalsy: true }) // Allow null, undefined, empty string
      .isURL()
      .withMessage('Avatar URL must be a valid URL'),
  ],
};

// Question validation schemas
const questionValidation = {
  create: [
    body('content')
      .notEmpty()
      .withMessage('Content is required')
      .isLength({ min: 5 })
      .withMessage('Content must be at least 5 characters'),

    body('options')
      .isArray({ min: 2 })
      .withMessage('At least 2 options are required'),

    body('options.*.id')
      .notEmpty()
      .withMessage('Option ID is required'),

    body('options.*.text')
      .notEmpty()
      .withMessage('Option text is required'),

    body('correctAnswer')
      .notEmpty()
      .withMessage('Correct answer is required'),

    body('difficulty')
      .isIn(['easy', 'medium', 'hard'])
      .withMessage('Difficulty must be easy, medium, or hard'),

    body('topicIds')
      .optional()
      .isArray()
      .withMessage('Topic IDs must be an array'),
  ],

  update: [
    body('content')
      .optional()
      .isLength({ min: 5 })
      .withMessage('Content must be at least 5 characters'),

    body('options')
      .optional()
      .isArray({ min: 2 })
      .withMessage('At least 2 options are required'),

    body('correctAnswer')
      .optional(),

    body('difficulty')
      .optional()
      .isIn(['easy', 'medium', 'hard'])
      .withMessage('Difficulty must be easy, medium, or hard'),

    body('topicIds')
      .optional()
      .isArray()
      .withMessage('Topic IDs must be an array'),
  ],
};

// Topic validation schemas
const topicValidation = {
  create: [
    body('name')
      .notEmpty()
      .withMessage('Topic name is required')
      .isLength({ min: 2, max: 100 })
      .withMessage('Topic name must be between 2 and 100 characters'),

    body('parentId')
      .optional()
      .isUUID()
      .withMessage('Parent ID must be a valid UUID'),
  ],
};

// Quiz validation schemas
const quizValidation = {
  create: [
    body('name')
      .notEmpty()
      .withMessage('Quiz name is required')
      .isLength({ min: 3, max: 200 })
      .withMessage('Quiz name must be between 3 and 200 characters'),

    body('questionIds')
      .isArray({ min: 1, max: 50 })
      .withMessage('Quiz must have between 1 and 50 questions'),

    body('visibility')
      .optional()
      .isIn(['PUBLIC', 'PRIVATE'])
      .withMessage('Visibility must be PUBLIC or PRIVATE'),
  ],

  attempt: [
    body('answers')
      .isArray()
      .withMessage('Answers must be provided as an array'),
  ],
};

// Challenge validation schemas
const challengeValidation = {
  create: [
    body('type')
      .isIn(['ASYNC', 'INSTANT'])
      .withMessage('Challenge type must be ASYNC or INSTANT'),

    body('opponentId')
      .optional()
      .isUUID()
      .withMessage('Opponent ID must be a valid UUID'),

    body('settings')
      .isObject()
      .withMessage('Settings must be an object'),

    body('settings.topicId')
      .optional()
      .isUUID()
      .withMessage('Topic ID must be a valid UUID'),

    body('settings.difficulty')
      .optional()
      .isIn(['EASY', 'MEDIUM', 'HARD'])
      .withMessage('Difficulty must be EASY, MEDIUM, or HARD'),

    body('settings.questionCount')
      .optional()
      .isInt({ min: 1, max: 20 })
      .withMessage('Question count must be between 1 and 20'),
  ],

  accept: [
    param('id')
      .isUUID()
      .withMessage('Challenge ID must be a valid UUID'),
  ],
};

// Common parameter validation
const commonValidation = {
  uuid: [
    param('id')
      .isUUID()
      .withMessage('ID must be a valid UUID'),
  ],

  pagination: [
    query('page')
      .optional()
      .isInt({ min: 1 })
      .withMessage('Page must be a positive integer'),

    query('limit')
      .optional()
      .isInt({ min: 1, max: 5000 })
      .withMessage('Limit must be between 1 and 5000'),
  ],
};

/**
 * Sanitize user input
 * @param {string} input - Input string
 * @returns {string} Sanitized string
 */
function sanitizeInput(input) {
  if (typeof input !== 'string') {
    return input;
  }

  return input
    .trim()
    .replace(/[<>]/g, '') // Remove potential HTML tags
    .slice(0, 1000); // Limit length
}

/**
 * Validate email format
 * @param {string} email - Email address
 * @returns {boolean} True if valid
 */
function isValidEmail(email) {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

/**
 * Validate UUID format
 * @param {string} uuid - UUID string
 * @returns {boolean} True if valid
 */
function isValidUUID(uuid) {
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return uuidRegex.test(uuid);
}

module.exports = {
  handleValidationErrors,
  userValidation,
  questionValidation,
  topicValidation,
  quizValidation,
  challengeValidation,
  commonValidation,
  sanitizeInput,
  isValidEmail,
  isValidUUID,
};