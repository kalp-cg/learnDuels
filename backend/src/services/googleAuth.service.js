/**
 * Google OAuth Authentication Service
 * Handles Google OAuth flow, token exchange, and user profile retrieval
 */

const axios = require('axios');
const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');
const config = require('../config/env');

const prisma = new PrismaClient();

/**
 * Generate Google OAuth URL for user authorization
 * @param {string} state - State parameter to maintain state between request and callback (used for platform detection)
 * @returns {string} Google OAuth authorization URL
 */
function getGoogleAuthUrl(state) {
  const rootUrl = 'https://accounts.google.com/o/oauth2/v2/auth';

  const options = {
    redirect_uri: 'http://10.132.37.122.nip.io:4000/api/auth/google/callback',
    client_id: config.GOOGLE_CLIENT_ID,
    access_type: 'offline',
    response_type: 'code',
    prompt: 'consent',
    scope: [
      'https://www.googleapis.com/auth/userinfo.profile',
      'https://www.googleapis.com/auth/userinfo.email',
    ].join(' '),
  };

  if (state) {
    options.state = state;
  }

  const queryString = new URLSearchParams(options).toString();
  const authUrl = `${rootUrl}?${queryString}`;
  console.log('🔐 Generated Google Auth URL:', authUrl);
  return authUrl;
}

/**
 * Exchange authorization code for access token
 * @param {string} code - Authorization code from Google
 * @returns {Promise<Object>} Token response with access_token and id_token
 */
async function getGoogleTokens(code) {
  try {
    const url = 'https://oauth2.googleapis.com/token';

    const values = {
      code,
      client_id: config.GOOGLE_CLIENT_ID,
      client_secret: config.GOOGLE_CLIENT_SECRET,
      redirect_uri: 'http://10.132.37.122.nip.io:4000/api/auth/google/callback',
      grant_type: 'authorization_code',
    };

    const response = await axios.post(url, new URLSearchParams(values), {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    });

    return response.data;
  } catch (error) {
    console.error('Error exchanging code for tokens:', error.response?.data || error.message);
    throw new Error('Failed to exchange authorization code for tokens');
  }
}

/**
 * Get Google user profile information
 * @param {string} id_token - ID token from Google
 * @param {string} access_token - Access token from Google
 * @returns {Promise<Object>} User profile data
 */
async function getGoogleUserInfo(id_token, access_token) {
  try {
    const response = await axios.get(
       `https://www.googleapis.com/oauth2/v1/userinfo?alt=json`,
      {
        headers: {
          Authorization: `Bearer ${access_token}`,
        },
      }
    );

    return response.data;
  } catch (error) {
    console.error('Error fetching Google user info:', error.response?.data || error.message);
    throw new Error('Failed to fetch user information from Google');
  }
}

/**
 * Find or create user based on Google profile
 * @param {Object} googleUser - Google user profile data
 * @returns {Promise<Object>} User object from database
 */
async function findOrCreateGoogleUser(googleUser) {
  const { id, email, name, picture, verified_email } = googleUser;

  if (!verified_email) {
    throw new Error('Google email is not verified');
  }

  try {
    // Check if user already exists with Google ID
    let user = await prisma.user.findUnique({
      where: { googleId: id },
    });

    if (user) {
      // Update user info if changed
      const updateData = {};
      if (user.fullName !== name) updateData.fullName = name;
      if (user.avatarUrl !== picture) updateData.avatarUrl = picture;

      if (Object.keys(updateData).length > 0) {
        user = await prisma.user.update({
          where: { id: user.id },
          data: updateData,
        });
      }

      return user;
    }

    // Check if user exists with same email (from email/password auth)
    user = await prisma.user.findUnique({
      where: { email },
    });

    if (user) {
      // Link Google account to existing email/password account
      user = await prisma.user.update({
        where: { id: user.id },
        data: {
          googleId: id,
          avatarUrl: picture || user.avatarUrl,
          authProvider: 'google',
        },
      });

      return user;
    }

    // Create new user
    user = await prisma.user.create({
      data: {
        email,
        fullName: name,
        avatarUrl: picture,
        googleId: id,
        authProvider: 'google',
        passwordHash: null, // Google users don't need a password
        isActive: true,
        rating: 1000, // Default rating for new users
      },
    });

    return user;
  } catch (error) {
    console.error('Error in findOrCreateGoogleUser:', error);
    throw new Error('Failed to create or update user');
  }
}

/**
 * Generate JWT token for authenticated user
 * @param {Object} user - User object from database
 * @returns {string} JWT token
 */
function generateJWT(user) {
  const payload = {
    id: user.id,
    email: user.email,
    fullName: user.fullName,
    role: user.role,
  };

  return jwt.sign(payload, config.JWT_SECRET, {
    expiresIn: '7d', // 7 days expiration as per requirements
  });
}

/**
 * Generate refresh token for user
 * @param {Object} user - User object from database
 * @returns {string} Refresh token
 */
function generateRefreshToken(user) {
  const payload = {
    id: user.id,
    email: user.email,
  };

  return jwt.sign(payload, config.JWT_REFRESH_SECRET, {
    expiresIn: '30d', // 30 days for refresh token
  });
}

/**
 * Complete Google OAuth flow
 * @param {string} code - Authorization code from Google callback
 * @returns {Promise<Object>} User and tokens
 */
async function handleGoogleCallback(code) {
  try {
    // Step 1: Exchange code for tokens
    const tokens = await getGoogleTokens(code);
    const { id_token, access_token } = tokens;

    // Step 2: Get user info from Google
    const googleUser = await getGoogleUserInfo(id_token, access_token);

    // Step 3: Find or create user in our database
    const user = await findOrCreateGoogleUser(googleUser);

    // Step 4: Generate our JWT tokens
    const accessToken = generateJWT(user);
    const refreshToken = generateRefreshToken(user);

    // Step 5: Store refresh token in database
    await prisma.refreshToken.create({
      data: {
        token: refreshToken,
        userId: user.id,
        expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days
      },
    });

    return {
      user: {
        id: user.id,
        email: user.email,
        fullName: user.fullName,
        avatarUrl: user.avatarUrl,
        rating: user.rating,
        role: user.role,
      },
      accessToken,
      refreshToken,
    };
  } catch (error) {
    console.error('Error in handleGoogleCallback:', error);
    throw error;
  }
}

/**
 * Handle Google Mobile Authentication (Native Sign-In)
 * @param {string} accessToken - Google access token
 * @param {string} idToken - Google ID token
 * @returns {Promise<Object>} User and tokens
 */
async function handleGoogleMobileAuth(accessToken, idToken) {
  try {
    // Get user info from Google using the provided tokens
    const googleUser = await getGoogleUserInfo(idToken, accessToken);

    // Find or create user in our database
    const user = await findOrCreateGoogleUser(googleUser);

    // Generate our JWT tokens
    const jwtAccessToken = generateJWT(user);
    const refreshToken = generateRefreshToken(user);

    // Store refresh token in database
    await prisma.refreshToken.create({
      data: {
        token: refreshToken,
        userId: user.id,
        expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days
      },
    });

    return {
      user: {
        id: user.id,
        email: user.email,
        fullName: user.fullName,
        username: user.username,
        avatarUrl: user.avatarUrl,
        rating: user.rating,
        role: user.role,
      },
      accessToken: jwtAccessToken,
      refreshToken,
    };
  } catch (error) {
    console.error('Error in handleGoogleMobileAuth:', error);
    throw new Error('Failed to authenticate with Google');
  }
}

module.exports = {
  getGoogleAuthUrl,
  handleGoogleCallback,
  handleGoogleMobileAuth,
  getGoogleTokens,
  getGoogleUserInfo,
  findOrCreateGoogleUser,
  generateJWT,
  generateRefreshToken,
};
