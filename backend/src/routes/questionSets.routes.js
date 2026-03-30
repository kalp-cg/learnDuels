const express = require('express');
const router = express.Router();
const questionSetService = require('../services/questionSet.service');
const { authenticate } = require('../middlewares/auth.middleware');

/**
 * QuestionSet Routes - Saved question collections/quizzes
 */

// Get all question sets (public + user's own)
router.get('/', authenticate, async (req, res, next) => {
  try {
    const { visibility, authorId, page, limit } = req.query;
    const result = await questionSetService.getQuestionSets({
      userId: req.user.id,
      visibility,
      authorId,
      page: page ? parseInt(page) : undefined,
      limit: limit ? parseInt(limit) : undefined,
    });
    res.json({ success: true, ...result });
  } catch (error) {
    next(error);
  }
});

// Get popular question sets
router.get('/popular', async (req, res, next) => {
  try {
    const { limit = 10 } = req.query;
    const questionSets = await questionSetService.getPopularQuestionSets(parseInt(limit));
    res.json({ success: true, data: questionSets });
  } catch (error) {
    next(error);
  }
});

// Get question set by ID
router.get('/:id', authenticate, async (req, res, next) => {
  try {
    const questionSet = await questionSetService.getQuestionSetById(
      req.params.id,
      req.user.id
    );
    res.json({ success: true, data: questionSet });
  } catch (error) {
    next(error);
  }
});

// Create question set
router.post('/', authenticate, async (req, res, next) => {
  try {
    const questionSet = await questionSetService.createQuestionSet(
      req.body,
      req.user.id
    );
    res.status(201).json({ success: true, data: questionSet });
  } catch (error) {
    next(error);
  }
});

// Update question set
router.put('/:id', authenticate, async (req, res, next) => {
  try {
    const questionSet = await questionSetService.updateQuestionSet(
      req.params.id,
      req.body,
      req.user.id
    );
    res.json({ success: true, data: questionSet });
  } catch (error) {
    next(error);
  }
});

// Delete question set
router.delete('/:id', authenticate, async (req, res, next) => {
  try {
    const result = await questionSetService.deleteQuestionSet(req.params.id, req.user.id);
    res.json({ success: true, ...result });
  } catch (error) {
    next(error);
  }
});

// Add question to set
router.post('/:id/questions', authenticate, async (req, res, next) => {
  try {
    const { questionId } = req.body;
    const questionSet = await questionSetService.addQuestion(
      req.params.id,
      questionId,
      req.user.id
    );
    res.json({ success: true, data: questionSet });
  } catch (error) {
    next(error);
  }
});

// Remove question from set
router.delete('/:id/questions/:questionId', authenticate, async (req, res, next) => {
  try {
    const questionSet = await questionSetService.removeQuestion(
      req.params.id,
      parseInt(req.params.questionId),
      req.user.id
    );
    res.json({ success: true, data: questionSet });
  } catch (error) {
    next(error);
  }
});

// Auto-generate quiz from topic and difficulty
// POST /api/question-sets/generate
router.post('/generate', authenticate, async (req, res, next) => {
  try {
    const { topicId, difficulty, numQuestions, name } = req.body;

    if (!topicId) {
      return res.status(400).json({
        success: false,
        message: 'topicId is required'
      });
    }

    const questionSet = await questionSetService.generateQuiz(
      { topicId, difficulty, numQuestions, name },
      req.user.id
    );

    res.status(201).json({
      success: true,
      data: questionSet,
      message: 'Quiz generated successfully'
    });
  } catch (error) {
    next(error);
  }
});

// Clone question set
router.post('/:id/clone', authenticate, async (req, res, next) => {
  try {
    const { newName } = req.body;
    const questionSet = await questionSetService.cloneQuestionSet(
      req.params.id,
      req.user.id,
      newName
    );
    res.status(201).json({ success: true, data: questionSet });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
