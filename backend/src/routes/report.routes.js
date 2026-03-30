const express = require('express');
const { body } = require('express-validator');
const { authenticateToken } = require('../middlewares/auth.middleware');
const { handleValidationErrors } = require('../utils/validators');
const { asyncHandler } = require('../middlewares/error.middleware');
const reportService = require('../services/report.service');

const router = express.Router();

// Create a report
router.post(
  '/',
  authenticateToken,
  [
    body('reportedId').isInt().withMessage('Reported ID must be an integer'),
    body('type').isIn(['user', 'question', 'inappropriate_content']).withMessage('Invalid report type'),
    body('reason').isString().notEmpty().withMessage('Reason is required'),
  ],
  handleValidationErrors,
  asyncHandler(async (req, res) => {
    const report = await reportService.createReport({
      userId: req.user.id,
      reportedId: req.body.reportedId,
      type: req.body.type,
      reason: req.body.reason,
    });
    res.status(201).json({
      success: true,
      message: 'Report submitted successfully',
      data: report,
    });
  })
);

// Get all reports (Admin only)
router.get(
  '/',
  authenticateToken,
  asyncHandler(async (req, res) => {
    // Simple admin check
    if (req.user.role !== 'admin') {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }

    const { page, limit, status } = req.query;
    const result = await reportService.getAllReports({
      page: parseInt(page) || 1,
      limit: parseInt(limit) || 20,
      status,
    });
    res.json({
      success: true,
      data: result,
    });
  })
);

// Update report status (Admin only)
router.patch(
  '/:id/status',
  authenticateToken,
  [
    body('status').isIn(['pending', 'reviewed', 'resolved']).withMessage('Invalid status'),
  ],
  handleValidationErrors,
  asyncHandler(async (req, res) => {
    if (req.user.role !== 'admin') {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }

    const report = await reportService.updateReportStatus(req.params.id, req.body.status);
    res.json({
      success: true,
      message: 'Report status updated',
      data: report,
    });
  })
);

module.exports = router;
