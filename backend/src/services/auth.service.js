/**
 * Authentication Service - New Schema
 * Handles user registration, login, and token management
 */

const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const { prisma } = require('../config/db');
const { generateTokenPair } = require('../utils/token');
const config = require('../config/env');
const { createError } = require('../middlewares/error.middleware');
const emailService = require('./email.service');
const googleAuthService = require('./googleAuth.service');

/**
 * Register a new user
 */
async function register(userData) {
  const { username, email, password, fullName } = userData;

  try {
    const existingUser = await prisma.user.findFirst({
      where: {
        OR: [
          { email },
          { username }
        ]
      },
    });

    if (existingUser) {
      if (existingUser.email === email) {
        throw createError.conflict('Email already registered');
      }
      if (existingUser.username === username) {
        throw createError.conflict('Username already taken');
      }
    }

    const passwordHash = await bcrypt.hash(password, config.BCRYPT_ROUNDS);

    const user = await prisma.user.create({
      data: {
        username,
        email,
        passwordHash,
        fullName, // Save full name
      },
      select: {
        id: true,
        username: true,
        email: true,
        fullName: true, // Return full name
        avatarUrl: true,
        role: true,
        xp: true,
        level: true,
        reputation: true,
        rating: true, // Include rating
        createdAt: true,
      },
    });

    const tokens = generateTokenPair({ 
      userId: user.id, 
      email: user.email,
      username: user.username,
      fullName: user.fullName,
      avatarUrl: user.avatarUrl,
      rating: user.rating
    });

    await prisma.refreshToken.create({
      data: {
        userId: user.id,
        token: tokens.refreshToken,
        expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      },
    });

    return { user, tokens };
  } catch (error) {
    console.error('❌ Registration error:', error);
    console.error('Error stack:', error.stack);
    if (error.isOperational) throw error;
    throw createError.internal('Failed to create account');
  }
}

/**
 * Login user
 */
async function login(credentials) {
  const { email, password } = credentials;

  try {
    const user = await prisma.user.findFirst({
      where: { 
        email,
        deletedAt: null, // Exclude soft-deleted users
        isActive: true
      },
      select: {
        id: true,
        username: true,
        email: true,
        fullName: true, // Include full name
        passwordHash: true,
        avatarUrl: true,
        role: true,
        xp: true,
        level: true,
        reputation: true,
        rating: true, // Include rating
        createdAt: true,
      },
    });

    if (!user) {
      throw createError.unauthorized('Invalid email or password');
    }

    const isValidPassword = await bcrypt.compare(password, user.passwordHash);
    if (!isValidPassword) {
      throw createError.unauthorized('Invalid email or password');
    }

    const tokens = generateTokenPair({ 
      userId: user.id, 
      email: user.email,
      username: user.username,
      fullName: user.fullName,
      avatarUrl: user.avatarUrl,
      rating: user.rating
    });

    await prisma.refreshToken.create({
      data: {
        userId: user.id,
        token: tokens.refreshToken,
        expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      },
    });

    const { passwordHash, ...userWithoutPassword } = user;

    return { user: userWithoutPassword, tokens };
  } catch (error) {
    console.error('Login error details:', error);
    if (error.isOperational) throw error;
    throw createError.internal('Login failed');
  }
}

/**
 * Refresh access token
 */
async function refreshTokens(refreshToken) {
  try {
    const storedToken = await prisma.refreshToken.findUnique({
      where: { token: refreshToken },
      include: { user: true },
    });

    if (!storedToken) {
      throw createError.unauthorized('Invalid refresh token');
    }

    if (new Date() > storedToken.expiresAt) {
      await prisma.refreshToken.delete({ where: { token: refreshToken } });
      throw createError.unauthorized('Refresh token expired');
    }

    const tokens = generateTokenPair({
      userId: storedToken.user.id,
      email: storedToken.user.email,
      username: storedToken.user.username,
      fullName: storedToken.user.fullName,
      avatarUrl: storedToken.user.avatarUrl,
      rating: storedToken.user.rating
    });

    await prisma.refreshToken.delete({ where: { token: refreshToken } });
    await prisma.refreshToken.create({
      data: {
        userId: storedToken.user.id,
        token: tokens.refreshToken,
        expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      },
    });

    return tokens;
  } catch (error) {
    if (error.isOperational) throw error;
    throw createError.internal('Token refresh failed');
  }
}

/**
 * Logout user
 */
async function logout(refreshToken) {
  try {
    if (!refreshToken) {
      throw createError.badRequest('Refresh token is required');
    }

    // Use deleteMany to avoid throwing when token is already rotated/absent
    const result = await prisma.refreshToken.deleteMany({ where: { token: refreshToken } });

    return { success: true, revoked: result.count };
  } catch (error) {
    if (error.isOperational) throw error;
    throw createError.internal('Logout failed');
  }
}

/**
 * Create session record
 */
async function createSession(userId, ipAddress, userAgent) {
  try {
    return await prisma.session.create({
      data: { userId, ipAddress, userAgent },
    });
  } catch (error) {
    console.error('Session creation error:', error);
  }
}

/**
 * Change user password
 */
async function changePassword(userId, passwordData) {
  // Support both 'currentPassword' and 'oldPassword' field names
  const currentPassword = passwordData.currentPassword || passwordData.oldPassword;
  const { newPassword } = passwordData;

  try {
    const user = await prisma.user.findUnique({
      where: { id: userId },
    });

    if (!user) {
      throw createError.notFound('User not found');
    }

    const isValidPassword = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!isValidPassword) {
      throw createError.unauthorized('Current password is incorrect');
    }

    const newPasswordHash = await bcrypt.hash(newPassword, config.BCRYPT_ROUNDS);

    await prisma.user.update({
      where: { id: userId },
      data: { passwordHash: newPasswordHash },
    });

    // Invalidate all refresh tokens for security
    await prisma.refreshToken.deleteMany({
      where: { userId },
    });

    return { success: true };
  } catch (error) {
    if (error.isOperational) throw error;
    throw createError.internal('Failed to change password');
  }
}

/**
 * Request password reset
 */
async function forgotPassword(email) {
  try {
    const user = await prisma.user.findUnique({
      where: { email },
    });

    if (!user) {
      // Don't reveal that user doesn't exist
      return { success: true, message: 'If an account exists, a reset email has been sent.' };
    }

    // Generate reset token
    const resetToken = crypto.randomBytes(32).toString('hex');
    const passwordResetToken = crypto
      .createHash('sha256')
      .update(resetToken)
      .digest('hex');

    const passwordResetExpires = new Date(Date.now() + 60 * 60 * 1000); // 1 hour

    await prisma.user.update({
      where: { id: user.id },
      data: {
        passwordResetToken,
        passwordResetExpires,
      },
    });

    // Send email
    await emailService.sendPasswordReset(user.email, resetToken);

    return { success: true, message: 'If an account exists, a reset email has been sent.' };
  } catch (error) {
    console.error('Forgot password error:', error);
    throw createError.internal('Failed to process password reset request');
  }
}

/**
 * Reset password with token
 */
async function resetPassword(token, newPassword) {
  try {
    const passwordResetToken = crypto
      .createHash('sha256')
      .update(token)
      .digest('hex');

    const user = await prisma.user.findFirst({
      where: {
        passwordResetToken,
        passwordResetExpires: {
          gt: new Date(),
        },
      },
    });

    if (!user) {
      throw createError.badRequest('Token is invalid or has expired');
    }

    const passwordHash = await bcrypt.hash(newPassword, config.BCRYPT_ROUNDS);

    await prisma.user.update({
      where: { id: user.id },
      data: {
        passwordHash,
        passwordResetToken: null,
        passwordResetExpires: null,
      },
    });

    // Invalidate all sessions
    await prisma.refreshToken.deleteMany({
      where: { userId: user.id },
    });

    return { success: true, message: 'Password has been reset successfully' };
  } catch (error) {
    if (error.isOperational) throw error;
    console.error('Reset password error:', error);
    throw createError.internal('Failed to reset password');
  }
}

/**
 * Login with Google
 */
async function loginWithGoogle(accessToken) {
  try {
    const googleUser = await googleAuthService.getGoogleUserInfo(null, accessToken);
    const user = await googleAuthService.findOrCreateGoogleUser(googleUser);

    const tokens = generateTokenPair({ 
      userId: user.id, 
      email: user.email,
      username: user.username,
      fullName: user.fullName,
      avatarUrl: user.avatarUrl,
      rating: user.rating,
      role: user.role
    });

    await prisma.refreshToken.create({
      data: {
        userId: user.id,
        token: tokens.refreshToken,
        expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      },
    });

    return { user, tokens };
  } catch (error) {
    console.error('Google login error:', error);
    if (error.isOperational) throw error;
    throw createError.internal('Google login failed');
  }
}

module.exports = {
  register,
  login,
  loginWithGoogle,
  refreshTokens,
  logout,
  createSession,
  changePassword,
  forgotPassword,
  resetPassword,
};
