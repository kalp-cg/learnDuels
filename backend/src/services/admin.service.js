const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

/**
 * Admin Service - Moderation queue and content management
 * PRD Requirement: Flagging system and moderation queue
 */

class AdminService {
  /**
   * Get moderation queue (pending questions)
   */
  async getModerationQueue(options = {}) {
    const { page = 1, limit = 20, status = 'pending' } = options;

    const where = {
      status,
    };

    const [questions, total] = await Promise.all([
      prisma.question.findMany({
        where,
        include: {
          author: {
            select: {
              id: true,
              fullName: true,
              email: true,
              reputation: true,
              createdAt: true,
            },
          },
        },
        orderBy: { createdAt: 'asc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      prisma.question.count({ where }),
    ]);

    return {
      questions,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * Approve a question
   */
  async approveQuestion(questionId, adminId) {
    const question = await prisma.question.findUnique({
      where: { id: parseInt(questionId) },
      include: { author: true },
    });

    if (!question) {
      throw new Error('Question not found');
    }

    if (question.status === 'published') {
      throw new Error('Question is already published');
    }

    // Update question status
    const updated = await prisma.question.update({
      where: { id: parseInt(questionId) },
      data: {
        status: 'published',
        approvedBy: adminId,
        approvedAt: new Date(),
      },
    });

    // Increase author's reputation
    await prisma.user.update({
      where: { id: question.authorId },
      data: {
        reputation: { increment: 5 },
      },
    });

    // Notify author
    await prisma.notification.create({
      data: {
        userId: question.authorId,
        message: 'Your question has been approved and published!',
        type: 'question_approved',
        metadata: { questionId: question.id },
      },
    });

    return updated;
  }

  /**
   * Reject a question
   */
  async rejectQuestion(questionId, adminId, reason) {
    const question = await prisma.question.findUnique({
      where: { id: parseInt(questionId) },
    });

    if (!question) {
      throw new Error('Question not found');
    }

    // Update question status
    const updated = await prisma.question.update({
      where: { id: parseInt(questionId) },
      data: {
        status: 'rejected',
        rejectedBy: adminId,
        rejectedAt: new Date(),
        rejectionReason: reason,
      },
    });

    // Notify author
    await prisma.notification.create({
      data: {
        userId: question.authorId,
        message: `Your question was rejected. Reason: ${reason}`,
        type: 'question_rejected',
        metadata: { questionId: question.id, reason },
      },
    });

    return updated;
  }

  /**
   * Get all flagged content (reports)
   */
  async getFlaggedContent(options = {}) {
    const { status = 'pending', page = 1, limit = 20 } = options;

    const where = { status };

    const [flags, total] = await Promise.all([
      prisma.flag.findMany({
        where,
        include: {
          reporter: {
            select: {
              id: true,
              fullName: true,
              email: true,
            },
          },
          question: {
            include: {
              author: {
                select: {
                  id: true,
                  fullName: true,
                  email: true,
                },
              },
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      prisma.flag.count({ where }),
    ]);

    return {
      flags,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * Flag a question
   */
  async flagQuestion(questionId, userId, reason) {
    const question = await prisma.question.findUnique({
      where: { id: parseInt(questionId) },
    });

    if (!question) {
      throw new Error('Question not found');
    }

    // Check if user already flagged this question
    const existingFlag = await prisma.flag.findFirst({
      where: {
        questionId: parseInt(questionId),
        reporterId: userId,
        status: 'pending',
      },
    });

    if (existingFlag) {
      throw new Error('You have already flagged this question');
    }

    const flag = await prisma.flag.create({
      data: {
        questionId: parseInt(questionId),
        reporterId: userId,
        reason,
        status: 'pending',
      },
      include: {
        reporter: {
          select: {
            id: true,
            fullName: true,
          },
        },
        question: {
          select: {
            id: true,
            content: true,
            authorId: true,
          },
        },
      },
    });

    return flag;
  }

  /**
   * Resolve a flag (approve or dismiss)
   */
  async resolveFlag(flagId, adminId, resolution, action) {
    const flag = await prisma.flag.findUnique({
      where: { id: parseInt(flagId) },
      include: { question: true },
    });

    if (!flag) {
      throw new Error('Flag not found');
    }

    if (flag.status !== 'pending') {
      throw new Error('Flag is already resolved');
    }

    // Update flag
    const updated = await prisma.flag.update({
      where: { id: parseInt(flagId) },
      data: {
        status: resolution, // 'approved' or 'dismissed'
        resolvedBy: adminId,
        resolvedAt: new Date(),
        resolution: action, // 'delete_question', 'warn_user', 'no_action'
      },
    });

    // Take action based on resolution
    if (resolution === 'approved') {
      if (action === 'delete_question') {
        await prisma.question.delete({
          where: { id: flag.questionId },
        });

        // Decrease author reputation
        await prisma.user.update({
          where: { id: flag.question.authorId },
          data: {
            reputation: { decrement: 10 },
          },
        });
      } else if (action === 'warn_user') {
        await prisma.notification.create({
          data: {
            userId: flag.question.authorId,
            message: `Warning: Your question was flagged for: ${flag.reason}`,
            type: 'warning',
            metadata: { questionId: flag.questionId, reason: flag.reason },
          },
        });

        // Decrease reputation slightly
        await prisma.user.update({
          where: { id: flag.question.authorId },
          data: {
            reputation: { decrement: 3 },
          },
        });
      }
    }

    // Notify reporter
    await prisma.notification.create({
      data: {
        userId: flag.reporterId,
        message: `Your flag has been ${resolution}.`,
        type: 'flag_resolved',
        metadata: { flagId: flag.id, resolution },
      },
    });

    return updated;
  }

  /**
   * Ban/suspend a user
   */
  async suspendUser(userId, adminId, reason, duration) {
    const user = await prisma.user.findUnique({
      where: { id: parseInt(userId) },
    });

    if (!user) {
      throw new Error('User not found');
    }

    if (user.role === 'admin') {
      throw new Error('Cannot suspend an admin user');
    }

    const suspendUntil = new Date();
    suspendUntil.setDate(suspendUntil.getDate() + duration); // duration in days

    const updated = await prisma.user.update({
      where: { id: parseInt(userId) },
      data: {
        isActive: false,
        suspendedUntil,
        suspensionReason: reason,
      },
    });

    // Notify user
    await prisma.notification.create({
      data: {
        userId: parseInt(userId),
        message: `Your account has been suspended. Reason: ${reason}. Duration: ${duration} days.`,
        type: 'account_suspended',
        metadata: { reason, duration, suspendUntil },
      },
    });

    // Log admin action
    await prisma.adminLog.create({
      data: {
        adminId,
        action: 'suspend_user',
        targetUserId: parseInt(userId),
        reason,
        metadata: { duration, suspendUntil },
      },
    });

    return updated;
  }

  /**
   * Unsuspend a user
   */
  async unsuspendUser(userId, adminId) {
    const user = await prisma.user.findUnique({
      where: { id: parseInt(userId) },
    });

    if (!user) {
      throw new Error('User not found');
    }

    const updated = await prisma.user.update({
      where: { id: parseInt(userId) },
      data: {
        isActive: true,
        suspendedUntil: null,
        suspensionReason: null,
      },
    });

    // Notify user
    await prisma.notification.create({
      data: {
        userId: parseInt(userId),
        message: 'Your account has been reactivated. Welcome back!',
        type: 'account_reactivated',
      },
    });

    // Log admin action
    await prisma.adminLog.create({
      data: {
        adminId,
        action: 'unsuspend_user',
        targetUserId: parseInt(userId),
        reason: 'Account reactivated',
      },
    });

    return updated;
  }


  /**
   * Get all users
   */
  async getAllUsers(options = {}) {
    const { page = 1, limit = 20, search } = options;
    const skip = (page - 1) * limit;

    const where = {};
    if (search) {
      where.OR = [
        { username: { contains: search, mode: 'insensitive' } },
        { email: { contains: search, mode: 'insensitive' } },
        { fullName: { contains: search, mode: 'insensitive' } },
      ];
    }

    const [users, total] = await Promise.all([
      prisma.user.findMany({
        where,
        select: {
          id: true,
          username: true,
          email: true,
          fullName: true,
          avatarUrl: true,
          role: true,
          isActive: true,
          createdAt: true,
        },
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      prisma.user.count({ where }),
    ]);

    return {
      users,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * Get admin dashboard statistics
   */
  async getDashboardStats() {
    const [
      pendingQuestions,
      pendingFlags,
      activeUsers,
      suspendedUsers,
      totalQuestions,
      totalChallenges,
      todaySignups,
    ] = await Promise.all([
      prisma.question.count({ where: { status: 'pending' } }),
      prisma.flag.count({ where: { status: 'pending' } }),
      prisma.user.count({ where: { isActive: true } }),
      prisma.user.count({ where: { isActive: false } }),
      prisma.question.count(),
      prisma.challenge.count(),
      prisma.user.count({
        where: {
          createdAt: {
            gte: new Date(new Date().setHours(0, 0, 0, 0)),
          },
        },
      }),
    ]);

    return {
      pendingQuestions,
      pendingFlags,
      activeUsers,
      suspendedUsers,
      totalQuestions,
      totalChallenges,
      todaySignups,
    };
  }

  /**
   * Get admin activity logs
   */
  async getAdminLogs(options = {}) {
    const { adminId, action, page = 1, limit = 50 } = options;

    const where = {
      ...(adminId && { adminId: parseInt(adminId) }),
      ...(action && { action }),
    };

    const [logs, total] = await Promise.all([
      prisma.adminLog.findMany({
        where,
        include: {
          admin: {
            select: {
              id: true,
              fullName: true,
              email: true,
            },
          },
          targetUser: {
            select: {
              id: true,
              fullName: true,
              email: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      prisma.adminLog.count({ where }),
    ]);

    return {
      logs,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }
}

module.exports = new AdminService();
