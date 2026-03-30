/**
 * Redis Configuration
 * Redis client initialization for caching and session management
 */

const Redis = require('ioredis');
const config = require('./env');

// Redis client instance
let redisClient = null;

/**
 * Initialize Redis connection
 * @returns {Promise<void>}
 */
async function connectRedis() {
  try {
    if (config.REDIS_URL || process.env.REDIS_HOST) {
      const redisConfig = {
        host: process.env.REDIS_HOST || 'localhost',
        port: parseInt(process.env.REDIS_PORT || '6379'),
        password: process.env.REDIS_PASSWORD || undefined,
        db: parseInt(process.env.REDIS_DB || '0'),
        retryStrategy: (times) => {
          const delay = Math.min(times * 50, 2000);
          return delay;
        },
        maxRetriesPerRequest: 3,
      };

      redisClient = new Redis(redisConfig);

      // Event handlers
      redisClient.on('connect', () => {
        console.log('✅ Redis connected successfully');
      });

      redisClient.on('ready', () => {
        console.log('✅ Redis is ready to accept commands');
      });

      redisClient.on('error', (err) => {
        console.error('❌ Redis connection error:', err.message);
      });

      redisClient.on('close', () => {
        console.log('⚠️  Redis connection closed');
      });

      redisClient.on('reconnecting', () => {
        console.log('🔄 Reconnecting to Redis...');
      });
    } else {
      console.log('⚠️  Redis URL not provided, skipping Redis connection');
    }
  } catch (error) {
    console.error('❌ Redis connection failed:', error);
    // Don't exit process - Redis is optional
  }
}

/**
 * Disconnect from Redis
 * @returns {Promise<void>}
 */
async function disconnectRedis() {
  try {
    if (redisClient) {
      await redisClient.quit();
      console.log('✅ Redis disconnected successfully');
    }
  } catch (error) {
    console.error('❌ Redis disconnection failed:', error);
  }
}

/**
 * Get Redis client
 * @returns {Object|null} Redis client or null
 */
function getRedisClient() {
  return redisClient;
}

/**
 * Set cache value
 * @param {string} key - Cache key
 * @param {any} value - Value to cache
 * @param {number} [ttl=300] - Time to live in seconds (default 5 minutes)
 * @returns {Promise<boolean>} Success status
 */
async function setCache(key, value, ttl = 300) {
  try {
    if (redisClient && redisClient.status === 'ready') {
      await redisClient.setex(key, ttl, JSON.stringify(value));
      return true;
    }
    return false;
  } catch (error) {
    console.error('Cache set error:', error);
    return false;
  }
}

/**
 * Get cache value
 * @param {string} key - Cache key
 * @returns {Promise<any|null>} Cached value or null
 */
async function getCache(key) {
  try {
    if (redisClient && redisClient.status === 'ready') {
      const value = await redisClient.get(key);
      return value ? JSON.parse(value) : null;
    }
    return null;
  } catch (error) {
    console.error('Cache get error:', error);
    return null;
  }
}

/**
 * Delete cache value
 * @param {string} key - Cache key or pattern
 * @returns {Promise<boolean>} Success status
 */
async function deleteCache(key) {
  try {
    if (redisClient && redisClient.status === 'ready') {
      await redisClient.del(key);
      return true;
    }
    return false;
  } catch (error) {
    console.error('Cache delete error:', error);
    return false;
  }
}

/**
 * Delete all keys matching a pattern
 * @param {string} pattern - Pattern to match (e.g., 'user:*')
 * @returns {Promise<boolean>} Success status
 */
async function deleteCachePattern(pattern) {
  try {
    if (redisClient && redisClient.status === 'ready') {
      const keys = await redisClient.keys(pattern);
      if (keys.length > 0) {
        await redisClient.del(...keys);
      }
      return true;
    }
    return false;
  } catch (error) {
    console.error('Cache delete pattern error:', error);
    return false;
  }
}

/**
 * Check if key exists in cache
 * @param {string} key - Cache key
 * @returns {Promise<boolean>}
 */
async function existsCache(key) {
  try {
    if (redisClient && redisClient.status === 'ready') {
      const result = await redisClient.exists(key);
      return result === 1;
    }
    return false;
  } catch (error) {
    console.error('Cache exists error:', error);
    return false;
  }
}

module.exports = {
  connectRedis,
  disconnectRedis,
  getRedisClient,
  setCache,
  getCache,
  deleteCache,
  deleteCachePattern,
  existsCache,
};