/**
 * Caching Middleware
 * Handles automatic caching for GET requests
 */

const { getCache, setCache } = require('../config/redis');

/**
 * Cache middleware factory
 * @param {number} ttl - Time to live in seconds (default: 300 = 5 minutes)
 * @param {function} keyGenerator - Function to generate cache key from req
 * @returns {function} Express middleware
 */
function cacheMiddleware(ttl = 300, keyGenerator = null) {
  return async (req, res, next) => {
    // Only cache GET requests
    if (req.method !== 'GET') {
      return next();
    }

    try {
      // Generate cache key
      const cacheKey = keyGenerator 
        ? keyGenerator(req) 
        : `cache:${req.originalUrl || req.url}`;

      // Try to get from cache
      const cachedData = await getCache(cacheKey);

      if (cachedData) {
        console.log(`✅ Cache HIT: ${cacheKey}`);
        return res.status(200).json({
          ...cachedData,
          cached: true,
          cacheKey,
        });
      }

      console.log(`❌ Cache MISS: ${cacheKey}`);

      // Store original json method
      const originalJson = res.json.bind(res);

      // Override json method to cache response
      res.json = function (data) {
        // Only cache successful responses
        if (res.statusCode === 200 && data.success !== false) {
          setCache(cacheKey, data, ttl).catch(err => {
            console.error('Failed to cache response:', err);
          });
        }
        return originalJson(data);
      };

      next();
    } catch (error) {
      console.error('Cache middleware error:', error);
      next(); // Continue without caching on error
    }
  };
}

/**
 * Cache key generators for different routes
 */
const cacheKeys = {
  /**
   * Generate cache key for leaderboard
   */
  leaderboard: (req) => {
    const { page = 1, limit = 20 } = req.query;
    return `leaderboard:global:${page}:${limit}`;
  },

  /**
   * Generate cache key for user profile
   */
  userProfile: (req) => {
    const userId = req.params.id || req.userId;
    return `user:profile:${userId}`;
  },

  /**
   * Generate cache key for categories
   */
  categories: () => {
    return 'categories:all';
  },

  /**
   * Generate cache key for difficulties
   */
  difficulties: () => {
    return 'difficulties:all';
  },

  /**
   * Generate cache key for questions list
   */
  questions: (req) => {
    const { page = 1, limit = 20, categoryId, difficultyId } = req.query;
    return `questions:list:${page}:${limit}:${categoryId || 'all'}:${difficultyId || 'all'}`;
  },

  /**
   * Generate cache key for question by ID
   */
  question: (req) => {
    const questionId = req.params.id;
    return `question:${questionId}`;
  },

  /**
   * Generate cache key for user's duels
   */
  userDuels: (req) => {
    const { status, page = 1, limit = 20 } = req.query;
    return `duels:user:${req.userId}:${status || 'all'}:${page}:${limit}`;
  },

  /**
   * Generate cache key for duel by ID
   */
  duel: (req) => {
    const duelId = req.params.id;
    return `duel:${duelId}`;
  },
};

/**
 * Pre-configured cache middlewares with common TTLs
 */
const cacheStrategies = {
  /**
   * Short cache (2 minutes) - for frequently changing data
   */
  short: cacheMiddleware(120),

  /**
   * Medium cache (5 minutes) - for standard data
   */
  medium: cacheMiddleware(300),

  /**
   * Long cache (30 minutes) - for rarely changing data
   */
  long: cacheMiddleware(1800),

  /**
   * Very long cache (1 hour) - for static data
   */
  veryLong: cacheMiddleware(3600),
};

module.exports = {
  cacheMiddleware,
  cacheKeys,
  cacheStrategies,
};
