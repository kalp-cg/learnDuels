import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'core/constants/api_constants.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/auth_callback_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/duel/topic_selection_screen.dart';
import 'screens/duel/duel_screen.dart';
import 'screens/duel/result_screen.dart';
import 'screens/quiz/practice_screen.dart';
import 'screens/quiz/create_question_screen.dart';
import 'screens/quiz/create_quiz_set_screen.dart';
import 'screens/main_screen.dart';
import 'screens/challenge/send_challenge_screen.dart';
import 'screens/challenge/pending_challenges_screen.dart';
import 'screens/admin/admin_screen.dart';
import 'screens/feed/feed_screen.dart';
import 'screens/onboarding/interests_screen.dart';
import 'screens/profile/follow_requests_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    debugPrint('✅ Firebase Initialized');
  } catch (e) {
    debugPrint(
      '⚠️ Firebase Initialization Failed (Check google-services.json): $e',
    );
  }

  if (!kIsWeb && Platform.isAndroid) {
    try {
      // Fetch all supported display modes
      final modes = await FlutterDisplayMode.supported;

      // Find the mode with the highest refresh rate
      // If multiple modes have the same highest refresh rate, pick the one with the highest resolution
      final bestMode = modes.reduce((a, b) {
        if (a.refreshRate > b.refreshRate) return a;
        if (b.refreshRate > a.refreshRate) return b;
        // Same refresh rate, check resolution
        if ((a.width * a.height) > (b.width * b.height)) return a;
        return b;
      });

      // Set the preferred mode
      await FlutterDisplayMode.setPreferredMode(bestMode);
      debugPrint('🚀 High Refresh Rate Enabled: ${bestMode.refreshRate}Hz');
    } catch (e) {
      debugPrint('⚠️ Failed to set high refresh rate: $e');
    }
  }

  debugPrint('🚀 App Starting...');
  debugPrint('🌐 kIsWeb: $kIsWeb');
  debugPrint('🔗 Base URL: ${ApiConstants.baseUrl}');
  runApp(const ProviderScope(child: LearnDuelsApp()));
}

class LearnDuelsApp extends ConsumerWidget {
  const LearnDuelsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'LearnDuels',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.academicTheme,
      initialRoute: '/splash',
      onGenerateRoute: (settings) {
        // Handle auth callback with query parameters
        if (settings.name?.startsWith('/auth-callback') == true) {
          return MaterialPageRoute(
            builder: (context) => const AuthCallbackScreen(),
            settings: settings,
          );
        }

        // Handle other routes
        final routes = {
          '/splash': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignupScreen(),
          '/home': (context) => const MainScreen(),
          '/topics': (context) => const TopicSelectionScreen(),
          '/duel': (context) => const DuelScreen(),
          '/result': (context) => const ResultScreen(),
          '/leaderboard': (context) => const MainScreen(initialIndex: 1),
          '/profile': (context) => const MainScreen(initialIndex: 2),
          '/practice': (context) => const PracticeScreen(),
          '/create-question': (context) => const CreateQuestionScreen(),
          '/send-challenge': (context) => const SendChallengeScreen(),
          '/challenges': (context) => const PendingChallengesScreen(),
          '/admin': (context) => const AdminScreen(),
          '/feed': (context) => const FeedScreen(),
          '/interests': (context) => const InterestsScreen(),
          '/create-quiz-set': (context) => const CreateQuizSetScreen(),
          '/follow-requests': (context) => const FollowRequestsScreen(),
        };

        final builder = routes[settings.name];
        if (builder != null) {
          return MaterialPageRoute(builder: builder, settings: settings);
        }

        return null;
      },
    );
  }
}
