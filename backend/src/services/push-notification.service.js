const admin = require('firebase-admin');
const { prisma } = require('../config/db');

/**
 * PUSH NOTIFICATION SERVICE
 * 
 * Uses Firebase Cloud Messaging (FCM) for cross-platform push notifications
 * Supports iOS, Android, and Web
 */

class PushNotificationService {
  constructor() {
    this.initialized = false;
    this.initializeFirebase();
  }

  /**
   * Initialize Firebase Admin SDK
   */
  initializeFirebase() {
    try {
      // Initialize Firebase with service account
      if (process.env.FIREBASE_SERVICE_ACCOUNT) {
        const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
        admin.initializeApp({
          credential: admin.credential.cert(serviceAccount)
        });
        this.initialized = true;
        console.log('✅ Firebase Admin initialized for push notifications');
      } else {
        console.log('⚠️ Firebase not configured. Push notifications disabled.');
      }
    } catch (error) {
      console.error('❌ Firebase initialization failed:', error.message);
    }
  }

  /**
   * Register device token for a user
   * @param {number} userId - User ID
   * @param {string} token - FCM device token
   * @param {string} platform - Platform (ios/android/web)
   */
  async registerDeviceToken(userId, token, platform = 'web') {
    await prisma.$executeRaw`
      INSERT INTO device_tokens (user_id, token, platform, created_at)
      VALUES (${userId}, ${token}, ${platform}, CURRENT_TIMESTAMP)
      ON CONFLICT (token) 
      DO UPDATE SET 
        user_id = ${userId},
        platform = ${platform},
        updated_at = CURRENT_TIMESTAMP
    `;
  }

  /**
   * Remove device token
   * @param {string} token - FCM device token
   */
  async removeDeviceToken(token) {
    await prisma.$executeRaw`
      DELETE FROM device_tokens WHERE token = ${token}
    `;
  }

  /**
   * Get user's device tokens
   * @param {number} userId - User ID
   * @returns {Promise<Array>} Device tokens
   */
  async getUserTokens(userId) {
    const tokens = await prisma.$queryRaw`
      SELECT token, platform 
      FROM device_tokens 
      WHERE user_id = ${userId}
    `;
    return tokens;
  }

  /**
   * Send push notification to user
   * @param {number} userId - Target user ID
   * @param {Object} notification - Notification payload
   * @returns {Promise<Object>} Send result
   */
  async sendToUser(userId, notification) {
    if (!this.initialized) {
      console.log('Push notifications not enabled');
      return { success: false, reason: 'not_configured' };
    }

    const tokens = await this.getUserTokens(userId);
    if (tokens.length === 0) {
      return { success: false, reason: 'no_tokens' };
    }

    const deviceTokens = tokens.map(t => t.token);
    
    const message = {
      notification: {
        title: notification.title,
        body: notification.body,
        imageUrl: notification.imageUrl
      },
      data: notification.data || {},
      tokens: deviceTokens
    };

    try {
      const response = await admin.messaging().sendEachForMulticast(message);
      
      // Remove invalid tokens
      const failedTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          failedTokens.push(deviceTokens[idx]);
        }
      });

      if (failedTokens.length > 0) {
        await Promise.all(
          failedTokens.map(token => this.removeDeviceToken(token))
        );
      }

      return {
        success: true,
        successCount: response.successCount,
        failureCount: response.failureCount
      };
    } catch (error) {
      console.error('Push notification error:', error);
      return { success: false, error: error.message };
    }
  }

  /**
   * Send notification when challenge is received
   * @param {number} userId - Challenged user ID
   * @param {Object} challenger - Challenger user data
   * @param {number} challengeId - Challenge ID
   */
  async notifyChallenge(userId, challenger, challengeId) {
    await this.sendToUser(userId, {
      title: '⚔️ New Challenge!',
      body: `${challenger.username} challenged you to a duel!`,
      imageUrl: challenger.avatarUrl,
      data: {
        type: 'challenge',
        challengeId: String(challengeId),
        challengerId: String(challenger.id)
      }
    });
  }

  /**
   * Send notification when challenge is accepted
   * @param {number} userId - Challenger user ID
   * @param {Object} accepter - User who accepted
   * @param {number} challengeId - Challenge ID
   */
  async notifyChallengeAccepted(userId, accepter, challengeId) {
    await this.sendToUser(userId, {
      title: '✅ Challenge Accepted!',
      body: `${accepter.username} accepted your challenge!`,
      imageUrl: accepter.avatarUrl,
      data: {
        type: 'challenge_accepted',
        challengeId: String(challengeId),
        accepterId: String(accepter.id)
      }
    });
  }

  /**
   * Send notification when someone follows you
   * @param {number} userId - Followed user ID
   * @param {Object} follower - Follower user data
   */
  async notifyNewFollower(userId, follower) {
    await this.sendToUser(userId, {
      title: '👥 New Follower',
      body: `${follower.username} started following you!`,
      imageUrl: follower.avatarUrl,
      data: {
        type: 'new_follower',
        followerId: String(follower.id)
      }
    });
  }

  /**
   * Send notification for level up
   * @param {number} userId - User ID
   * @param {number} newLevel - New level achieved
   */
  async notifyLevelUp(userId, newLevel) {
    await this.sendToUser(userId, {
      title: '🎉 Level Up!',
      body: `Congratulations! You've reached level ${newLevel}!`,
      data: {
        type: 'level_up',
        level: String(newLevel)
      }
    });
  }

  /**
   * Send notification for leaderboard rank change
   * @param {number} userId - User ID
   * @param {number} newRank - New rank
   * @param {string} topicName - Topic name (optional)
   */
  async notifyRankChange(userId, newRank, topicName = null) {
    const message = topicName 
      ? `You're now #${newRank} in ${topicName}!`
      : `You're now #${newRank} on the global leaderboard!`;

    await this.sendToUser(userId, {
      title: '📊 Rank Update',
      body: message,
      data: {
        type: 'rank_change',
        rank: String(newRank),
        topic: topicName || 'global'
      }
    });
  }

  /**
   * Send notification when question is approved
   * @param {number} userId - Question author ID
   * @param {string} questionTitle - Question text
   */
  async notifyQuestionApproved(userId, questionTitle) {
    await this.sendToUser(userId, {
      title: '✅ Question Approved',
      body: `Your question "${questionTitle}" has been approved!`,
      data: {
        type: 'question_approved'
      }
    });
  }

  /**
   * Send batch notification to multiple users
   * @param {Array<number>} userIds - Target user IDs
   * @param {Object} notification - Notification payload
   */
  async sendToMultipleUsers(userIds, notification) {
    const results = await Promise.all(
      userIds.map(userId => this.sendToUser(userId, notification))
    );

    return {
      total: userIds.length,
      successful: results.filter(r => r.success).length,
      failed: results.filter(r => !r.success).length
    };
  }

  /**
   * Send topic-based broadcast
   * @param {string} topic - FCM topic name
   * @param {Object} notification - Notification payload
   */
  async sendToTopic(topic, notification) {
    if (!this.initialized) {
      return { success: false, reason: 'not_configured' };
    }

    const message = {
      notification: {
        title: notification.title,
        body: notification.body
      },
      data: notification.data || {},
      topic: topic
    };

    try {
      const messageId = await admin.messaging().send(message);
      return { success: true, messageId };
    } catch (error) {
      console.error('Topic notification error:', error);
      return { success: false, error: error.message };
    }
  }

  /**
   * Subscribe user to topic
   * @param {Array<string>} tokens - Device tokens
   * @param {string} topic - Topic name
   */
  async subscribeToTopic(tokens, topic) {
    if (!this.initialized) return;

    try {
      await admin.messaging().subscribeToTopic(tokens, topic);
    } catch (error) {
      console.error('Subscribe to topic error:', error);
    }
  }
}

// Create device_tokens table
async function initPushNotifications() {
  try {
    await prisma.$executeRaw`
      CREATE TABLE IF NOT EXISTS device_tokens (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL,
        token TEXT NOT NULL UNIQUE,
        platform VARCHAR(20) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `;
    await prisma.$executeRaw`
      CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON device_tokens(user_id)
    `;
    console.log('✅ Push notification tables initialized');
  } catch (error) {
    console.log('⚠️ Push notification tables may already exist');
  }
}

if (process.env.NODE_ENV !== 'test') {
  initPushNotifications();
}

module.exports = new PushNotificationService();
