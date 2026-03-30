import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/user_service.dart';
import '../../widgets/custom_button.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final int userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  String? _followStatus; // pending, accepted, or null

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      final userService = ref.read(userServiceProvider);
      final profile = await userService.getUserById(widget.userId);

      if (mounted && profile != null) {
        setState(() {
          _userProfile = profile;
          _isFollowing = profile['isFollowing'] ?? false;
          _followStatus = profile['followStatus']; // Get the follow status
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    }
  }

  Future<void> _toggleFollow() async {
    setState(() => _isFollowLoading = true);

    try {
      final userService = ref.read(userServiceProvider);
      bool success;
      String message = '';

      // If already following or request is pending, unfollow/cancel
      if (_isFollowing || _followStatus == 'pending') {
        success = await userService.unfollowUser(widget.userId);
        if (_isFollowing) {
          message = success ? 'Unfollowed user' : 'Error unfollowing';
        } else {
          message = success ? 'Request cancelled' : 'Error cancelling request';
        }

        if (success && mounted) {
          setState(() {
            _isFollowing = false;
            _followStatus = null;
            if (_userProfile != null && _isFollowing) {
              final currentCount = _userProfile!['followersCount'] ?? 0;
              _userProfile!['followersCount'] = currentCount > 0
                  ? currentCount - 1
                  : 0;
            }
          });
        }
      } else {
        // Send new follow request
        final result = await userService.followUser(widget.userId);
        success = result['success'];
        message = result['message'] ?? 'Follow request sent';

        if (success && mounted) {
          setState(() {
            _followStatus = result['status']; // Should be 'pending'
          });
        }
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }

  String _getFollowButtonText() {
    if (_isFollowing) {
      return 'Unfollow';
    } else if (_followStatus == 'pending') {
      return 'Cancel Request';
    } else {
      return 'Follow';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_userProfile == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('User not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_userProfile!['username'] ?? 'Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar and Name
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: _userProfile!['avatarUrl'] != null
                      ? NetworkImage(_userProfile!['avatarUrl'])
                      : null,
                  child: _userProfile!['avatarUrl'] == null
                      ? Text(
                          (_userProfile!['fullName'] ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(fontSize: 32),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  _userProfile!['fullName'] ?? 'Unknown',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  '@${_userProfile!['username'] ?? ''}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
                if (_userProfile!['bio'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _userProfile!['bio'],
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Follow Button
          CustomButton(
            text: _getFollowButtonText(),
            isLoading: _isFollowLoading,
            onPressed: _toggleFollow,
            backgroundColor: _isFollowing
                ? Colors.grey
                : (_followStatus == 'pending' ? Colors.orange : null),
          ),
          const SizedBox(height: 24),

          // Stats Grid
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn(
                    'Level',
                    '${_userProfile!['level'] ?? 0}',
                    Icons.star,
                  ),
                  _buildStatColumn(
                    'XP',
                    '${_userProfile!['xp'] ?? 0}',
                    Icons.bolt,
                  ),
                  _buildStatColumn(
                    'Rating',
                    '${_userProfile!['rating'] ?? 1200}',
                    Icons.emoji_events,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Social Stats
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn(
                    'Followers',
                    '${_userProfile!['followersCount'] ?? 0}',
                    Icons.people,
                  ),
                  _buildStatColumn(
                    'Following',
                    '${_userProfile!['followingCount'] ?? 0}',
                    Icons.person_add,
                  ),
                  _buildStatColumn(
                    'Quizzes',
                    '${_userProfile!['quizzesCompleted'] ?? 0}',
                    Icons.quiz,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }
}
