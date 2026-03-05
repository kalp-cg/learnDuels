/**
 * PM2 Ecosystem Configuration
 * 
 * This config enables clustering to utilize all CPU cores
 * and significantly increases backend capacity.
 * 
 * Usage:
 *   npm install -g pm2
 *   pm2 start ecosystem.config.js
 *   pm2 logs
 *   pm2 status
 *   pm2 stop all
 *   pm2 restart all
 */



module.exports = {
  apps: [{
    name: 'learnduels-backend',
    script: './src/server.js',
    
    // Cluster mode - use all CPU cores
    instances: 'max', // Or specify a number like 4
    exec_mode: 'cluster',
    
    // Environment variables
    env: {
      NODE_ENV: 'production',
      PORT: 4000
    },
    
    // Memory management
    max_memory_restart: '500M',
    
    // Auto-restart on crash
    autorestart: true,
    watch: false, // Set to true in development
    
    // Logging
    error_file: './logs/error.log',
    out_file: './logs/out.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    
    // Graceful shutdown
    kill_timeout: 5000,
    wait_ready: true,
    listen_timeout: 10000,
    
    // Performance monitoring
    merge_logs: true,
    instance_var: 'INSTANCE_ID'
  }]
};
