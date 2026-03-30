/**
 * Socket.IO Index
 * Main socket initialization and event routing
 */

const { Server } = require('socket.io');
const { createAdapter } = require('@socket.io/redis-adapter');
const { createClient } = require('redis');
const { verifyAccessToken } = require('../utils/token');
const config = require('../config/env');
const { prisma } = require('../config/db');

// Import socket handlers
const challengeHandler = require('./challenge.socket');
const duelHandler = require('./duel.socket');
const chatHandler = require('./chat.socket');
const spectatorService = require('../services/spectator.service');

let ioInstance;

/**
 * Initialize Socket.IO server
 * @param {Object} server - HTTP server instance
 * @returns {Object} Socket.IO server instance
 */
function initializeSocket(server) {
  const origin = config.SOCKET_CORS_ORIGIN || config.CORS_ORIGIN;
  const isDevelopment = config.NODE_ENV === 'development';
  const allowedOrigins = (origin || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);

  const isLocalDevOrigin = (incomingOrigin) => {
    if (!isDevelopment || !incomingOrigin) {
      return false;
    }

    try {
      const { hostname } = new URL(incomingOrigin);
      return hostname === 'localhost' || hostname === '127.0.0.1' || hostname === '::1';
    } catch {
      return false;
    }
  };

  const socketCorsOrigin = (incomingOrigin, callback) => {
    if (!incomingOrigin) {
      return callback(null, true);
    }

    if (origin === '*' || allowedOrigins.includes(incomingOrigin) || isLocalDevOrigin(incomingOrigin)) {
      return callback(null, true);
    }

    return callback(null, false);
  };

  const io = new Server(server, {
    cors: {
      origin: socketCorsOrigin,
      credentials: origin !== '*',
      methods: ['GET', 'POST'],
    },
    pingTimeout: 60000,
    pingInterval: 25000,
  });

  // Redis Adapter for Clustering
  const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';

  try {
    const pubClient = createClient({ url: redisUrl });
    const subClient = pubClient.duplicate();

    Promise.all([pubClient.connect(), subClient.connect()])
      .then(() => {
        io.adapter(createAdapter(pubClient, subClient));
        console.log('✅ Socket.IO Redis Adapter initialized');
      })
      .catch((err) => {
        console.error('❌ Failed to connect to Redis for Socket.IO Adapter:', err);
      });

    // Handle errors
    pubClient.on('error', (err) => console.error('Redis Pub Client Error:', err));
    subClient.on('error', (err) => console.error('Redis Sub Client Error:', err));

  } catch (error) {
    console.error('❌ Failed to initialize Redis Adapter:', error);
  }

  // Authentication middleware
  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth.token || socket.handshake.headers.authorization?.split(' ')[1];

      if (!token) {
        return next(new Error('Authentication token required'));
      }

      // Verify the JWT token
      const decoded = verifyAccessToken(token);
      socket.userId = decoded.userId || decoded.id; // Handle both cases

      // Populate user data (Handle both new and old tokens)
      if (decoded.fullName || decoded.username) {
        socket.userEmail = decoded.email;
        socket.userName = decoded.fullName || decoded.username;
        socket.userAvatar = decoded.avatarUrl;
        socket.userRating = decoded.rating;
      } else {
        // Fallback for old tokens: Fetch from DB
        try {
          const user = await prisma.user.findUnique({
            where: { id: socket.userId },
            select: { fullName: true, username: true, email: true, avatarUrl: true, rating: true }
          });
          if (user) {
            socket.userEmail = user.email;
            socket.userName = user.fullName || user.username;
            socket.userAvatar = user.avatarUrl;
            socket.userRating = user.rating;
          }
        } catch (dbError) {
          console.error('Failed to fetch user details for socket:', dbError);
        }
      }

      console.log(`Socket authenticated: ${socket.id} (User: ${socket.userId})`);
      next();
    } catch (error) {
      console.error('Socket authentication failed:', error.message);
      next(new Error('Authentication failed'));
    }
  });

  // Handle connections
  io.on('connection', (socket) => {
    console.log(`New socket connection: ${socket.id} (User: ${socket.userId})`);

    // Store user-socket mapping
    userSocketMap.set(socket.userId, socket.id);
    socketUserMap.set(socket.id, socket.userId);

    // Handle disconnection
    socket.on('disconnect', (reason) => {
      console.log(`Socket disconnected: ${socket.id} (User: ${socket.userId}) - Reason: ${reason}`);

      // Clean up mappings
      userSocketMap.delete(socket.userId);
      socketUserMap.delete(socket.id);

      // Leave spectating if watching
      spectatorService.leaveSpectate(socket.id);
    });

    // Register challenge event handlers (PRD compliant)
    challengeHandler.registerEvents(socket, io);

    // Register chat event handlers
    chatHandler.registerEvents(socket, io);

    // Spectator events
    socket.on('spectate:join', async (data) => {
      try {
        const { duelId } = data;
        const duelState = await spectatorService.joinSpectate(duelId, socket.userId, socket.id);

        // Join spectator room
        socket.join(`spectate:${duelId}`);

        // Send current state to spectator
        socket.emit('spectate:joined', duelState);

        // Notify players about new spectator
        io.to(`duel_${duelId}`).emit('spectate:viewer_joined', {
          spectatorCount: duelState.spectatorCount
        });
      } catch (error) {
        socket.emit('spectate:error', { message: error.message });
      }
    });

    socket.on('spectate:leave', (data) => {
      const { duelId } = data;
      spectatorService.leaveSpectate(socket.id);
      socket.leave(`spectate:${duelId}`);

      // Notify about viewer leaving
      io.to(`duel_${duelId}`).emit('spectate:viewer_left', {
        spectatorCount: spectatorService.activeDuels.get(duelId)?.spectators.size || 0
      });
    });

    // Handle general events
    socket.on('error', (error) => {
      console.error(`Socket error for ${socket.id}:`, error);
    });

    // Heartbeat/ping for connection health
    socket.on('ping', () => {
      socket.emit('pong');
    });

    // Handle user profile updates (avatar, name changes)
    socket.on('user:updateProfile', (data) => {
      if (data) {
        if (data.avatarUrl !== undefined) {
          socket.userAvatar = data.avatarUrl;
        }
        if (data.fullName !== undefined) {
          socket.userName = data.fullName;
        }
        console.log(`User ${socket.userId} updated profile: avatar=${socket.userAvatar}, name=${socket.userName}`);
      }
    });

    // Join user to their personal room for notifications
    socket.join(`user:${socket.userId}`);

    // Emit connection success
    socket.emit('connected', {
      message: 'Connected to LearnDuels server',
      socketId: socket.id,
      userId: socket.userId,
      timestamp: new Date().toISOString(),
    });
  });

  // Error handling
  io.on('error', (error) => {
    console.error('Socket.IO server error:', error);
  });

  // ==========================================
  // DUEL NAMESPACE (Real-time Gameplay)
  // ==========================================
  const duelNamespace = io.of('/duel');

  // Duel Namespace Middleware
  duelNamespace.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth.token || socket.handshake.headers.authorization?.split(' ')[1];
      if (!token) return next(new Error('Authentication token required'));

      const decoded = verifyAccessToken(token);
      socket.userId = decoded.userId || decoded.id;
      
      // Fetch user details for game state
      try {
        const user = await prisma.user.findUnique({
          where: { id: socket.userId },
          select: { fullName: true, username: true, email: true, avatarUrl: true, rating: true }
        });
        if (user) {
          socket.userEmail = user.email;
          socket.userName = user.fullName || user.username;
          socket.userAvatar = user.avatarUrl;
          socket.userRating = user.rating;
        }
      } catch (e) { console.error('User fetch error:', e); }

      next();
    } catch (error) {
      next(new Error('Authentication failed'));
    }
  });

  duelNamespace.on('connection', (socket) => {
    console.log(`⚔️  User ${socket.userId} connected to /duel namespace`);
    
    // Register duel events on the namespace
    duelHandler.registerEvents(socket, duelNamespace);
  });

  console.log('✅ Socket.IO server initialized');
  ioInstance = io;
  return io;
}

/**
 * Get the initialized IO instance
 */
function getIO() {
  if (!ioInstance) {
    throw new Error('Socket.IO not initialized!');
  }
  return ioInstance;
}

// In-memory mappings (in production, use Redis)
const userSocketMap = new Map(); // userId -> socketId
const socketUserMap = new Map(); // socketId -> userId

/**
 * Get socket ID for a user
 * @param {string} userId - User ID
 * @returns {string|null} Socket ID or null
 */
function getUserSocketId(userId) {
  return userSocketMap.get(userId) || null;
}

/**
 * Get user ID for a socket
 * @param {string} socketId - Socket ID
 * @returns {string|null} User ID or null
 */
function getSocketUserId(socketId) {
  return socketUserMap.get(socketId) || null;
}

/**
 * Check if user is online
 * @param {string} userId - User ID
 * @returns {boolean} True if user is online
 */
function isUserOnline(userId) {
  return userSocketMap.has(userId);
}

/**
 * Send notification to a specific user
 * @param {Object} io - Socket.IO server instance
 * @param {string} userId - Target user ID
 * @param {string} event - Event name
 * @param {Object} data - Event data
 * @returns {boolean} True if notification was sent
 */
function sendToUser(io, userId, event, data) {
  try {
    io.to(`user:${userId}`).emit(event, data);
    return true;
  } catch (error) {
    console.error('Failed to send notification to user:', error);
    return false;
  }
}

/**
 * Broadcast to all connected users
 * @param {Object} io - Socket.IO server instance
 * @param {string} event - Event name
 * @param {Object} data - Event data
 */
function broadcast(io, event, data) {
  try {
    io.emit(event, data);
  } catch (error) {
    console.error('Failed to broadcast message:', error);
  }
}

module.exports = {
  initializeSocket,
  getIO,
  getUserSocketId,
  getSocketUserId,
  isUserOnline,
  sendToUser,
  broadcast,
};