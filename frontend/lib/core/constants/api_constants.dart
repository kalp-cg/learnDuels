import 'package:flutter/foundation.dart';
import 'dart:io';

class ApiConstants {
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String _normalizeApiBaseUrl(String base) {
    final trimmed = base.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.endsWith('/api') ? trimmed : '$trimmed/api';
  }

  // Base URL - Update this with your actual backend URL
  // For Android Emulator use 10.0.2.2, for iOS use localhost
  static String get baseUrl {
    final override = _normalizeApiBaseUrl(_apiBaseUrlOverride);
    if (override.isNotEmpty) {
      return override;
    }

    // AWS Backend URL for testing
    // return 'https://app.codinggita.space/api';

    // Local development
    if (kIsWeb) {
      return 'http://localhost:4000/api';
    }
    // Android (physical device & emulator)
    // Physical device: use your PC's local network IP
    // Emulator: use 10.0.2.2
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:4000/api';
    }
    // iOS / Others
    return 'http://localhost:4000/api';
  }

  // Auth (Email/Password only - OAuth removed)
  static const String login = '/auth/login';
  static const String register = '/auth/signup';
  static const String me = '/auth/me';
  static const String refreshToken = '/auth/refresh-token';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String googleMobile = '/auth/google/mobile';

  // Topics (replaces Categories)
  static const String topics = '/topics';
  static const String popularTopics = '/topics/popular';
  static const String searchTopics = '/topics/search';

  // Questions
  static const String questions = '/questions';

  // Question Sets (replaces quizzes)
  static const String questionSets = '/question-sets';

  // Challenges (replaces duels)
  static const String challenges = '/challenges';
  static const String acceptChallenge = '/challenges/{id}/accept';
  static const String declineChallenge = '/challenges/{id}/decline';

  // Duels (for compatibility)
  static const String duels = '/duels';
  static const String duelMatchmaking = '/duels/matchmaking';

  // Attempts
  static const String attempts = '/attempts';

  // Leaderboard
  static const String leaderboard = '/leaderboard';

  // Users
  static const String users = '/users';
  static const String userProfile = '/users/profile';
  static const String userStats = '/users/stats';

  // Notifications
  static const String notifications = '/notifications';
  static const String registerDevice = '/notifications/register-device';
  static const String removeDevice = '/notifications/remove-device';

  // Recommendations (NEW)
  static const String recommendUsers = '/recommendations/users';
  static const String recommendTopics = '/recommendations/topics';
  static const String recommendQuestionSets = '/recommendations/question-sets';

  // Analytics (NEW)
  static const String analyticsDashboard = '/analytics/dashboard';
  static const String analyticsDau = '/analytics/dau';
  static const String analyticsChallenges = '/analytics/challenges';
  static const String analyticsQuizzes = '/analytics/quizzes';
  static const String analyticsEngagement = '/analytics/engagement';
  static const String analyticsTopicsPopular = '/analytics/topics/popular';

  // Spectator Mode (NEW)
  static const String spectateDuels = '/spectate/duels';
  static const String spectateDuelDetails = '/spectate/duels/{id}';
  static const String spectateSpectators = '/spectate/duels/{id}/spectators';

  // GDPR Compliance (NEW)
  static const String gdprExport = '/gdpr/export';
  static const String gdprDelete = '/gdpr/delete';
  static const String gdprAnonymize = '/gdpr/anonymize';
  static const String gdprActivities = '/gdpr/processing-activities';

  // Admin (if needed)
  static const String adminModeration = '/admin/moderation';
}
