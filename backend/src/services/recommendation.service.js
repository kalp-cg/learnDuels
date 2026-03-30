const prisma = require('../config/db');

/**
 * FOLLOW RECOMMENDATION ALGORITHM
 * 
 * Uses collaborative filtering with multiple signals:
 * 1. Mutual Connections (if you both follow X, you might like Y)
 * 2. Similar Interests (users playing similar topics)
 * 3. Similar Skill Level (users with similar XP/level)
 * 4. Activity Similarity (engagement patterns)
 * 
 * Scoring System:
 * - Mutual connections: 10 points per mutual
 * - Topic overlap: 5 points per shared topic
 * - Level proximity: 10 - |levelDiff| points
 * - Recent activity: 3 points if both active in last 7 days
 */

class RecommendationService {
  /**
   * Get personalized user recommendations
   * @param {number} userId - Current user ID
   * @param {number} limit - Max recommendations to return
   * @returns {Promise<Array>} Recommended users with scores
   */
  async getUserRecommendations(userId, limit = 10) {
    // Get current user's profile
    const currentUser = await prisma.user.findUnique({
      where: { id: userId },
      include: {
        following: { select: { followingId: true } },
        attempts: {
          select: { questionSetId: true },
          distinct: ['questionSetId']
        }
      }
    });

    if (!currentUser) {
      throw new Error('User not found');
    }

    const followingIds = currentUser.following.map(f => f.followingId);
    const alreadyFollowing = new Set([userId, ...followingIds]);

    // Get candidate users (exclude self and already following)
    const candidates = await prisma.user.findMany({
      where: {
        id: { notIn: Array.from(alreadyFollowing) },
        isActive: true
      },
      include: {
        followers: { select: { followerId: true } },
        attempts: {
          select: { questionSetId: true },
          distinct: ['questionSetId'],
          take: 20
        }
      },
      take: 100 // Limit candidates for performance
    });

    // Score each candidate
    const scoredCandidates = candidates.map(candidate => {
      let score = 0;
      const reasons = [];

      // 1. MUTUAL CONNECTIONS (strongest signal)
      const candidateFollowers = new Set(candidate.followers.map(f => f.followerId));
      const mutualConnections = followingIds.filter(id => candidateFollowers.has(id));
      if (mutualConnections.length > 0) {
        score += mutualConnections.length * 10;
        reasons.push(`${mutualConnections.length} mutual connection${mutualConnections.length > 1 ? 's' : ''}`);
      }

      // 2. TOPIC SIMILARITY (shared interests)
      const currentUserTopics = new Set(currentUser.attempts.map(a => a.questionSetId));
      const candidateTopics = new Set(candidate.attempts.map(a => a.questionSetId));
      const sharedTopics = [...currentUserTopics].filter(t => candidateTopics.has(t)).length;
      if (sharedTopics > 0) {
        score += sharedTopics * 5;
        reasons.push(`${sharedTopics} shared interest${sharedTopics > 1 ? 's' : ''}`);
      }

      // 3. SKILL LEVEL PROXIMITY
      const levelDiff = Math.abs(currentUser.level - candidate.level);
      const levelScore = Math.max(0, 10 - levelDiff);
      if (levelScore > 5) {
        score += levelScore;
        reasons.push('Similar skill level');
      }

      // 4. RECENT ACTIVITY
      const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
      const bothActive = currentUser.updatedAt > sevenDaysAgo && candidate.updatedAt > sevenDaysAgo;
      if (bothActive) {
        score += 3;
        reasons.push('Recently active');
      }

      // 5. HIGH REPUTATION BOOST
      if (candidate.reputation > 100) {
        score += 2;
        reasons.push('Top contributor');
      }

      // 6. MANY FOLLOWERS BOOST (popularity signal)
      if (candidate.followersCount > 10) {
        score += 1;
        reasons.push('Popular user');
      }

      return {
        id: candidate.id,
        username: candidate.username,
        email: candidate.email,
        avatarUrl: candidate.avatarUrl,
        bio: candidate.bio,
        level: candidate.level,
        xp: candidate.xp,
        reputation: candidate.reputation,
        followersCount: candidate.followersCount,
        followingCount: candidate.followingCount,
        score,
        reasons,
        mutualConnections: mutualConnections.length
      };
    });

    // Sort by score descending and return top N
    const recommendations = scoredCandidates
      .filter(c => c.score > 0) // Only return users with positive scores
      .sort((a, b) => b.score - a.score)
      .slice(0, limit);

    return recommendations;
  }

  /**
   * Get topic recommendations based on user's activity
   * @param {number} userId - User ID
   * @param {number} limit - Max topics to return
   * @returns {Promise<Array>} Recommended topics
   */
  async getTopicRecommendations(userId, limit = 5) {
    // Get user's completed attempts
    const userAttempts = await prisma.attempt.findMany({
      where: { userId },
      include: {
        questionSet: {
          include: {
            items: {
              include: {
                question: {
                  include: { topics: true }
                }
              }
            }
          }
        }
      }
    });

    // Extract topics user has engaged with
    const engagedTopicIds = new Set();
    userAttempts.forEach(attempt => {
      attempt.questionSet.items.forEach(item => {
        item.question.topics.forEach(topic => {
          engagedTopicIds.add(topic.id);
        });
      });
    });

    // Find similar users (collaborative filtering)
    const similarUsers = await this.getUserRecommendations(userId, 20);
    const similarUserIds = similarUsers.map(u => u.id);

    // Get topics popular among similar users
    const topicsFromSimilarUsers = await prisma.attempt.findMany({
      where: { userId: { in: similarUserIds } },
      include: {
        questionSet: {
          include: {
            items: {
              include: {
                question: {
                  include: { topics: true }
                }
              }
            }
          }
        }
      }
    });

    // Score topics
    const topicScores = new Map();
    topicsFromSimilarUsers.forEach(attempt => {
      attempt.questionSet.items.forEach(item => {
        item.question.topics.forEach(topic => {
          if (!engagedTopicIds.has(topic.id)) {
            const currentScore = topicScores.get(topic.id) || { topic, count: 0 };
            currentScore.count++;
            topicScores.set(topic.id, currentScore);
          }
        });
      });
    });

    // Convert to array and sort
    const recommendations = Array.from(topicScores.values())
      .sort((a, b) => b.count - a.count)
      .slice(0, limit)
      .map(({ topic }) => topic);

    return recommendations;
  }

  /**
   * Get question set recommendations
   * @param {number} userId - User ID
   * @param {number} limit - Max question sets
   * @returns {Promise<Array>} Recommended question sets
   */
  async getQuestionSetRecommendations(userId, limit = 10) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { level: true }
    });

    // Get user's completed sets
    const completedSetIds = await prisma.attempt.findMany({
      where: { userId },
      select: { questionSetId: true },
      distinct: ['questionSetId']
    }).then(attempts => attempts.map(a => a.questionSetId));

    // Find popular sets user hasn't done yet, matching their skill level
    const recommendations = await prisma.questionSet.findMany({
      where: {
        id: { notIn: completedSetIds },
        isPublic: true
      },
      include: {
        author: { select: { username: true, avatarUrl: true } },
        items: {
          include: {
            question: { select: { difficulty: true } }
          }
        },
        _count: { select: { attempts: true } }
      },
      take: limit * 2 // Get more to filter
    });

    // Score based on difficulty match and popularity
    const scoredSets = recommendations.map(set => {
      let score = 0;

      // Difficulty matching
      const avgDifficulty = set.items.reduce((sum, item) => {
        const diffValue = { easy: 1, medium: 2, hard: 3 }[item.question.difficulty] || 2;
        return sum + diffValue;
      }, 0) / set.items.length;

      const userDiffLevel = user.level < 5 ? 1 : user.level < 15 ? 2 : 3;
      const diffMatch = 1 - Math.abs(avgDifficulty - userDiffLevel) / 3;
      score += diffMatch * 50;

      // Popularity
      score += Math.min(set._count.attempts, 50);

      return { ...set, score };
    });

    return scoredSets
      .sort((a, b) => b.score - a.score)
      .slice(0, limit);
  }
}

module.exports = new RecommendationService();
