/**
 * Express Application Setup
 * Main application configuration and middleware setup
 */

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const promBundle = require('express-prom-bundle');

const config = require('./config/env');
const { connectDatabase } = require('./config/db');
const { connectRedis } = require('./config/redis');
const passport = require('./config/passport');
const { errorHandler, notFoundHandler } = require('./middlewares/error.middleware');

// Import routes
const authRoutes = require('./routes/auth.routes');
const userRoutes = require('./routes/user.routes');
const topicRoutes = require('./routes/topics.routes');
const questionRoutes = require('./routes/question.routes');
const questionSetRoutes = require('./routes/questionSets.routes');
const challengeRoutes = require('./routes/challenges.routes');
const attemptRoutes = require('./routes/attempts.routes');
const leaderboardRoutes = require('./routes/leaderboard.routes');
const notificationRoutes = require('./routes/notification.routes');
const adminRoutes = require('./routes/admin.routes');
const recommendationRoutes = require('./routes/recommendation.routes');
const spectatorRoutes = require('./routes/spectator.routes');
const gdprRoutes = require('./routes/gdpr.routes');
const duelRoutes = require('./routes/duel.routes');
const feedRoutes = require('./routes/feed.routes');
const reportRoutes = require('./routes/report.routes');
const chatRoutes = require('./routes/chat.routes');
const savedRoutes = require('./routes/saved.routes');

/**
 * Create Express application
 * @returns {Object} Express app instance
 */
function createApp() {
  const app = express();

  const allowedOrigins = (config.CORS_ORIGIN || '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  const allowAllOrigins = allowedOrigins.includes('*');
  const isDevelopment = config.NODE_ENV === 'development';
  const allowTestTokenEndpoint =
    process.env.ENABLE_TEST_TOKEN_ENDPOINT === 'true' &&
    config.NODE_ENV === 'development';

  const isLocalDevOrigin = (origin) => {
    if (!isDevelopment || !origin) {
      return false;
    }

    try {
      const { hostname } = new URL(origin);
      return hostname === 'localhost' || hostname === '127.0.0.1' || hostname === '::1';
    } catch {
      return false;
    }
  };

  // Trust proxy for rate limiting and IP detection
  app.set('trust proxy', 1);

  // Prometheus metrics middleware
  const metricsMiddleware = promBundle({
    includeMethod: true,
    includePath: true,
    includeStatusCode: true,
    includeUp: true,
    customLabels: { project_name: 'learnduels_backend' },
    promClient: {
      collectDefaultMetrics: {
      }
    }
  });
  app.use(metricsMiddleware);

  // Initialize Passport
  app.use(passport.initialize());

  // Security middleware
  app.use(helmet({
    crossOriginEmbedderPolicy: false,
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        scriptSrc: ["'self'"],
        imgSrc: ["'self'", "data:", "https:"],
      },
    },
  }));

  // CORS configuration
  app.use(cors({
    origin: function (origin, callback) {
      // Allow requests with no origin (like mobile apps or curl requests)
      if (!origin) return callback(null, true);

      // Wildcard mode is allowed only without credentials.
      if (allowAllOrigins) {
        return callback(null, true);
      }

      if (allowedOrigins.includes(origin)) {
        return callback(null, true);
      }

      // Allow dynamic localhost ports for Flutter web and local tooling in development.
      if (isLocalDevOrigin(origin)) {
        return callback(null, true);
      }

      return callback(null, false);
    },
    credentials: !allowAllOrigins,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
  }));

  // Strict Rate Limiting for Auth Routes
  const authLimiter = rateLimit({
    windowMs: config.RATE_LIMIT_WINDOW,
    max: Math.max(20, Math.min(config.RATE_LIMIT_MAX, 100)),
    message: {
      success: false,
      message: 'Too many login attempts, please try again later.',
    },
    standardHeaders: true,
    legacyHeaders: false,
  });
  app.use('/api/auth', authLimiter);

  // Rate limiting - OPTIMIZED for 500-700 users
  const limiter = rateLimit({
    windowMs: config.RATE_LIMIT_WINDOW,
    max: config.RATE_LIMIT_MAX,
    message: {
      success: false,
      message: 'Too many requests from this IP, please try again later.',
    },
    standardHeaders: true,
    legacyHeaders: false,
  });
  app.use('/api', limiter); // Apply to all /api routes

  // Logging
  if (config.NODE_ENV === 'development') {
    app.use(morgan('dev'));
  } else {
    app.use(morgan('combined'));
  }

  // Body parsing
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  // Serve uploaded files statically
  const path = require('path');
  app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

  // API Routes
  app.use('/health', require('./routes/health.routes'));

  // Root endpoint (Welcome message)
  app.get('/', (req, res) => {
    res.json({
      success: true,
      message: 'Welcome to LearnDuels API 🚀',
      version: process.env.npm_package_version || '1.0.0',
      status: 'active',
      documentation: '/api',
      health_check: '/health'
    });
  });

  // Temporary route for token generation
  app.get('/api/test/token', (req, res, next) => {
    if (!allowTestTokenEndpoint) {
      return res.status(404).json({ success: false, message: 'Not Found' });
    }
    const { generateAccessToken } = require('./utils/token');
    const id = parseInt(req.query.id) || 1;
    // Standard test users
    const emails = { 1: 'ashwani@gmail.com', 2: 'akshar@gmail.com' };
    res.json({ token: generateAccessToken({ userId: id, email: emails[id] || `test${id}@example.com` }) });
  });

  // API Info endpoint
  app.get('/api', (req, res) => {
    res.json({
      success: true,
      message: 'Welcome to LearnDuels API',
      version: '2.0.0',
      documentation: '/api/docs',
      endpoints: {
        auth: '/api/auth',
        users: '/api/users',
        topics: '/api/topics',
        questions: '/api/questions',
        questionSets: '/api/question-sets',
        challenges: '/api/challenges',
        attempts: '/api/attempts',
        leaderboard: '/api/leaderboard',
        notifications: '/api/notifications',
        admin: '/api/admin',
        recommendations: '/api/recommendations',
        spectate: '/api/spectate',
        gdpr: '/api/gdpr',
        saved: '/api/saved',
        duels: '/api/duels',
        feed: '/api/feed',
        reports: '/api/reports',
        chat: '/api/chat',
      },
      timestamp: new Date().toISOString(),
    });
  });

  // API Routes - PRD Compliant
  app.use('/api/auth', authRoutes);
  app.use('/api/users', userRoutes);
  app.use('/api/topics', topicRoutes);
  app.use('/api/questions', questionRoutes);
  app.use('/api/question-sets', questionSetRoutes);
  app.use('/api/challenges', challengeRoutes);
  app.use('/api/attempts', attemptRoutes);
  app.use('/api/leaderboard', leaderboardRoutes);
  app.use('/api/notifications', notificationRoutes);
  app.use('/api/admin', adminRoutes);
  app.use('/api/recommendations', recommendationRoutes);
  app.use('/api/spectate', spectatorRoutes);
  app.use('/api/gdpr', gdprRoutes);
  app.use('/api/duels', duelRoutes);
  app.use('/api/feed', feedRoutes);
  app.use('/api/reports', reportRoutes);
  app.use('/api/chat', chatRoutes);
  app.use('/api/saved', savedRoutes);
  // Push notifications merged into notifications route

  // 404 handler for undefined routes
  app.use(notFoundHandler);

  // Global error handler (must be last)
  app.use(errorHandler);

  return app;
}

/**
 * Initialize application
 * @returns {Promise<Object>} Express app instance
 */
async function initializeApp() {
  try {
    console.log('🚀 Initializing LearnDuels Backend...');

    // Connect to database
    await connectDatabase();

    // Connect to Redis (optional)
    await connectRedis();

    // Create Express app
    const app = createApp();

    console.log('✅ Application initialized successfully');
    return app;
  } catch (error) {
    console.error('❌ Failed to initialize application:', error);
    process.exit(1);
  }
}

module.exports = {
  createApp,
  initializeApp,
};