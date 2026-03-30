/**
 * Authentication Middleware
 * JWT token validation and user authentication
 */

const { verifyAccessToken } = require('../utils/token');
const { prisma } = require('../config/db');
const { unauthorizedResponse, errorResponse } = require('../utils/response');

/**
 * Authenticate user using JWT token
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next function
 */
async function authenticateToken(req, res, next) {
  try {
    // Get token from Authorization header
    const authHeader = req.headers.authorization;
    const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

    if (!token) {
      return unauthorizedResponse(res, 'Access token required');
    }

    // Verify token
    const payload = verifyAccessToken(token);
    if (!payload) {
      console.error(`DEBUG: Auth failed for token: ${token.substring(0, 10)}...`);
      return unauthorizedResponse(res, 'Invalid or expired access token');
    }

    // Get user from database
    const user = await prisma.user.findUnique({
      where: { id: payload.userId },
      select: {
        id: true,
        isActive: true,
        username: true,
        fullName: true,
        email: true,
        role: true,
        xp: true,
        level: true,
        reputation: true,
        rating: true,
        avatarUrl: true,
        bio: true,
        currentStreak: true,
        longestStreak: true,
        questionsSolved: true,
        quizzesCompleted: true,
        followersCount: true,
        followingCount: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    if (!user) {
      return unauthorizedResponse(res, 'User not found');
    }

    if (!user.isActive) {
      return unauthorizedResponse(res, 'Account is deactivated');
    }

    // Add user to request object
    req.user = user;
    req.userId = user.id;

    next();
  } catch (error) {
    console.error('Authentication error:', error);
    return errorResponse(res, 'Authentication failed', 500);
  }
}

/**
 * Optional authentication middleware
 * Authenticates user if token is provided, but doesn't require it
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next function
 */
async function optionalAuth(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    const token = authHeader && authHeader.split(' ')[1];

    if (token) {
      const payload = verifyAccessToken(token);

      if (payload) {
        const user = await prisma.user.findUnique({
          where: { id: payload.userId },
          select: {
            id: true,
            username: true,
            email: true,
            role: true,
            xp: true,
            level: true,
            createdAt: true,
            updatedAt: true,
          },
        });

        if (user) {
          req.user = user;
          req.userId = user.id;
        }
      }
    }

    next();
  } catch (error) {
    // Don't fail on optional auth errors
    console.error('Optional authentication error:', error);
    next();
  }
}

/**
 * Check if user owns a resource
 * @param {string} resourceUserId - User ID of the resource owner
 * @param {string} currentUserId - Current user's ID
 * @returns {boolean} True if user owns the resource
 */
function checkResourceOwnership(resourceUserId, currentUserId) {
  return resourceUserId === currentUserId;
}

/**
 * Middleware to check resource ownership
 * @param {string} resourceField - Field name containing the user ID
 * @returns {Function} Middleware function
 */
function requireOwnership(resourceField = 'authorId') {
  return async (req, res, next) => {
    try {
      const resourceId = req.params.id;
      const userId = req.userId;

      if (!resourceId) {
        return errorResponse(res, 'Resource ID required', 400);
      }

      // This is a generic ownership check
      // In practice, you'd check specific resources
      // For now, just proceed to the controller
      next();
    } catch (error) {
      console.error('Ownership check error:', error);
      return errorResponse(res, 'Ownership verification failed', 500);
    }
  };
}

/**
 * Rate limiting middleware for authentication attempts
 * @param {number} maxAttempts - Maximum attempts allowed
 * @param {number} windowMs - Time window in milliseconds
 * @returns {Function} Middleware function
 */
function authRateLimit(maxAttempts = 5, windowMs = 15 * 60 * 1000) {
  const attempts = new Map();

  return (req, res, next) => {
    const clientIp = req.ip || req.connection.remoteAddress;
    const now = Date.now();

    // Clean old entries
    for (const [ip, data] of attempts.entries()) {
      if (now - data.firstAttempt > windowMs) {
        attempts.delete(ip);
      }
    }

    // Check current attempts
    const clientAttempts = attempts.get(clientIp);

    if (clientAttempts) {
      if (clientAttempts.count >= maxAttempts) {
        const timeLeft = Math.ceil((clientAttempts.firstAttempt + windowMs - now) / 1000);
        return errorResponse(
          res,
          `Too many authentication attempts. Try again in ${timeLeft} seconds.`,
          429
        );
      }

      clientAttempts.count++;
    } else {
      attempts.set(clientIp, {
        count: 1,
        firstAttempt: now,
      });
    }

    next();
  };
}

/**
 * Middleware to extract user ID from token without full authentication
 * Useful for optional features that work better with user context
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next function
 */
function extractUserId(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    const token = authHeader && authHeader.split(' ')[1];

    if (token) {
      const payload = verifyAccessToken(token);
      if (payload && payload.userId) {
        req.userId = payload.userId;
      }
    }

    next();
  } catch (error) {
    // Don't fail, just proceed without user ID
    next();
  }
}

/**
 * Require admin role middleware
 * Must be used after authenticateToken
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next function
 */
async function requireAdmin(req, res, next) {
  try {
    if (!req.user) {
      return unauthorizedResponse(res, 'Authentication required');
    }

    if (req.user.role !== 'admin') {
      return errorResponse(res, 'Admin access required', 403);
    }

    next();
  } catch (error) {
    console.error('Admin check error:', error);
    return errorResponse(res, 'Authorization check failed', 500);
  }
}

module.exports = {
  authenticateToken,
  authenticate: authenticateToken, // Alias for convenience
  optionalAuth,
  checkResourceOwnership,
  requireOwnership,
  authRateLimit,
  extractUserId,
  requireAdmin,
};