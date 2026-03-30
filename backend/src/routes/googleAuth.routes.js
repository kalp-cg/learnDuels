/**
 * Google OAuth Routes
 * Mounted at /api/auth/google
 */

const express = require('express');
const router = express.Router();
const googleAuthController = require('../controllers/googleAuth.controller');

// GET /api/auth/google/url - Get Google OAuth authorization URL
router.get('/url', googleAuthController.getGoogleAuthUrl);

// GET /api/auth/google/callback - Handle Google OAuth web callback
router.get('/callback', googleAuthController.handleGoogleCallback);

// POST /api/auth/google/mobile - Handle Google Sign-In from Flutter mobile app
router.post('/mobile', googleAuthController.handleGoogleMobileAuth);

module.exports = router;
