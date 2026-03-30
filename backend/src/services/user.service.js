/**
 * User Service
 * Handles user profile and social features
 */

const { prisma } = require('../config/db');
const { createError } = require('../middlewares/error.middleware');
const feedService = require('./feed.service');
const { uploadImage, deleteImage, extractPublicId } = require('../config/cloudinary');

/**
 * Get all users (with pagination and search)
 */
async function getAllUsers(currentUserId, { page = 1, limit = 20, search = '', sortBy = 'newest' }) {
  try {
    // Cap limit at 5000 to prevent excessive queries
    const cappedLimit = Math.min(parseInt(limit) || 20, 5000);
    const skip = (page - 1) * cappedLimit;
    const where = {};

    if (search) {
      where.OR = [
        { username: { contains: search, mode: 'insensitive' } },
        { fullName: { contains: search, mode: 'insensitive' } },
      ];
    }

    // Exclude current user
    if (currentUserId) {
      where.id = { not: parseInt(currentUserId) };
    }

    let orderBy = { createdAt: 'desc' };
    if (sortBy === 'rating') {
      orderBy = { rating: 'desc' };
    } else if (sortBy === 'xp') {
      orderBy = { xp: 'desc' };
    }

    const [users, total] = await Promise.all([
      prisma.user.findMany({
        where,
        skip,
        take: cappedLimit,
        orderBy,
        select: {
          id: true,
          username: true,
          fullName: true,
          avatarUrl: true,
          level: true,
          rating: true,
          createdAt: true,
          _count: {
            select: {
              followers: true,
            }
          }
        },
      }),
      prisma.user.count({ where }),
    ]);

    // Check following status for each user
    const usersWithStatus = await Promise.all(users.map(async (user) => {
      const follow = await prisma.userFollower.findUnique({
        where: {
          followerId_followingId: {
            followerId: parseInt(currentUserId),
            followingId: user.id,
          },
        },
      });
      
      // Debug log for specific user check
      // if (user.username === 'some_username') console.log(...) 

      return {
        ...user,
        isFollowing: follow?.status === 'accepted',
        followStatus: follow?.status || null,
      };
    }));

    // console.log(`Returning ${usersWithStatus.length} users for ${currentUserId}`);

    return {
      users: usersWithStatus,
      pagination: {
        page,
        limit: cappedLimit,
        total,
        pages: Math.ceil(total / cappedLimit),
      },
    };
  } catch (error) {
    console.error('Get all users error:', error);
    throw createError.internal('Failed to fetch users');
  }
}

/**
 * Get user profile by ID
 */
async function getUserProfile(userId, currentUserId = null) {
  try {
    // Update streak before fetching profile
    await updateStreak(userId);

    const user = await prisma.user.findUnique({
      where: { id: parseInt(userId) },
      select: {
        id: true,
        username: true,
        fullName: true,
        email: true,
        avatarUrl: true,
        bio: true,
        role: true,
        rating: true,
        xp: true,
        level: true,
        reputation: true,
        createdAt: true,
        currentStreak: true,
        longestStreak: true,
        _count: {
          select: {
            followers: true,
            following: true,
            questions: true,
          },
        },
      },
    });

    if (!user) {
      throw createError.notFound('User not found');
    }

    let isFollowing = false;
    let followStatus = null;
    if (currentUserId && parseInt(currentUserId) !== parseInt(userId)) {
      const follow = await prisma.userFollower.findUnique({
        where: {
          followerId_followingId: {
            followerId: parseInt(currentUserId),
            followingId: parseInt(userId),
          },
        },
      });
      if (follow) {
        isFollowing = follow.status === 'accepted';
        followStatus = follow.status; // pending, accepted, or declined
      }
    }

    return {
      ...user,
      isFollowing,
      followStatus,
    };
  } catch (error) {
    if (error.isOperational) throw error;
    throw createError.internal('Failed to fetch user profile');
  }
}

/**
 * Update user streak
 */
async function updateStreak(userId) {
  try {
    const user = await prisma.user.findUnique({
      where: { id: parseInt(userId) },
      select: { lastLoginAt: true, currentStreak: true, longestStreak: true },
    });

    if (!user) return;

    const now = new Date();
    const lastLogin = user.lastLoginAt ? new Date(user.lastLoginAt) : null;

    let newCurrentStreak = user.currentStreak;
    let newLongestStreak = user.longestStreak;

    if (!lastLogin) {
      // First login ever
      newCurrentStreak = 1;
      newLongestStreak = 1;
    } else {
      // Calculate difference in days
      // Reset time to midnight for accurate day comparison
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const lastDate = new Date(lastLogin.getFullYear(), lastLogin.getMonth(), lastLogin.getDate());

      const diffTime = Math.abs(today - lastDate);
      const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

      if (diffDays === 1) {
        // Consecutive day
        newCurrentStreak += 1;
        if (newCurrentStreak > newLongestStreak) {
          newLongestStreak = newCurrentStreak;
        }
      } else if (diffDays > 1) {
        // Missed a day (or more)
        newCurrentStreak = 1;
      }
      // If diffDays === 0 (same day), do nothing to streak
    }

    await prisma.user.update({
      where: { id: parseInt(userId) },
      data: {
        lastLoginAt: now,
        currentStreak: newCurrentStreak,
        longestStreak: newLongestStreak,
      },
    });
  } catch (error) {
    console.error('Failed to update streak:', error);
    // Don't throw, just log. Streak update shouldn't block profile fetch.
  }
}

/**
 * Update user profile
 */
async function updateProfile(userId, updateData) {
  try {
    const { fullName, avatarUrl, bio } = updateData;

    const updateFields = {};
    if (fullName !== undefined) updateFields.fullName = fullName;
    if (avatarUrl !== undefined) updateFields.avatarUrl = avatarUrl;
    if (bio !== undefined) updateFields.bio = bio;

    const user = await prisma.user.update({
      where: { id: parseInt(userId) },
      data: updateFields,
      select: {
        id: true,
        fullName: true,
        email: true,
        avatarUrl: true,
        bio: true,
        role: true,
        rating: true,
      },
    });

    return user;
  } catch (error) {
    if (error.isOperational) throw error;
    throw createError.internal('Failed to update profile');
  }
}

/**
 * Follow a user (Send follow request)
 */
async function followUser(followerId, followingId) {
  try {
    console.log(`👥 User ${followerId} attempting to follow user ${followingId}`);
    
    if (parseInt(followerId) === parseInt(followingId)) {
      throw createError.badRequest('Cannot follow yourself');
    }

    // Check if the user to follow exists
    const userToFollow = await prisma.user.findUnique({
      where: { id: parseInt(followingId) },
      select: { id: true, fullName: true, email: true },
    });

    if (!userToFollow) {
      throw createError.notFound('User to follow not found');
    }

    const existing = await prisma.userFollower.findFirst({
      where: {
        followerId: parseInt(followerId),
        followingId: parseInt(followingId),
      },
    });

    if (existing) {
      console.log(`⚠️  Existing follow relationship found: status=${existing.status}`);
      if (existing.status === 'pending') {
        throw createError.conflict('Follow request already sent');
      } else if (existing.status === 'accepted') {
        throw createError.conflict('Already following this user');
      } else if (existing.status === 'declined') {
        // Allow resending after decline
        await prisma.userFollower.update({
          where: { id: existing.id },
          data: { status: 'pending', createdAt: new Date() },
        });
        
        console.log(`✅ Follow request resent (was declined)`);
        // Send notification
        await sendFollowRequestNotification(followerId, followingId, userToFollow);
        return { success: true, message: 'Follow request sent' };
      }
    }

    // Create pending follow request
    const followRequest = await prisma.userFollower.create({
      data: {
        followerId: parseInt(followerId),
        followingId: parseInt(followingId),
        status: 'pending',
      },
    });

    console.log(`✅ Follow request created successfully:`, {
      id: followRequest.id,
      follower: followerId,
      following: followingId,
      status: followRequest.status
    });

    // Send notification to the user being followed
    await sendFollowRequestNotification(followerId, followingId, userToFollow);

    return { success: true, message: 'Follow request sent' };
  } catch (error) {
    if (error.isOperational) throw error;
    console.error('❌ Follow user error:', error);
    throw createError.internal('Failed to send follow request');
  }
}

/**
 * Send follow request notification
 */
async function sendFollowRequestNotification(followerId, followingId, userToFollow) {
  try {
    const follower = await prisma.user.findUnique({
      where: { id: parseInt(followerId) },
      select: { fullName: true, email: true },
    });

    // Create notification
    await prisma.notification.create({
      data: {
        userId: parseInt(followingId),
        type: 'follow_request',
        message: `${follower?.fullName || 'Someone'} sent you a follow request`,
        data: {
          followerId: parseInt(followerId),
          followerName: follower?.fullName,
          followerEmail: follower?.email,
        },
      },
    });

    // Send real-time notification via socket
    try {
      const { getIO, sendToUser } = require('../sockets/index');
      const io = getIO();
      sendToUser(io, followingId, 'notification', {
        type: 'follow_request',
        message: `${follower?.fullName || 'Someone'} sent you a follow request`,
        followerId: parseInt(followerId),
      });
    } catch (socketError) {
      console.error('Failed to send socket notification:', socketError);
    }
  } catch (error) {
    console.error('Failed to send follow request notification:', error);
  }
}

/**
 * Accept follow request
 */
async function acceptFollowRequest(userId, followerId) {
  try {
    const followRequest = await prisma.userFollower.findFirst({
      where: {
        followerId: parseInt(followerId),
        followingId: parseInt(userId),
        status: 'pending',
      },
    });

    if (!followRequest) {
      throw createError.notFound('Follow request not found');
    }

    // Update status to accepted
    const updated = await prisma.userFollower.update({
      where: { id: followRequest.id },
      data: { status: 'accepted' },
    });

    // Make friendship mutual (bidirectional)
    try {
      // Check if reverse relationship exists (User -> Follower)
      const reverseFollow = await prisma.userFollower.findUnique({
        where: {
          followerId_followingId: {
            followerId: parseInt(userId),
            followingId: parseInt(followerId)
          }
        }
      });

      if (reverseFollow) {
        // If it exists (even if pending/declined), update to accepted so both are friends
        if (reverseFollow.status !== 'accepted') {
          await prisma.userFollower.update({
            where: { id: reverseFollow.id },
            data: { status: 'accepted' }
          });
          console.log(`✅ Mutual friendship established (updated reverse relation)`);
        }
      } else {
        // Create new accepted relationship so user automatically follows back
        await prisma.userFollower.create({
          data: {
            followerId: parseInt(userId),
            followingId: parseInt(followerId),
            status: 'accepted'
          }
        });
        console.log(`✅ Mutual friendship established (created reverse relation)`);
      }
    } catch (reverseError) {
      console.error('Error establishing mutual friendship:', reverseError);
      // Don't fail the request if reverse update fails, just log it
    }
    
    console.log(`✅ Follow request accepted: ${updated.id}, status: ${updated.status}`);

    // Create notification for follower
    const acceptedBy = await prisma.user.findUnique({
      where: { id: parseInt(userId) },
      select: { fullName: true },
    });

    await prisma.notification.create({
      data: {
        userId: parseInt(followerId),
        type: 'follow_accepted',
        message: `${acceptedBy?.fullName || 'User'} accepted your follow request`,
        data: { userId: parseInt(userId) },
      },
    });

    // Send real-time notification
    try {
      const { getIO, sendToUser } = require('../sockets/index');
      const io = getIO();
      sendToUser(io, followerId, 'notification', {
        type: 'follow_accepted',
        message: `${acceptedBy?.fullName || 'User'} accepted your follow request`,
        userId: parseInt(userId),
      });
    } catch (socketError) {
      console.error('Failed to send socket notification:', socketError);
    }

    return { success: true, message: 'Follow request accepted' };
  } catch (error) {
    if (error.isOperational) throw error;
    console.error('Accept follow request error:', error);
    throw createError.internal('Failed to accept follow request');
  }
}

/**
 * Decline follow request
 */
async function declineFollowRequest(userId, followerId) {
  try {
    const followRequest = await prisma.userFollower.findFirst({
      where: {
        followerId: parseInt(followerId),
        followingId: parseInt(userId),
        status: 'pending',
      },
    });

    if (!followRequest) {
      throw createError.notFound('Follow request not found');
    }

    // Update status to declined (or delete)
    await prisma.userFollower.update({
      where: { id: followRequest.id },
      data: { status: 'declined' },
    });

    // Send real-time notification
    try {
      const { getIO, sendToUser } = require('../sockets/index');
      const io = getIO();
      sendToUser(io, followerId, 'notification', {
        type: 'follow_declined',
        message: 'Follow request declined',
        userId: parseInt(userId),
      });
    } catch (socketError) {
      console.error('Failed to send socket notification:', socketError);
    }

    return { success: true, message: 'Follow request declined' };
  } catch (error) {
    if (error.isOperational) throw error;
    console.error('Decline follow request error:', error);
    throw createError.internal('Failed to decline follow request');
  }
}

/**
 * Get pending follow requests
 */
async function getPendingFollowRequests(userId, options = {}) {
  const { page = 1, limit = 20 } = options;
  const skip = (page - 1) * limit;

  try {
    console.log(`📥 Getting pending follow requests for user ${userId}`);
    
    const [requests, totalCount] = await Promise.all([
      prisma.userFollower.findMany({
        where: {
          followingId: parseInt(userId),
          status: 'pending',
        },
        include: {
          follower: {
            select: {
              id: true,
              fullName: true,
              email: true,
              avatarUrl: true,
              rating: true,
            },
          },
        },
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      prisma.userFollower.count({
        where: {
          followingId: parseInt(userId),
          status: 'pending',
        },
      }),
    ]);

    console.log(`✅ Found ${requests.length} pending follow requests for user ${userId}`);
    console.log(`Request data:`, requests.map(r => ({ id: r.id, follower: r.follower.fullName, status: r.status })));

    return {
      requests: requests.map((r) => r.follower),
      pagination: {
        total: totalCount,
        page,
        limit,
        totalPages: Math.ceil(totalCount / limit),
      },
    };
  } catch (error) {
    console.error('Get pending follow requests error:', error);
    throw createError.internal('Failed to fetch follow requests');
  }
}

/**
 * Unfollow a user or cancel follow request
 */
async function unfollowUser(followerId, followingId) {
  try {
    const deleted = await prisma.userFollower.deleteMany({
      where: {
        followerId: parseInt(followerId),
        followingId: parseInt(followingId),
      },
    });

    if (deleted.count === 0) {
      throw createError.notFound('Follow relationship not found');
    }

    return { success: true, message: 'Unfollowed successfully' };
  } catch (error) {
    if (error.isOperational) throw error;
    throw createError.internal('Failed to unfollow user');
  }
}

/**
 * Get follow status between two users
 */
async function getFollowStatus(requestingUserId, targetUserId) {
  try {
    const followRelation = await prisma.userFollower.findFirst({
      where: {
        followerId: parseInt(requestingUserId),
        followingId: parseInt(targetUserId),
      },
    });

    if (!followRelation) {
      return { status: 'not_following', isFollowing: false, isPending: false };
    }

    if (followRelation.status === 'accepted') {
      return { status: 'following', isFollowing: true, isPending: false };
    }

    if (followRelation.status === 'pending') {
      return { status: 'pending', isFollowing: false, isPending: true };
    }

    return { status: 'not_following', isFollowing: false, isPending: false };
  } catch (error) {
    console.error('Get follow status error:', error);
    throw createError.internal('Failed to get follow status');
  }
}

/**
 * Get user's followers (only accepted)
 */
async function getFollowers(userId, options = {}) {
  const { page = 1, limit = 20 } = options;
  const skip = (page - 1) * limit;

  try {
    const [followers, totalCount] = await Promise.all([
      prisma.userFollower.findMany({
        where: {
          followingId: parseInt(userId),
          status: 'accepted',
        },
        include: {
          follower: {
            select: {
              id: true,
              fullName: true,
              avatarUrl: true,
              rating: true,
            },
          },
        },
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      prisma.userFollower.count({
        where: {
          followingId: parseInt(userId),
          status: 'accepted',
        },
      }),
    ]);

    return {
      followers: followers.map((f) => f.follower),
      pagination: {
        total: totalCount,
        page,
        limit,
        totalPages: Math.ceil(totalCount / limit),
      },
    };
  } catch (error) {
    throw createError.internal('Failed to fetch followers');
  }
}

/**
 * Get users that user is following (only accepted)
 */
async function getFollowing(userId, options = {}) {
  const { page = 1, limit = 20 } = options;
  const skip = (page - 1) * limit;

  try {
    const [following, totalCount] = await Promise.all([
      prisma.userFollower.findMany({
        where: {
          followerId: parseInt(userId),
          status: 'accepted',
        },
        include: {
          following: {
            select: {
              id: true,
              fullName: true,
              avatarUrl: true,
              rating: true,
            },
          },
        },
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      prisma.userFollower.count({
        where: {
          followerId: parseInt(userId),
          status: 'accepted',
        },
      }),
    ]);

    return {
      following: following.map((f) => f.following),
      pagination: {
        total: totalCount,
        page,
        limit,
        totalPages: Math.ceil(totalCount / limit),
      },
    };
  } catch (error) {
    throw createError.internal('Failed to fetch following');
  }
}

/**
 * Search users by query
 */
async function searchUsers(query, options = {}) {
  const { page = 1, limit = 20 } = options;
  const skip = (page - 1) * limit;

  try {
    const where = {
      OR: [
        {
          fullName: {
            contains: query,
            mode: 'insensitive',
          },
        },
        {
          email: {
            contains: query,
            mode: 'insensitive',
          },
        },
      ],
    };

    const [users, totalCount] = await Promise.all([
      prisma.user.findMany({
        where,
        select: {
          id: true,
          fullName: true,
          email: true,
          avatarUrl: true,
          role: true,
          rating: true,
          createdAt: true,
          _count: {
            select: {
              followers: true,
              following: true,
            },
          },
        },
        skip,
        take: limit,
        orderBy: {
          rating: 'desc',
        },
      }),
      prisma.user.count({ where }),
    ]);

    return {
      users,
      pagination: {
        total: totalCount,
        page,
        limit,
        totalPages: Math.ceil(totalCount / limit),
      },
    };
  } catch (error) {
    throw createError.internal('User search failed');
  }
}

/**
 * Add XP to user and handle leveling up
 */
async function addXp(userId, amount) {
  try {
    const user = await prisma.user.findUnique({
      where: { id: parseInt(userId) },
      select: { id: true, xp: true, level: true }
    });

    if (!user) return;

    const newXp = user.xp + amount;
    // Simple level formula: 1000 XP per level
    const newLevel = Math.floor(newXp / 1000) + 1;

    const updateData = {
      xp: newXp
    };

    if (newLevel > user.level) {
      updateData.level = newLevel;

      // Create Level Up Activity
      try {
        await feedService.createActivity(userId, 'LEVEL_UP', {
          oldLevel: user.level,
          newLevel: newLevel
        });
      } catch (e) {
        console.error('Feed error', e);
      }
    }

    await prisma.user.update({
      where: { id: parseInt(userId) },
      data: updateData
    });

    return { newXp, newLevel, leveledUp: newLevel > user.level };
  } catch (error) {
    console.error('Add XP error:', error);
  }
}

/**
 * Upload user avatar to Cloudinary
 */
async function uploadAvatar(userId, file) {
  try {
    console.log('Uploading avatar for user:', userId);
    console.log('File details:', {
      fieldname: file.fieldname,
      originalname: file.originalname,
      mimetype: file.mimetype,
      size: file.size,
      hasBuffer: !!file.buffer
    });

    if (!file.buffer) {
      throw new Error('File buffer is missing. Make sure multer is configured with memoryStorage.');
    }

    // Get current user to check for existing avatar
    const user = await prisma.user.findUnique({
      where: { id: parseInt(userId) },
      select: { avatarUrl: true },
    });

    // Delete old avatar from Cloudinary if exists
    if (user.avatarUrl) {
      const publicId = extractPublicId(user.avatarUrl);
      if (publicId) {
        try {
          await deleteImage(publicId);
          console.log('Deleted old avatar:', publicId);
        } catch (err) {
          console.error('Error deleting old avatar:', err);
        }
      }
    }

    // Upload new avatar
    console.log('Uploading to Cloudinary...');
    const result = await uploadImage(file.buffer, 'avatars', `user_${userId}`);
    console.log('Upload successful:', result.secure_url);

    // Update user in database
    await prisma.user.update({
      where: { id: parseInt(userId) },
      data: { avatarUrl: result.secure_url },
    });

    return result.secure_url;
  } catch (error) {
    console.error('Upload avatar error:', error);
    throw createError.internal('Failed to upload avatar');
  }
}

/**
 * Delete user avatar
 */
async function deleteAvatar(userId) {
  try {
    const user = await prisma.user.findUnique({
      where: { id: parseInt(userId) },
      select: { avatarUrl: true },
    });

    if (user.avatarUrl) {
      const publicId = extractPublicId(user.avatarUrl);
      if (publicId) {
        await deleteImage(publicId);
      }
    }

    await prisma.user.update({
      where: { id: parseInt(userId) },
      data: { avatarUrl: null },
    });
  } catch (error) {
    console.error('Delete avatar error:', error);
    throw createError.internal('Failed to delete avatar');
  }
}

/**
 * Update user profile (including avatar upload)
 */
async function updateUserProfile(userId, data) {
  try {
    const { fullName, bio, username, avatarUrl, avatarFile } = data;
    const updateFields = {};

    if (fullName !== undefined) updateFields.fullName = fullName;
    if (bio !== undefined) updateFields.bio = bio;
    if (username !== undefined) {
      // Check if username is already taken
      const existing = await prisma.user.findFirst({
        where: {
          username,
          id: { not: parseInt(userId) },
        },
      });
      if (existing) {
        throw createError.badRequest('Username already taken');
      }
      updateFields.username = username;
    }

    // Handle avatar upload if file provided
    if (avatarFile) {
      const uploadedAvatarUrl = await uploadAvatar(userId, avatarFile);
      updateFields.avatarUrl = uploadedAvatarUrl;
    } else if (avatarUrl !== undefined) {
      // Support direct URL updates (from Cloudinary or external URLs)
      updateFields.avatarUrl = avatarUrl;
    }

    const user = await prisma.user.update({
      where: { id: parseInt(userId) },
      data: updateFields,
      select: {
        id: true,
        username: true,
        fullName: true,
        email: true,
        avatarUrl: true,
        bio: true,
        role: true,
        rating: true,
        level: true,
        xp: true,
      },
    });

    return user;
  } catch (error) {
    if (error.isOperational) throw error;
    console.error('Update profile error:', error);
    throw createError.internal('Failed to update profile');
  }
}

module.exports = {
  getUserProfile,
  updateProfile,
  followUser,
  unfollowUser,
  acceptFollowRequest,
  declineFollowRequest,
  getPendingFollowRequests,
  getFollowStatus,
  getFollowers,
  getFollowing,
  searchUsers,
  getAllUsers,
  addXp,
  uploadAvatar,
  deleteAvatar,
  updateUserProfile,
};
