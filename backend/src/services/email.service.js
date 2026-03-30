const nodemailer = require('nodemailer');
const config = require('../config/env');

/**
 * Email Service
 * Handles sending emails for password reset, welcome messages, etc.
 */

class EmailService {
  constructor() {
    this.transporter = null;
    this.initializeTransporter();
  }

  initializeTransporter() {
    if (process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS) {
      this.transporter = nodemailer.createTransport({
        host: process.env.SMTP_HOST,
        port: process.env.SMTP_PORT || 587,
        secure: process.env.SMTP_SECURE === 'true', // true for 465, false for other ports
        auth: {
          user: process.env.SMTP_USER,
          pass: process.env.SMTP_PASS,
        },
      });
      console.log('✅ Email Service initialized with SMTP');
    } else {
      console.log('⚠️ Email Service: SMTP credentials missing. Emails will be logged to console (Dev Mode).');
    }
  }

  /**
   * Send an email
   * @param {string} to - Recipient email
   * @param {string} subject - Email subject
   * @param {string} html - Email body (HTML)
   */
  async sendEmail(to, subject, html) {
    if (this.transporter) {
      try {
        const info = await this.transporter.sendMail({
          from: process.env.SMTP_FROM || '"LearnDuels" <noreply@learnduels.com>',
          to,
          subject,
          html,
        });
        console.log(`📧 Email sent to ${to}: ${info.messageId}`);
        return true;
      } catch (error) {
        console.error('❌ Failed to send email:', error);
        return false;
      }
    } else {
      // Dev Mode: Log to console
      console.log('---------------------------------------------------');
      console.log(`📧 [DEV MODE] Email to: ${to}`);
      console.log(`Subject: ${subject}`);
      console.log('Body:');
      console.log(html);
      console.log('---------------------------------------------------');
      return true;
    }
  }

  /**
   * Send password reset email
   * @param {string} to - Recipient email
   * @param {string} resetToken - Reset token
   */
  async sendPasswordReset(to, resetToken) {
    const resetUrl = `${process.env.FRONTEND_URL || 'http://localhost:3000'}/reset-password?token=${resetToken}`;
    
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2>Reset Your Password</h2>
        <p>You requested a password reset for your LearnDuels account.</p>
        <p>Click the button below to reset your password. This link is valid for 1 hour.</p>
        <a href="${resetUrl}" style="display: inline-block; background-color: #4CAF50; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px; margin: 20px 0;">Reset Password</a>
        <p>If you didn't request this, please ignore this email.</p>
        <p>Or copy this link: ${resetUrl}</p>
      </div>
    `;

    return this.sendEmail(to, 'Reset Your Password - LearnDuels', html);
  }
}

module.exports = new EmailService();
