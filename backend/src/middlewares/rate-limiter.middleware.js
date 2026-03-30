/**
 * Rate Limiting Middleware
 * Protects API from abuse and DDoS attacks
 */

const rateLimit = require('express-rate-limit');
const { getRedisClient } = require('../config/redis');

/**
 * Create rate limiter with or without Redis store
 * @param {Object} options - Rate limiter options
 * @returns {function} Express middleware
 */
function createRateLimiter(options) {
  const redisClient = getRedisClient();
  
  const config = {
    windowMs: options.windowMs || 15 * 60 * 1000, // 15 minutes default
    max: options.max || 100, // 100 requests per window
    message: options.message || {
      success: false,
      message: 'Too many requests from this IP, please try again later.',
      retryAfter: options.windowMs / 1000,
    },
    standardHeaders: true, // Return rate limit info in headers
    legacyHeaders: false, // Disable X-RateLimit-* headers
    handler: (req, res) => {
      res.status(429).json({
        success: false,
        message: 'Too many requests, please try again later.',
        retryAfter: Math.ceil(req.rateLimit.resetTime / 1000),
      });
    },
    ...options,
  };

  // Use Redis store if available
  if (redisClient && redisClient.status === 'ready') {
    try {
      const RedisStore = require('rate-limit-redis');
      config.store = new RedisStore({
        client: redisClient,
        prefix: options.prefix || 'rl:',
      });
      console.log('✅ Rate limiting using Redis store');
    } catch (error) {
      console.log('⚠️  Redis store not available, using memory store');
    }
  }

  return rateLimit(config);
}

/**
 * General API rate limiter
 * 100 requests per 15 minutes
 */
const apiLimiter = createRateLimiter({
  windowMs: 15 * 60 * 1000,
  max: 100,
  prefix: 'rl:api:',
  message: {
    success: false,
    message: 'Too many API requests, please slow down.',
  },
});

/**
 * Strict rate limiter for authentication endpoints
 * 5 requests per 15 minutes
 */
const authLimiter = createRateLimiter({
  windowMs: 15 * 60 * 1000,
  max: 5,
  prefix: 'rl:auth:',
  message: {
    success: false,
    message: 'Too many login attempts, please try again later.',
  },
  skipSuccessfulRequests: true, // Don't count successful logins
});

/**
 * Moderate rate limiter for write operations
 * 50 requests per 15 minutes
 */
const writeLimiter = createRateLimiter({
  windowMs: 15 * 60 * 1000,
  max: 50,
  prefix: 'rl:write:',
  message: {
    success: false,
    message: 'Too many write requests, please slow down.',
  },
});

/**
 * Lenient rate limiter for read operations
 * 200 requests per 15 minutes
 */
const readLimiter = createRateLimiter({
  windowMs: 15 * 60 * 1000,
  max: 200,
  prefix: 'rl:read:',
  message: {
    success: false,
    message: 'Too many read requests, please slow down.',
  },
});

/**
 * Very strict rate limiter for password reset/sensitive operations
 * 3 requests per hour
 */
const sensitiveLimiter = createRateLimiter({
  windowMs: 60 * 60 * 1000,
  max: 3,
  prefix: 'rl:sensitive:',
  message: {
    success: false,
    message: 'Too many attempts for this sensitive operation. Please try again later.',
  },
});

/**
 * Rate limiter for question creation
 * 20 questions per hour
 */
const questionCreateLimiter = createRateLimiter({
  windowMs: 60 * 60 * 1000, 
  max: 20,
  prefix: 'rl:question:create:',
  message: {
    success: false,
    message: 'You can only create 20 questions per hour. Please try again later.',
  },
});

/**
 * Rate limiter for duel creation
 * 10 duels per hour
 */
const duelCreateLimiter = createRateLimiter({
  windowMs: 60 * 60 * 1000,
  max: 10,
  prefix: 'rl:duel:create:',
  message: {
    success: false,
    message: 'You can only create 10 duels per hour. Please try again later.',
  },
});

module.exports = {
  createRateLimiter,
  apiLimiter,
  authLimiter,
  writeLimiter,
  readLimiter,
  sensitiveLimiter,
  questionCreateLimiter,
  duelCreateLimiter,
};
