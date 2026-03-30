const express = require('express');
const router = express.Router();
const topicService = require('../services/topic.service');
const { authenticate } = require('../middlewares/auth.middleware');

/**
 * Topic Routes - Hierarchical topic management
 */

// Get all topics (tree or flat)
router.get('/', async (req, res, next) => {
  try {
    const { asTree } = req.query;
    const topics = await topicService.getAllTopics({ asTree: asTree === 'true' });
    res.json({ success: true, data: topics });
  } catch (error) {
    next(error);
  }
});

// Get popular topics
router.get('/popular', async (req, res, next) => {
  try {
    const { limit = 10 } = req.query;
    const topics = await topicService.getPopularTopics(parseInt(limit));
    res.json({ success: true, data: topics });
  } catch (error) {
    next(error);
  }
});

// Search topics
router.get('/search', async (req, res, next) => {
  try {
    const { q } = req.query;
    if (!q) {
      return res.status(400).json({ success: false, message: 'Search query required' });
    }
    const topics = await topicService.searchTopics(q);
    res.json({ success: true, data: topics });
  } catch (error) {
    next(error);
  }
});

// Get topic by ID
router.get('/:id', async (req, res, next) => {
  try {
    const topic = await topicService.getTopicById(req.params.id);
    res.json({ success: true, data: topic });
  } catch (error) {
    next(error);
  }
});

// Get topic path/breadcrumb
router.get('/:id/path', async (req, res, next) => {
  try {
    const path = await topicService.getTopicPath(req.params.id);
    res.json({ success: true, data: path });
  } catch (error) {
    next(error);
  }
});

// Get subtopics
router.get('/:id/subtopics', async (req, res, next) => {
  try {
    const subtopics = await topicService.getSubtopics(req.params.id);
    res.json({ success: true, data: subtopics });
  } catch (error) {
    next(error);
  }
});

// Create topic (admin only)
router.post('/', authenticate, async (req, res, next) => {
  try {
    if (req.user.role !== 'admin') {
      return res.status(403).json({ success: false, message: 'Admin access required' });
    }
    const topic = await topicService.createTopic(req.body);
    res.status(201).json({ success: true, data: topic });
  } catch (error) {
    next(error);
  }
});

// Update topic (admin only)
router.put('/:id', authenticate, async (req, res, next) => {
  try {
    if (req.user.role !== 'admin') {
      return res.status(403).json({ success: false, message: 'Admin access required' });
    }
    const topic = await topicService.updateTopic(req.params.id, req.body);
    res.json({ success: true, data: topic });
  } catch (error) {
    next(error);
  }
});

// Delete topic (admin only)
router.delete('/:id', authenticate, async (req, res, next) => {
  try {
    if (req.user.role !== 'admin') {
      return res.status(403).json({ success: false, message: 'Admin access required' });
    }
    const result = await topicService.deleteTopic(req.params.id);
    res.json({ success: true, ...result });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
