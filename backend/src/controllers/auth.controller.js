const authService = require('../services/auth.service');
const { asyncHandler } = require('../middlewares/error.middleware');

const signup = asyncHandler(async (req, res) => {
  const { user, tokens } = await authService.register(req.body);
  res.status(201).json({
    success: true,
    message: 'Account created successfully',
    data: {
      user,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    },
  });
});

const login = asyncHandler(async (req, res) => {
  const { user, tokens } = await authService.login(req.body);
  res.json({
    success: true,
    message: 'Login successful',
    data: {
      user,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    },
  });
});

const googleLogin = asyncHandler(async (req, res) => {
  const { accessToken } = req.body;
  if (!accessToken) {
    return res.status(400).json({ success: false, message: 'Google access token is required' });
  }
  const { user, tokens } = await authService.loginWithGoogle(accessToken);
  res.json({
    success: true,
    message: 'Google login successful',
    data: {
      user,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    },
  });
});

const refreshToken = asyncHandler(async (req, res) => {
  const { refreshToken } = req.body;
  const tokens = await authService.refreshTokens(refreshToken);
  res.json({
    success: true,
    message: 'Tokens refreshed successfully',
    data: tokens,
  });
});

const logout = asyncHandler(async (req, res) => {
  const { refreshToken } = req.body;
  if (refreshToken) {
    await authService.logout(refreshToken);
  }
  res.json({
    success: true,
    message: 'Logged out successfully',
  });
});

const changePassword = asyncHandler(async (req, res) => {
  await authService.changePassword(req.userId, req.body);
  res.json({
    success: true,
    message: 'Password changed successfully',
  });
});

const forgotPassword = asyncHandler(async (req, res) => {
  const result = await authService.forgotPassword(req.body.email);
  res.json(result);
});

const resetPassword = asyncHandler(async (req, res) => {
  const { token, newPassword } = req.body;
  const result = await authService.resetPassword(token, newPassword);
  res.json(result);
});

const getMe = (req, res) => {
  res.json({
    success: true,
    message: 'User profile retrieved successfully',
    data: req.user,
  });
};

module.exports = {
  signup,
  login,
  googleLogin,
  refreshToken,
  logout,
  changePassword,
  forgotPassword,
  resetPassword,
  getMe
};
