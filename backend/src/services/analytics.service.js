const { prisma } = require('../config/db');

/**
 * ANALYTICS TRACKING SERVICE
 * 
 * Tracks key metrics:
 * - Daily Active Users (DAU)
 * - Challenge acceptance rate
 * - Quiz completion rate
 * - User engagement patterns
 * - Topic popularity
 */

class AnalyticsService {
  /**
   * Record user activity (call on every authenticated request)
   * @param {number} userId - User ID
   * @param {string} action - Action type
   */
  async trackUserActivity(userId, action) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    // Upsert daily user activity
    await prisma.$executeRaw`
      INSERT INTO user_activity (user_id, date, action_count, last_action)
      VALUES (${userId}, ${today}, 1, ${action})
      ON CONFLICT (user_id, date)
      DO UPDATE SET 
        action_count = user_activity.action_count + 1,
        last_action = ${action}
    `;
  }

  /**
   * Get Daily Active Users count
   * @param {Date} startDate - Start date
   * @param {Date} endDate - End date
   * @returns {Promise<Array>} DAU data
   */
  async getDailyActiveUsers(startDate, endDate) {
    const dau = await prisma.$queryRaw`
      SELECT 
        date,
        COUNT(DISTINCT user_id) as active_users
      FROM user_activity
      WHERE date >= ${startDate} AND date <= ${endDate}
      GROUP BY date
      ORDER BY date ASC
    `;

    return dau;
  }

  /**
   * Get challenge acceptance rate
   * @param {Date} startDate - Start date
   * @param {Date} endDate - End date
   * @returns {Promise<Object>} Acceptance rate data
   */
  async getChallengeAcceptanceRate(startDate, endDate) {
    const stats = await prisma.challenge.groupBy({
      by: ['status'],
      where: {
        createdAt: {
          gte: startDate,
          lte: endDate
        }
      },
      _count: true
    });

    const total = stats.reduce((sum, s) => sum + s._count, 0);
    const accepted = stats.find(s => s.status === 'accepted')?._count || 0;
    const declined = stats.find(s => s.status === 'declined')?._count || 0;
    const completed = stats.find(s => s.status === 'completed')?._count || 0;

    return {
      total,
      accepted,
      declined,
      completed,
      acceptanceRate: total > 0 ? (accepted / total) * 100 : 0,
      completionRate: accepted > 0 ? (completed / accepted) * 100 : 0
    };
  }

  /**
   * Get quiz completion rate
   * @param {Date} startDate - Start date
   * @param {Date} endDate - End date
   * @returns {Promise<Object>} Completion rate data
   */
  async getQuizCompletionRate(startDate, endDate) {
    const attempts = await prisma.attempt.findMany({
      where: {
        startedAt: {
          gte: startDate,
          lte: endDate
        }
      },
      select: {
        completedAt: true
      }
    });

    const total = attempts.length;
    const completed = attempts.filter(a => a.completedAt !== null).length;

    return {
      total,
      completed,
      abandoned: total - completed,
      completionRate: total > 0 ? (completed / total) * 100 : 0
    };
  }

  /**
   * Get user engagement metrics
   * @param {Date} startDate - Start date
   * @param {Date} endDate - End date
   * @returns {Promise<Object>} Engagement metrics
   */
  async getUserEngagement(startDate, endDate) {
    const [
      totalUsers,
      activeUsers,
      newUsers,
      avgSessionsPerUser
    ] = await Promise.all([
      prisma.user.count(),
      prisma.user.count({
        where: {
          updatedAt: {
            gte: startDate,
            lte: endDate
          }
        }
      }),
      prisma.user.count({
        where: {
          createdAt: {
            gte: startDate,
            lte: endDate
          }
        }
      }),
      prisma.$queryRaw`
        SELECT AVG(action_count) as avg_actions
        FROM user_activity
        WHERE date >= ${startDate} AND date <= ${endDate}
      `
    ]);

    return {
      totalUsers,
      activeUsers,
      newUsers,
      engagementRate: totalUsers > 0 ? (activeUsers / totalUsers) * 100 : 0,
      avgActionsPerUser: avgSessionsPerUser[0]?.avg_actions || 0
    };
  }

  /**
   * Get topic popularity
   * @param {Date} startDate - Start date
   * @param {Date} endDate - End date
   * @param {number} limit - Number of topics
   * @returns {Promise<Array>} Popular topics
   */
  async getTopicPopularity(startDate, endDate, limit = 10) {
    const topicStats = await prisma.$queryRaw`
      SELECT 
        t.id,
        t.name,
        t.slug,
        COUNT(DISTINCT a.user_id) as unique_users,
        COUNT(a.id) as total_attempts,
        AVG(a.score) as avg_score
      FROM topics t
      INNER JOIN question_topics qt ON qt.topic_id = t.id
      INNER JOIN questions q ON q.id = qt.question_id
      INNER JOIN question_set_items qsi ON qsi.question_id = q.id
      INNER JOIN attempts a ON a.question_set_id = qsi.question_set_id
      WHERE a.started_at >= ${startDate} AND a.started_at <= ${endDate}
      GROUP BY t.id, t.name, t.slug
      ORDER BY total_attempts DESC
      LIMIT ${limit}
    `;

    return topicStats;
  }

  /**
   * Get user retention (7-day and 30-day)
   * @param {Date} cohortDate - Cohort start date
   * @returns {Promise<Object>} Retention data
   */
  async getUserRetention(cohortDate) {
    const cohortUsers = await prisma.user.findMany({
      where: {
        createdAt: {
          gte: cohortDate,
          lt: new Date(cohortDate.getTime() + 24 * 60 * 60 * 1000)
        }
      },
      select: { id: true }
    });

    const cohortUserIds = cohortUsers.map(u => u.id);
    const cohortSize = cohortUserIds.length;

    if (cohortSize === 0) return { day7: 0, day30: 0 };

    const day7 = new Date(cohortDate.getTime() + 7 * 24 * 60 * 60 * 1000);
    const day30 = new Date(cohortDate.getTime() + 30 * 24 * 60 * 60 * 1000);

    const [day7Retained, day30Retained] = await Promise.all([
      prisma.user.count({
        where: {
          id: { in: cohortUserIds },
          updatedAt: { gte: day7 }
        }
      }),
      prisma.user.count({
        where: {
          id: { in: cohortUserIds },
          updatedAt: { gte: day30 }
        }
      })
    ]);

    return {
      cohortSize,
      day7RetentionRate: (day7Retained / cohortSize) * 100,
      day30RetentionRate: (day30Retained / cohortSize) * 100
    };
  }

  /**
   * Get real-time dashboard stats
   * @returns {Promise<Object>} Dashboard data
   */
  async getDashboardStats() {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const last7Days = new Date(today.getTime() - 7 * 24 * 60 * 60 * 1000);
    const last30Days = new Date(today.getTime() - 30 * 24 * 60 * 60 * 1000);

    const [
      totalUsers,
      activeToday,
      activeLast7Days,
      totalQuestions,
      totalChallenges,
      totalAttempts,
      challengeStats,
      quizStats
    ] = await Promise.all([
      prisma.user.count(),
      prisma.user.count({
        where: { updatedAt: { gte: today } }
      }),
      prisma.user.count({
        where: { updatedAt: { gte: last7Days } }
      }),
      prisma.question.count(),
      prisma.challenge.count(),
      prisma.attempt.count(),
      this.getChallengeAcceptanceRate(last30Days, now),
      this.getQuizCompletionRate(last30Days, now)
    ]);

    return {
      users: {
        total: totalUsers,
        activeToday,
        activeLast7Days
      },
      content: {
        totalQuestions,
        totalChallenges,
        totalAttempts
      },
      challenges: challengeStats,
      quizzes: quizStats
    };
  }
}

// Create user_activity table if not exists
async function initAnalytics() {
  try {
    await prisma.$executeRaw`
      CREATE TABLE IF NOT EXISTS user_activity (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL,
        date DATE NOT NULL,
        action_count INTEGER DEFAULT 1,
        last_action VARCHAR(50),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(user_id, date)
      )
    `;
    await prisma.$executeRaw`
      CREATE INDEX IF NOT EXISTS idx_user_activity_date ON user_activity(date)
    `;
    await prisma.$executeRaw`
      CREATE INDEX IF NOT EXISTS idx_user_activity_user_date ON user_activity(user_id, date)
    `;
    console.log('✅ Analytics tables initialized');
  } catch (error) {
    console.log('⚠️ Analytics tables may already exist:', error.message);
  }
}

// Initialize on startup (skip during tests to avoid async side effects)
if (process.env.NODE_ENV !== 'test') {
  initAnalytics();
}

module.exports = new AnalyticsService();
