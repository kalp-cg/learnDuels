/**
 * Google OAuth Authentication Controller
 * Handles HTTP requests for Google OAuth flow
 */

const googleAuthService = require('../services/googleAuth.service');
const config = require('../config/env');

/**
 * Get Google OAuth authorization URL
 * Route: GET /api/auth/google/url
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
async function getGoogleAuthUrl(req, res) {
  try {
    const { platform } = req.query; // 'mobile' or 'web'
    const url = googleAuthService.getGoogleAuthUrl(platform);

    res.json({
      success: true,
      data: {
        url,
      },
    });
  } catch (error) {
    console.error('Error generating Google auth URL:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to generate Google authentication URL',
      error: error.message,
    });
  }
}

/**
 * Handle Google OAuth callback
 * Route: GET /api/auth/google/callback
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
async function handleGoogleCallback(req, res) {
  const { code, error, state } = req.query;

  try {
    // Check if user denied access
    if (error) {
      console.error('Google OAuth error:', error);
      const webAppUrl = process.env.FLUTTER_WEB_URL || 'http://localhost:8080';
      return res.redirect(`${webAppUrl}/#/login?error=${encodeURIComponent(error)}`);
    }

    // Validate authorization code
    if (!code) {
      const webAppUrl = process.env.FLUTTER_WEB_URL || 'http://localhost:8080';
      return res.redirect(`${webAppUrl}/#/login?error=${encodeURIComponent('No authorization code received')}`);
    }

    // Process Google OAuth callback
    const { user, accessToken, refreshToken } = await googleAuthService.handleGoogleCallback(code);

    // Determine redirect URL based on state (platform)
    let redirectUrl;
    if (state === 'mobile') {
      // Redirect to mobile app via deep link
      // Scheme must match AndroidManifest.xml (learn_duel_app)
      redirectUrl = `learn_duel_app://auth/callback?access_token=${encodeURIComponent(accessToken)}&refresh_token=${encodeURIComponent(refreshToken)}`;

      // For mobile deep links, return an HTML page that redirects via JS
      // This avoids issues where the browser treats the custom scheme as a relative path
      return res.send(`
        <!DOCTYPE html>
        <html>
          <head>
            <meta charset="UTF-8">
            <title>Redirecting...</title>
            <script>
              window.onload = function() {
                // Try automatic redirect
                window.location.href = "${redirectUrl}";
              };
            </script>
            <style>
              body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                display: flex;
                flex-direction: column;
                justify-content: center;
                align-items: center;
                min-height: 100vh;
                margin: 0;
                background: #f0f2f5;
                text-align: center;
                padding: 20px;
              }
              .success-icon {
                font-size: 48px;
                margin-bottom: 20px;
              }
              h3 { color: #2e7d32; margin: 0 0 10px 0; }
              p { color: #666; margin-bottom: 30px; }
              .btn {
                background-color: #1976d2;
                color: white;
                padding: 15px 30px;
                border-radius: 25px;
                text-decoration: none;
                font-weight: bold;
                font-size: 16px;
                box-shadow: 0 4px 6px rgba(0,0,0,0.1);
                transition: transform 0.2s;
              }
              .btn:active { transform: scale(0.95); }
            </style>
          </head>
          <body>
            <div class="success-icon">✅</div>
            <h3>Authentication Successful!</h3>
            <p>You can now return to the app.</p>
            <a href="${redirectUrl}" class="btn">Open App</a>
          </body>
        </html>
      `);
    } else {
      // Default to web app
      const webAppUrl = process.env.FLUTTER_WEB_URL || 'http://localhost:8080';
      redirectUrl = `${webAppUrl}/#/home?access_token=${encodeURIComponent(accessToken)}&refresh_token=${encodeURIComponent(refreshToken)}`;
      return res.redirect(302, redirectUrl);
    }

  } catch (error) {
    console.error('Google callback error:', error);

    const webAppUrl = process.env.FLUTTER_WEB_URL || 'http://localhost:8080';
    const errorMessage = encodeURIComponent(error.message || 'Authentication failed');

    return res.send(`
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="UTF-8">
          <meta http-equiv="Content-Security-Policy" content="default-src 'self'; style-src 'unsafe-inline';">
          <title>Login Failed - LearnDuels</title>
          <style>
            body {
              font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
              display: flex;
              justify-content: center;
              align-items: center;
              min-height: 100vh;
              margin: 0;
              background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
            }
            .container {
              background: white;
              padding: 2.5rem;
              border-radius: 16px;
              box-shadow: 0 10px 40px rgba(0,0,0,0.2);
              text-align: center;
              max-width: 500px;
            }
            h1 { color: #E53935; font-size: 28px; }
            .error-icon { font-size: 4rem; color: #E53935; margin-bottom: 1rem; }
            .error-message {
              background: #fff5f5;
              border-left: 4px solid #E53935;
              padding: 1.25rem;
              margin: 1.5rem 0;
              text-align: left;
              color: #742a2a;
              border-radius: 8px;
            }
            a {
              display: inline-block;
              background: #E53935;
              color: white;
              padding: 12px 24px;
              border-radius: 8px;
              text-decoration: none;
              margin-top: 1rem;
            }
            a:hover { background: #C62828; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="error-icon">✕</div>
            <h1>Login Failed</h1>
            <div class="error-message">
              <strong>Error:</strong> ${error.message}
            </div>
            <p>Please try again or contact support if the problem persists.</p>
            <a href="${webAppUrl}/#/login">Back to Login</a>
          </div>
        </body>
      </html>
    `);
  }
}

/**
 * Handle Google OAuth for Mobile (Native Sign-In)
 * Route: POST /api/auth/google/mobile
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
async function handleGoogleMobileAuth(req, res) {
  const { accessToken, idToken } = req.body;

  try {
    if (!accessToken && !idToken) {
      return res.status(400).json({
        success: false,
        message: 'Missing Google access token or ID token',
      });
    }

    // Process Google mobile authentication
    const result = await googleAuthService.handleGoogleMobileAuth(accessToken, idToken);

    res.json({
      success: true,
      message: 'Google authentication successful',
      data: result,
    });
  } catch (error) {
    console.error('Google mobile auth error:', error);
    res.status(401).json({
      success: false,
      message: error.message || 'Google authentication failed',
    });
  }
}

module.exports = {
  getGoogleAuthUrl,
  handleGoogleCallback,
  handleGoogleMobileAuth,
};
