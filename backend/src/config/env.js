/**
 * Environment Configuration
 * EB-safe, fail-fast, production-ready
 */

const dotenv = require('dotenv');

// Load .env file
// Note: dotenv will NOT overwrite existing environment variables, 
// so this is safe even if variables are provided by the host system.
dotenv.config();

// Helper to require env vars (fail fast)
function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`❌ Missing required environment variable: ${name}`);
  }
  return value;
}

// Helper for optional numeric env
function optionalNumber(name, defaultValue) {
  const value = process.env[name];
  return value ? Number(value) : defaultValue;
}

const config = {
  /* ============================
     Server
  ============================ */
  NODE_ENV: process.env.NODE_ENV || 'development',
  PORT: Number(process.env.PORT) || 8080, // EB injects PORT
  HOST: '0.0.0.0',

  /* ============================
     Database (REQUIRED)
  ============================ */
  DATABASE_URL: requireEnv('DATABASE_URL'),

  /* ============================
     JWT (REQUIRED)
  ============================ */
  JWT_SECRET: requireEnv('JWT_SECRET'),
  JWT_REFRESH_SECRET: requireEnv('JWT_REFRESH_SECRET'),
  JWT_EXPIRE: process.env.JWT_EXPIRE || '15m',
  JWT_REFRESH_EXPIRE: process.env.JWT_REFRESH_EXPIRE || '7d',

  /* ============================
     Redis (Optional but explicit)
  ============================ */
  REDIS_HOST: process.env.REDIS_HOST || null,
  REDIS_PORT: process.env.REDIS_PORT ? Number(process.env.REDIS_PORT) : null,
  REDIS_PASSWORD: process.env.REDIS_PASSWORD || null,
  REDIS_DB: process.env.REDIS_DB ? Number(process.env.REDIS_DB) : 0,

  /* ============================
     CORS
  ============================ */
  CORS_ORIGIN: process.env.CORS_ORIGIN || '*',

  /* ============================
     Rate Limiting
  ============================ */
  RATE_LIMIT_WINDOW: optionalNumber('RATE_LIMIT_WINDOW', 15 * 60 * 1000),
  RATE_LIMIT_MAX: optionalNumber('RATE_LIMIT_MAX', 100),

  /* ============================
     Security
  ============================ */
  BCRYPT_ROUNDS: optionalNumber('BCRYPT_ROUNDS', 12),

  /* ============================
     URLs
  ============================ */
  SERVER_URL: requireEnv('SERVER_URL'),
  FLUTTER_WEB_URL: process.env.FLUTTER_WEB_URL || null,
  FLUTTER_DEEP_LINK_SCHEME: process.env.FLUTTER_DEEP_LINK_SCHEME || 'learn_duel_app',

  /* ============================
     Cloudinary (Optional features)
  ============================ */
  CLOUDINARY_CLOUD_NAME: process.env.CLOUDINARY_CLOUD_NAME || null,
  CLOUDINARY_API_KEY: process.env.CLOUDINARY_API_KEY || null,
  CLOUDINARY_API_SECRET: process.env.CLOUDINARY_API_SECRET || null,
};

// Minimal safe log (no secrets)
if (config.NODE_ENV !== 'production') {
  console.log('✅ Environment loaded:');
  console.log(`- NODE_ENV: ${config.NODE_ENV}`);
  console.log(`- PORT: ${config.PORT}`);
  console.log(`- DATABASE_URL: ${config.DATABASE_URL ? 'SET' : 'MISSING'}`);
  console.log(`- REDIS: ${config.REDIS_HOST ? 'ENABLED' : 'DISABLED'}`);
}

module.exports = config;