const express = require('express');
const router = express.Router();
const gdprService = require('../services/gdpr.service');
const { authenticateToken } = require('../middlewares/auth.middleware');
const { successResponse, errorResponse } = require('../utils/response');

/**
 * @route   GET /api/gdpr/export
 * @desc    Export all user data (GDPR Article 20)
 * @access  Private
 */
router.get('/export', authenticateToken, async (req, res) => {
  try {
    const data = await gdprService.exportUserData(req.user.id);
    
    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Content-Disposition', `attachment; filename=user_data_${req.user.id}.json`);
    res.json(data);
  } catch (error) {
    console.error('Export user data error:', error);
    res.status(500).json(errorResponse(error.message));
  }
});

/**
 * @route   POST /api/gdpr/delete
 * @desc    Delete user account and all data (GDPR Article 17)
 * @access  Private
 */
router.post('/delete', authenticateToken, async (req, res) => {
  try {
    const { password } = req.body;

    if (!password) {
      return res.status(400).json(errorResponse('Password is required for account deletion'));
    }

    const result = await gdprService.deleteUserAccount(req.user.id, password);
    res.json(successResponse(result, 'Account deleted successfully'));
  } catch (error) {
    console.error('Delete account error:', error);
    res.status(400).json(errorResponse(error.message));
  }
});

/**
 * @route   POST /api/gdpr/anonymize
 * @desc    Anonymize user data (alternative to deletion)
 * @access  Private
 */
router.post('/anonymize', authenticateToken, async (req, res) => {
  try {
    const result = await gdprService.anonymizeUserData(req.user.id);
    res.json(successResponse(result, 'Account anonymized successfully'));
  } catch (error) {
    console.error('Anonymize account error:', error);
    res.status(400).json(errorResponse(error.message));
  }
});

/**
 * @route   GET /api/gdpr/processing-activities
 * @desc    Get data processing activities information
 * @access  Private
 */
router.get('/processing-activities', authenticateToken, async (req, res) => {
  try {
    const activities = await gdprService.getDataProcessingActivities(req.user.id);
    res.json(successResponse(activities, 'Processing activities retrieved'));
  } catch (error) {
    console.error('Get processing activities error:', error);
    res.status(500).json(errorResponse(error.message));
  }
});

module.exports = router;
