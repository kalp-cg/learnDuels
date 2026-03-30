/**
 * Server Entry Point
 * HTTP server with Socket.IO integration and graceful shutdown
 */

const http = require('http');
const { initializeApp } = require('./app');
const { initializeSocket } = require('./sockets');
const { prisma } = require('./config/db');

// Get PORT directly from environment (AWS Elastic Beanstalk compatible)
const PORT = process.env.PORT || 5000;
const HOST = '0.0.0.0';

/**
 * Create and start the HTTP server
 */
async function startServer() {
  try {
    // Initialize Express app
    const app = await initializeApp();

    // Create HTTP server
    const server = http.createServer(app);

    // Initialize Socket.IO
    const io = initializeSocket(server);

    // Store io instance in app for access in routes if needed
    app.set('io', io);

    // Server event handlers
    server.on('error', (error) => {
      if (error.syscall !== 'listen') {
        throw error;
      }

      const bind = typeof PORT === 'string'
        ? 'Pipe ' + PORT
        : 'Port ' + PORT;

      // Handle specific listen errors with friendly messages
      switch (error.code) {
        case 'EACCES':
          console.error(`❌ ${bind} requires elevated privileges`);
          process.exit(1);
          break;
        case 'EADDRINUSE':
          console.error(`❌ ${bind} is already in use`);
          process.exit(1);
          break;
        default:
          throw error;
      }
    });

    server.on('listening', () => {
      const addr = server.address();
      const bind = typeof addr === 'string'
        ? 'pipe ' + addr
        : 'port ' + addr.port;
      
      console.log('🎯 Server Configuration:');
      console.log(`   Environment: ${process.env.NODE_ENV || 'development'}`);
      console.log(`   Port: ${addr.port}`);
      console.log(`   Database: ${process.env.DATABASE_URL ? 'Connected' : 'Not configured'}`);
      console.log(`   Redis: ${process.env.REDIS_URL ? 'Configured' : 'Not configured'}`);
      console.log('');
      console.log('🌐 API Endpoints:');
      console.log(`   Health: http://localhost:${addr.port}/health`);
      console.log(`   API Info: http://localhost:${addr.port}/api`);
      console.log(`   Auth: http://localhost:${addr.port}/api/auth`);
      console.log(`   Socket.IO: ws://localhost:${addr.port}`);
      console.log('');
      console.log(`🚀 LearnDuels server listening on ${bind}`);
    });

    // Graceful shutdown handlers
    const gracefulShutdown = async (signal) => {
      console.log(`\n📤 ${signal} received. Starting graceful shutdown...`);
      
      // Stop accepting new connections
      server.close(async () => {
        console.log('🔌 HTTP server closed');
        
        try {
          // Close Socket.IO connections
          io.close();
          console.log('🔌 Socket.IO closed');
          
          // Close database connections
          await prisma.$disconnect();
          console.log('🗄️  Database disconnected');
          
          console.log('✅ Graceful shutdown completed');
          process.exit(0);
        } catch (error) {
          console.error('❌ Error during shutdown:', error);
          process.exit(1);
        }
      });
      
      // Force close after 30 seconds
      setTimeout(() => {
        console.error('⏰ Forced shutdown after timeout');
        process.exit(1);
      }, 30000);
    };

    // Handle different shutdown signals
    process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
    process.on('SIGINT', () => gracefulShutdown('SIGINT'));
    process.on('SIGUSR1', () => gracefulShutdown('SIGUSR1'));
    process.on('SIGUSR2', () => gracefulShutdown('SIGUSR2'));

    // Handle uncaught exceptions
    process.on('uncaughtException', (error) => {
      console.error('💥 Uncaught Exception:', error);
      gracefulShutdown('UNCAUGHT_EXCEPTION');
    });

    // Handle unhandled promise rejections
    process.on('unhandledRejection', (reason, promise) => {
      console.error('💥 Unhandled Rejection at:', promise, 'reason:', reason);
      gracefulShutdown('UNHANDLED_REJECTION');
    });

    // Start listening
    server.listen(PORT, HOST);

    return server;
  } catch (error) {
    console.error('💥 Failed to start server:', error);
    process.exit(1);
  }
}

/**
 * Start the server if this file is run directly
 */
if (require.main === module) {
  startServer().catch((error) => {
    console.error('💥 Server startup failed:', error);
    process.exit(1);
  });
}

module.exports = {
  startServer,
};