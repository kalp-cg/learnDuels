/**
 * JWT Token Utilities
 * Functions for creating, verifying, and managing JWT tokens
 */

const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const config = require('../config/env');

/**
 * Generate access token
 * @param {Object} payload - Token payload
 * @returns {string} JWT access token
 */
function generateAccessToken(payload) {
  return jwt.sign(payload, config.JWT_SECRET, {
    expiresIn: config.JWT_EXPIRE,
    issuer: 'learnduels',
    audience: 'learnduels-client',
  });
}

/**
 * Generate refresh token
 * @param {Object} payload - Token payload
 * @returns {string} JWT refresh token
 */
function generateRefreshToken(payload) {
  // Add a random nonce to ensure uniqueness even if generated in the same second
  const uniquePayload = {
    ...payload,
    nonce: crypto.randomBytes(16).toString('hex')
  };

  return jwt.sign(uniquePayload, config.JWT_REFRESH_SECRET, {
    expiresIn: config.JWT_REFRESH_EXPIRE,
    issuer: 'learnduels',
    audience: 'learnduels-client',
  });
}

/**
 * Verify access token
 * @param {string} token - JWT token
 * @returns {Object|null} Decoded payload or null
 */
function verifyAccessToken(token) {
  try {
    return jwt.verify(token, config.JWT_SECRET, {
      issuer: 'learnduels',
      audience: 'learnduels-client',
    });
  } catch (error) {
    console.error('Access token verification failed:', error.message);
    return null;
  }
}

/**
 * Verify refresh token
 * @param {string} token - JWT refresh token
 * @returns {Object|null} Decoded payload or null
 */
function verifyRefreshToken(token) {
  try {
    return jwt.verify(token, config.JWT_REFRESH_SECRET, {
      issuer: 'learnduels',
      audience: 'learnduels-client',
    });
  } catch (error) {
    console.error('Refresh token verification failed:', error.message);
    return null;
  }
}

/**
 * Generate token pair (access + refresh)
 * @param {Object} payload - Token payload
 * @returns {Object} Token pair
 */
function generateTokenPair(payload) {
  const accessToken = generateAccessToken(payload);
  const refreshToken = generateRefreshToken(payload);

  return {
    accessToken,
    refreshToken,
    expiresIn: config.JWT_EXPIRE,
    tokenType: 'Bearer',
  };
}

/**
 * Decode token without verification
 * @param {string} token - JWT token
 * @returns {Object|null} Decoded token or null
 */
function decodeToken(token) {
  try {
    return jwt.decode(token, { complete: true });
  } catch (error) {
    console.error('Token decode failed:', error.message);
    return null;
  }
}

/**
 * Check if token is expired
 * @param {string} token - JWT token
 * @returns {boolean} True if expired
 */
function isTokenExpired(token) {
  try {
    const decoded = jwt.decode(token);
    if (!decoded || !decoded.exp) {
      return true;
    }

    const currentTime = Math.floor(Date.now() / 1000);
    return decoded.exp < currentTime;
  } catch (error) {
    return true;
  }
}

module.exports = {
  generateAccessToken,
  generateRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
  generateTokenPair,
  decodeToken,
  isTokenExpired,
};