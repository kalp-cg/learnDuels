const express = require('express');
const router = express.Router();
const chatService = require('../services/chat.service');
const { authenticate } = require('../middlewares/auth.middleware');
const { successResponse, createdResponse, errorResponse } = require('../utils/response');

// Get all conversations for current user
router.get('/conversations', authenticate, async (req, res, next) => {
  try {
    const conversations = await chatService.getUserConversations(req.user.id);
    successResponse(res, conversations, 'Conversations retrieved');
  } catch (error) {
    next(error);
  }
});

// Start or get direct conversation with another user
router.post('/conversations/direct', authenticate, async (req, res, next) => {
  try {
    const { userId } = req.body;
    if (!userId) return errorResponse(res, 'User ID is required', 400);

    const conversation = await chatService.getOrCreateDirectConversation(req.user.id, parseInt(userId));
    successResponse(res, conversation, 'Conversation retrieved');
  } catch (error) {
    next(error);
  }
});

// Get messages for a conversation
router.get('/conversations/:id/messages', authenticate, async (req, res, next) => {
  try {
    const { page, limit } = req.query;
    const messages = await chatService.getConversationMessages(req.user.id, req.params.id, {
      page: parseInt(page) || 1,
      limit: parseInt(limit) || 50
    });
    successResponse(res, messages, 'Messages retrieved');
  } catch (error) {
    next(error);
  }
});

// Send a message
router.post('/conversations/:id/messages', authenticate, async (req, res, next) => {
  try {
    const { content } = req.body;
    if (!content) return errorResponse(res, 'Content is required', 400);

    const message = await chatService.sendMessage(req.user.id, req.params.id, content);

    createdResponse(res, message, 'Message sent');
  } catch (error) {
    next(error);
  }
});

// Upload image for chat
router.post('/upload-image', authenticate, async (req, res, next) => {
  const { uploadChatImage, handleUploadError } = require('../middlewares/upload.middleware');

  uploadChatImage(req, res, (err) => {
    if (err) {
      return handleUploadError(err, req, res, next);
    }

    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'No image file provided'
      });
    }

    // Return the file URL
    const imageUrl = `/uploads/${req.file.filename}`;

    res.status(200).json({
      success: true,
      data: {
        url: imageUrl,
        filename: req.file.filename
      },
      message: 'Image uploaded successfully'
    });
  });
});

module.exports = router;
