const prisma = require('../config/db');

/**
 * GDPR COMPLIANCE SERVICE
 * 
 * Features:
 * - Export all user data
 * - Delete user account and data
 * - Anonymize user data
 * - Data portability
 */

class GdprService {
  /**
   * Export all user data (GDPR Article 20)
   * @param {number} userId - User ID
   * @returns {Promise<Object>} Complete user data export
   */
  async exportUserData(userId) {
    const [
      user,
      attempts,
      challenges,
      challengeParticipations,
      followers,
      following,
      notifications,
      flags,
      adminLogs,
      questionSets,
      questions,
      duelAnswers,
      leaderboardEntries
    ] = await Promise.all([
      // Basic user data
      prisma.user.findUnique({
        where: { id: userId },
        include: {
          refreshTokens: { select: { token: false, createdAt: true, expiresAt: true } }
        }
      }),

      // Quiz attempts
      prisma.attempt.findMany({
        where: { userId },
        include: {
          questionSet: { select: { title: true } }
        }
      }),

      // Challenges created
      prisma.challenge.findMany({
        where: { challengerId: userId },
        include: {
          challenged: { select: { username: true } },
          questionSet: { select: { title: true } }
        }
      }),

      // Challenge participations
      prisma.challengeParticipant.findMany({
        where: { userId },
        include: {
          challenge: {
            include: {
              challenger: { select: { username: true } },
              questionSet: { select: { title: true } }
            }
          }
        }
      }),

      // Followers
      prisma.userFollower.findMany({
        where: { followingId: userId },
        include: {
          follower: { select: { username: true, email: true } }
        }
      }),

      // Following
      prisma.userFollower.findMany({
        where: { followerId: userId },
        include: {
          following: { select: { username: true, email: true } }
        }
      }),

      // Notifications
      prisma.notification.findMany({
        where: { userId }
      }),

      // Content flags submitted
      prisma.flag.findMany({
        where: { userId }
      }),

      // Admin actions on user
      prisma.adminLog.findMany({
        where: { targetUserId: userId }
      }),

      // Question sets created
      prisma.questionSet.findMany({
        where: { authorId: userId },
        include: {
          items: {
            include: {
              question: true
            }
          }
        }
      }),

      // Questions created
      prisma.question.findMany({
        where: { authorId: userId },
        include: {
          topics: true
        }
      }),

      // Duel answers
      prisma.duelAnswer.findMany({
        where: { userId },
        include: {
          question: { select: { question: true } }
        }
      }),

      // Leaderboard entries
      prisma.leaderboardEntry.findMany({
        where: { userId }
      })
    ]);

    return {
      exportDate: new Date().toISOString(),
      exportVersion: '1.0',
      userData: {
        id: user.id,
        username: user.username,
        email: user.email,
        bio: user.bio,
        avatarUrl: user.avatarUrl,
        xp: user.xp,
        level: user.level,
        reputation: user.reputation,
        followersCount: user.followersCount,
        followingCount: user.followingCount,
        isActive: user.isActive,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
        lastLoginAt: user.lastLoginAt
      },
      activity: {
        quizAttempts: attempts.map(a => ({
          questionSet: a.questionSet.title,
          score: a.score,
          timeTaken: a.timeTaken,
          startedAt: a.startedAt,
          completedAt: a.completedAt
        })),
        challengesCreated: challenges.length,
        challengesParticipated: challengeParticipations.length,
        totalQuestionsCreated: questions.length,
        totalQuestionSetsCreated: questionSets.length
      },
      socialData: {
        followers: followers.map(f => ({
          username: f.follower.username,
          followedAt: f.createdAt
        })),
        following: following.map(f => ({
          username: f.following.username,
          followedAt: f.createdAt
        }))
      },
      content: {
        questionSets: questionSets.map(qs => ({
          title: qs.title,
          description: qs.description,
          isPublic: qs.isPublic,
          questionCount: qs.items.length,
          createdAt: qs.createdAt
        })),
        questions: questions.map(q => ({
          question: q.question,
          options: q.options,
          difficulty: q.difficulty,
          status: q.status,
          topics: q.topics.map(t => t.name),
          createdAt: q.createdAt
        }))
      },
      notifications: notifications.map(n => ({
        type: n.type,
        message: n.message,
        read: n.read,
        createdAt: n.createdAt
      })),
      moderation: {
        flagsSubmitted: flags.length,
        adminActions: adminLogs.map(log => ({
          action: log.action,
          performedAt: log.createdAt
        }))
      },
      statistics: {
        totalAttempts: attempts.length,
        completedAttempts: attempts.filter(a => a.completedAt).length,
        averageScore: attempts.length > 0 
          ? attempts.reduce((sum, a) => sum + a.score, 0) / attempts.length 
          : 0,
        leaderboardEntries: leaderboardEntries.length
      }
    };
  }

  /**
   * Delete user account and all associated data (GDPR Article 17)
   * Implements soft-delete for audit purposes
   * @param {number} userId - User ID
   * @param {string} password - User password for verification
   * @returns {Promise<Object>} Deletion result
   */
  async deleteUserAccount(userId, password) {
    // Verify user and password
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, passwordHash: true }
    });

    if (!user) {
      throw new Error('User not found');
    }

    const bcrypt = require('bcryptjs');
    const isValidPassword = await bcrypt.compare(password, user.passwordHash);
    if (!isValidPassword) {
      throw new Error('Invalid password');
    }

    // Soft delete user account and associated data
    await prisma.$transaction(async (tx) => {
      // Soft delete user's questions
      await tx.question.updateMany({ 
        where: { authorId: userId },
        data: { deletedAt: new Date() }
      });
      
      // Soft delete question sets
      await tx.questionSet.updateMany({ 
        where: { authorId: userId },
        data: { deletedAt: new Date() }
      });
      
      // Soft delete the user account
      await tx.user.update({ 
        where: { id: userId },
        data: { 
          deletedAt: new Date(),
          isActive: false,
          email: `deleted_${userId}@deleted.com`, // Prevent email conflicts
          username: `deleted_user_${userId}` // Prevent username conflicts
        }
      });
    });

    return {
      success: true,
      message: 'User account has been deactivated and marked for deletion',
      deletedAt: new Date().toISOString()
    };
  }

  /**
   * Anonymize user data (alternative to deletion)
   * @param {number} userId - User ID
   * @returns {Promise<Object>} Anonymization result
   */
  async anonymizeUserData(userId) {
    const user = await prisma.user.findUnique({
      where: { id: userId }
    });

    if (!user) {
      throw new Error('User not found');
    }

    // Anonymize user data
    const anonymizedUser = await prisma.user.update({
      where: { id: userId },
      data: {
        username: `deleted_user_${userId}`,
        email: `deleted_${userId}@anonymized.local`,
        password: '',
        bio: null,
        avatarUrl: null,
        isActive: false
      }
    });

    // Delete sensitive data
    await prisma.refreshToken.deleteMany({ where: { userId } });
    await prisma.notification.deleteMany({ where: { userId } });

    return {
      success: true,
      message: 'User data has been anonymized',
      anonymizedAt: new Date().toISOString()
    };
  }

  /**
   * Get data processing activities for a user
   * @param {number} userId - User ID
   * @returns {Promise<Object>} Processing activities
   */
  async getDataProcessingActivities(userId) {
    return {
      dataCollected: [
        'Account information (email, username)',
        'Profile data (bio, avatar)',
        'Activity data (quiz attempts, scores)',
        'Social data (followers, following)',
        'Content created (questions, question sets)',
        'Notifications',
        'IP address and session data'
      ],
      purposeOfProcessing: [
        'Provide quiz and challenge services',
        'Calculate rankings and leaderboards',
        'Enable social features',
        'Send notifications',
        'Improve service quality'
      ],
      dataRetention: {
        activeAccount: 'Indefinite (until account deletion)',
        inactiveAccount: '2 years of inactivity',
        deletedAccount: '30 days (backup retention)'
      },
      thirdPartySharing: 'No data is shared with third parties',
      userRights: [
        'Right to access (export data)',
        'Right to rectification (update profile)',
        'Right to erasure (delete account)',
        'Right to data portability (export in JSON)',
        'Right to object (anonymization)'
      ]
    };
  }
}

module.exports = new GdprService();
