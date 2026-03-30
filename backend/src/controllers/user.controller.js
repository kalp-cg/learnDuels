/**
 * User Controller
 * Handles user profile management including image uploads
 */

const userService = require('../services/user.service');
const { asyncHandler } = require('../middlewares/error.middleware');

/**
 * Get all users with pagination and search
 */
const getAllUsers = asyncHandler(async (req, res) => {
  const { page, limit, search, sortBy } = req.query;
  const result = await userService.getAllUsers(req.userId, {
    page: parseInt(page) || 1,
    limit: parseInt(limit) || 20,
    search,
    sortBy,
  });

  res.json({
    success: true,
    message: 'Users retrieved successfully',
    data: result.users,
    pagination: result.pagination,
  });
});

/**
 * Get current user's profile
 */
const getProfile = asyncHandler(async (req, res) => {
  const profile = await userService.getUserProfile(req.userId);

  res.json({
    success: true,
    message: 'Profile retrieved successfully',
    data: profile,
  });
});

/**
 * Get user by ID
 */
const getUserById = asyncHandler(async (req, res) => {
  const profile = await userService.getUserProfile(req.params.id, req.userId);

  res.json({
    success: true,
    message: 'User profile retrieved successfully',
    data: profile,
  });
});

/**
 * Update user profile (including avatar)
 */
const updateProfile = asyncHandler(async (req, res) => {
  const { fullName, bio, username, avatarUrl } = req.body;
  const avatarFile = req.file; // From multer middleware

  const updatedProfile = await userService.updateUserProfile(req.userId, {
    fullName,
    bio,
    username,
    avatarUrl,  // Support direct URL updates
    avatarFile, // Support file uploads
  });

  res.json({
    success: true,
    message: 'Profile updated successfully',
    data: updatedProfile,
  });
});

/**
 * Upload/Update profile picture
 */
const uploadAvatar = asyncHandler(async (req, res) => {
  if (!req.file) {
    return res.status(400).json({
      success: false,
      message: 'No image file provided',
    });
  }

  const avatarUrl = await userService.uploadAvatar(req.userId, req.file);

  res.json({
    success: true,
    message: 'Avatar uploaded successfully',
    data: { avatarUrl },
  });
});

/**
 * Delete profile picture
 */
const deleteAvatar = asyncHandler(async (req, res) => {
  await userService.deleteAvatar(req.userId);

  res.json({
    success: true,
    message: 'Avatar deleted successfully',
  });
});

/**
 * Follow a user (send follow request)
 */
const followUser = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const result = await userService.followUser(req.userId, parseInt(id));

  res.json({
    success: true,
    message: result.message || 'Follow request sent successfully',
    data: {
      status: 'pending',
      message: result.message
    }
  });
});

/**
 * Unfollow a user or cancel follow request
 */
const unfollowUser = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const result = await userService.unfollowUser(req.userId, parseInt(id));

  res.json({
    success: true,
    message: result.message || 'Unfollowed successfully',
  });
});

/**
 * Accept follow request
 */
const acceptFollowRequest = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const result = await userService.acceptFollowRequest(req.userId, parseInt(id));

  res.json({
    success: true,
    message: result.message || 'Follow request accepted',
  });
});

/**
 * Decline follow request
 */
const declineFollowRequest = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const result = await userService.declineFollowRequest(req.userId, parseInt(id));

  res.json({
    success: true,
    message: result.message || 'Follow request declined',
  });
});

/**
 * Get pending follow requests
 */
const getPendingFollowRequests = asyncHandler(async (req, res) => {
  const { page, limit } = req.query;
  const result = await userService.getPendingFollowRequests(req.userId, {
    page: parseInt(page) || 1,
    limit: parseInt(limit) || 20,
  });

  res.json({
    success: true,
    message: 'Follow requests retrieved successfully',
    data: result.requests,
    pagination: result.pagination,
  });
});

/**
 * Get user's followers
 */
const getFollowers = asyncHandler(async (req, res) => {
  // Use req.params.id for /:id/followers routes, fallback to req.userId for /me/followers
  const id = req.params.id || req.userId;
  const result = await userService.getFollowers(parseInt(id));

  res.json({
    success: true,
    message: 'Followers retrieved successfully',
    // Flatten the response - extract followers array directly if it exists
    data: result.followers || result,
  });
});

/**
 * Get users that a user is following
 */
const getFollowing = asyncHandler(async (req, res) => {
  // Use req.params.id for /:id/following routes, fallback to req.userId for /me/following
  const id = req.params.id || req.userId;
  const result = await userService.getFollowing(parseInt(id));

  res.json({
    success: true,
    message: 'Following retrieved successfully',
    // Flatten the response - extract `following` array directly if it exists
    data: result.following || result,
  });
});

/**
 * Search users
 */
const searchUsers = asyncHandler(async (req, res) => {
  const { query } = req.query;
  const users = await userService.searchUsers(query, req.userId);

  res.json({
    success: true,
    message: 'Search results retrieved successfully',
    data: users,
  });
});

module.exports = {
  getAllUsers,
  getProfile,
  getUserById,
  updateProfile,
  uploadAvatar,
  deleteAvatar,
  followUser,
  unfollowUser,
  acceptFollowRequest,
  declineFollowRequest,
  getPendingFollowRequests,
  getFollowers,
  getFollowing,
  searchUsers,
};
