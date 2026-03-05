/**
 * Health Check Controller
 * Handles application health monitoring
 */

const config = require('../config/env');

/**
 * Get system health status
 * @param {Object} req - Request object
 * @param {Object} res - Response object
 */
exports.getHealth = (req, res) => {
    res.json({
        success: true,
        message: 'LearnDuels API is healthy',
        timestamp: new Date().toISOString(),
        environment: config.NODE_ENV,
        version: process.env.npm_package_version || '1.0.0',
    });
};
