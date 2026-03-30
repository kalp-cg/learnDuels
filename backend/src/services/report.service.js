/**
 * Report Service
 * Handles user reports and moderation
 */

const { prisma } = require('../config/db');
const { createError } = require('../middlewares/error.middleware');

/**
 * Create a report
 */
async function createReport(reportData) {
  try {
    const { reportedId, userId, reason, type } = reportData;

    const report = await prisma.report.create({
      data: {
        reportedId: parseInt(reportedId),
        userId: parseInt(userId),
        reason,
        type: type || 'inappropriate_content',
        status: 'pending',
      },
      include: {
        user: {
          select: {
            id: true,
            fullName: true,
          },
        },
      },
    });

    return report;
  } catch (error) {
    throw createError.internal('Failed to create report');
  }
}

/**
 * Get all reports
 */
async function getAllReports(options = {}) {
  const { page = 1, limit = 20, status } = options;
  const skip = (page - 1) * limit;

  try {
    const where = {};
    if (status) where.status = status;

    const [reports, totalCount] = await Promise.all([
      prisma.report.findMany({
        where,
        include: {
          user: {
            select: {
              id: true,
              fullName: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      prisma.report.count({ where }),
    ]);

    return {
      reports,
      pagination: {
        total: totalCount,
        page,
        limit,
        totalPages: Math.ceil(totalCount / limit),
      },
    };
  } catch (error) {
    throw createError.internal('Failed to fetch reports');
  }
}

/**
 * Update report status
 */
async function updateReportStatus(reportId, status) {
  try {
    const report = await prisma.report.update({
      where: { id: parseInt(reportId) },
      data: { status },
    });

    return report;
  } catch (error) {
    throw createError.internal('Failed to update report status');
  }
}

/**
 * Get user's reports
 */
async function getUserReports(userId, options = {}) {
  const { page = 1, limit = 20 } = options;
  const skip = (page - 1) * limit;

  try {
    const [reports, totalCount] = await Promise.all([
      prisma.report.findMany({
        where: { userId: parseInt(userId) },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      prisma.report.count({
        where: { userId: parseInt(userId) },
      }),
    ]);

    return {
      reports,
      pagination: {
        total: totalCount,
        page,
        limit,
        totalPages: Math.ceil(totalCount / limit),
      },
    };
  } catch (error) {
    throw createError.internal('Failed to fetch user reports');
  }
}

module.exports = {
  createReport,
  getAllReports,
  updateReportStatus,
  getUserReports,
};
