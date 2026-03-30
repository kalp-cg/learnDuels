/**
 * Feed Service
 * Handles activity feed generation and retrieval
 */

const { prisma } = require('../config/db');
const { createError } = require('../middlewares/error.middleware');

/**
 * Create a new activity
 * @param {number} userId - The user performing the action
 * @param {string} type - Activity type (create_quiz, won_duel, new_highscore, level_up)
 * @param {Object} data - Metadata for the activity
 */
async function createActivity(userId, type, data = {}) {
  try {
    await prisma.activity.create({
      data: {
        userId: parseInt(userId),
        type,
        data,
      },
    });
  } catch (error) {
    console.error('Create activity error:', error);
    // Don't throw error to prevent blocking main flow
  }
}

/**
 * Get activity feed for a user (activities from people they follow)
 */
async function getFeed(userId, options = {}) {
  const { page = 1, limit = 20 } = options;
  const skip = (page - 1) * limit;

  try {
    // 1. Get IDs of users being followed
    const following = await prisma.userFollower.findMany({
      where: { followerId: parseInt(userId) },
      select: { followingId: true },
    });

    const followingIds = following.map(f => f.followingId);

    // Include self in feed? Usually yes, or maybe separate tab. 
    // For now, let's include self to make the feed less empty for new users.
    followingIds.push(parseInt(userId));

    if (followingIds.length === 0) {
      return {
        activities: [],
        pagination: {
          total: 0,
          page,
          limit,
          totalPages: 0,
        },
      };
    }

    // 2. Fetch activities
    const [activities, totalCount] = await Promise.all([
      prisma.activity.findMany({
        where: {
          userId: { in: followingIds },
        },
        include: {
          user: {
            select: {
              id: true,
              fullName: true,
              username: true,
              avatarUrl: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      prisma.activity.count({
        where: {
          userId: { in: followingIds },
        },
      }),
    ]);

    return {
      activities,
      pagination: {
        total: totalCount,
        page,
        limit,
        totalPages: Math.ceil(totalCount / limit),
      },
    };
  } catch (error) {
    console.error('Get feed error:', error);
    throw createError.internal('Failed to fetch activity feed');
  }
}

module.exports = {
  createActivity,
  getFeed,
};
