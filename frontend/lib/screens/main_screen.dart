import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/nav_provider.dart';
import '../providers/notification_provider.dart';
import '../core/services/socket_service.dart';
import '../core/services/push_notification_service.dart';
import '../core/theme.dart';
import 'home/home_screen.dart';
import 'leaderboard/leaderboard_screen.dart';
import 'profile/profile_screen.dart';
import 'friends/friends_screen.dart';
import 'duel/duel_screen.dart';
import 'chat/general_chat_screen.dart';
import 'notifications/notification_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  const MainScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  late Function(dynamic) _invitationHandler;
  late Function(dynamic) _notificationHandler;
  late Function(dynamic) _duelAcceptedHandler;
  late Function(dynamic) _challengeStartedHandler;
  SocketService? _socketService;

  @override
  void initState() {
    super.initState();

    _invitationHandler = (data) {
      if (!mounted) return;
      _showInvitationDialog(data);
    };

    _notificationHandler = (data) {
      if (!mounted) return;

      // Increment unread count
      ref.read(unreadNotificationCountProvider.notifier).state++;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            data['message'] ?? 'New notification',
            style: GoogleFonts.firaCode(fontWeight: FontWeight.w500),
          ),
          backgroundColor: AppTheme.surfaceLight,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'View',
            textColor: AppTheme.primary,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
            },
          ),
        ),
      );
      // Refresh notification list if needed
      ref.invalidate(notificationsProvider);
    };

    _duelAcceptedHandler = (data) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DuelScreen()),
      );
    };

    _challengeStartedHandler = (data) {
      if (!mounted) return;
      // The data is already handled by DuelProvider which updates the state.
      // We just need to navigate.
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DuelScreen()),
      );
    };

    // Initialize the provider with the passed index
    Future.microtask(() {
      ref.read(bottomNavIndexProvider.notifier).state = widget.initialIndex;
      _initSocket();
    });
  }

  void _initSocket() async {
    _socketService = ref.read(socketServiceProvider);
    await _socketService?.connect();

    // Initialize Push Notifications
    try {
      await PushNotificationService().initialize();
    } catch (e) {
      debugPrint('Push notification init error: $e');
    }

    // Listen for invitations
    _socketService?.on('duel:invitation_received', _invitationHandler);

    // Listen for generic notifications
    _socketService?.on('notification', _notificationHandler);

    // Listen for duel start (after acceptance)
    _socketService?.on('duel:accepted', _duelAcceptedHandler);

    // Listen for challenge start (instant duel)
    _socketService?.on('challenge:started', _challengeStartedHandler);
  }

  void _showInvitationDialog(dynamic data) {
    // Extract challenger name safely
    final challengerName = data['challenger'] != null
        ? (data['challenger']['fullName'] ??
              data['challenger']['username'] ??
              'Someone')
        : 'Someone';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.sports_esports_rounded,
                color: AppTheme.secondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Duel Challenge!',
              style: GoogleFonts.firaCode(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Text(
          '$challengerName wants to duel you!',
          style: GoogleFonts.firaCode(
            color: AppTheme.textSecondary,
            fontSize: 15,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Decline
              final socketService = ref.read(socketServiceProvider);
              socketService.emit('challenge:decline', {
                'challengeId': data['challengeId'],
              });
              Navigator.pop(context);
            },
            child: Text(
              'Decline',
              style: GoogleFonts.firaCode(
                color: AppTheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextButton(
              onPressed: () async {
                // Accept
                final socketService = ref.read(socketServiceProvider);
                socketService.emit('challenge:accept', {
                  'challengeId': data['challengeId'],
                });
                Navigator.pop(context);

                // Navigation will be handled by 'challenge:started' listener
                // in DuelProvider or MainScreen
              },
              child: Text(
                'Accept',
                style: GoogleFonts.firaCode(
                  color: AppTheme.background,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _socketService?.off('duel:invitation_received', _invitationHandler);
    _socketService?.off('notification', _notificationHandler);
    _socketService?.off('duel:accepted', _duelAcceptedHandler);
    _socketService?.off('challenge:started', _challengeStartedHandler);
    _socketService?.disconnect();
    super.dispose();
  }

  final List<Widget> _screens = const [
    HomeScreen(),
    LeaderboardScreen(),
    GeneralChatScreen(),
    FriendsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(bottomNavIndexProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: IndexedStack(index: currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: const Border(
            top: BorderSide(color: AppTheme.border, width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  0,
                  Icons.home_outlined,
                  Icons.home_rounded,
                  'HOME',
                  currentIndex,
                ),
                _buildNavItem(
                  1,
                  Icons.leaderboard_outlined,
                  Icons.leaderboard_rounded,
                  'RANK',
                  currentIndex,
                ),
                _buildNavItem(
                  2,
                  Icons.chat_bubble_outline_rounded,
                  Icons.chat_bubble_rounded,
                  'CHAT',
                  currentIndex,
                ),
                _buildNavItem(
                  3,
                  Icons.people_outline,
                  Icons.people_rounded,
                  'NETWORK',
                  currentIndex,
                ),
                _buildNavItem(
                  4,
                  Icons.person_outline,
                  Icons.person_rounded,
                  'PROFILE',
                  currentIndex,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
    int currentIndex,
  ) {
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () {
        ref.read(bottomNavIndexProvider.notifier).state = index;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppTheme.primary : AppTheme.textMuted,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.firaCode(
                color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 9,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
