import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/user_service.dart';
import '../../core/services/socket_service.dart';
import '../friends/friends_screen.dart';

class FollowRequestsScreen extends ConsumerStatefulWidget {
  const FollowRequestsScreen({super.key});

  @override
  ConsumerState<FollowRequestsScreen> createState() =>
      _FollowRequestsScreenState();
}

class _FollowRequestsScreenState extends ConsumerState<FollowRequestsScreen> {
  List<dynamic> _requests = [];
  bool _isLoading = true;
  final Set<int> _processingIds = {};

  late Function(dynamic) _notificationHandler;

  @override
  void initState() {
    super.initState();
    _notificationHandler = (data) {
      if (data['type'] == 'follow_request') {
        if (mounted) {
          _loadRequests(); // Reload list to show new request
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${data['message']}'),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Refresh',
                onPressed: _loadRequests,
              ),
            ),
          );
        }
      }
    };
    _loadRequests();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    final socketService = ref.read(socketServiceProvider);
    socketService.on('notification', _notificationHandler);
  }

  @override
  void dispose() {
    final socketService = ref.read(socketServiceProvider);
    socketService.off('notification', _notificationHandler);
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);

    try {
      final userService = ref.read(userServiceProvider);
      final requests = await userService.getPendingFollowRequests();

      if (mounted) {
        setState(() {
          _requests = requests;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading requests: $e')));
      }
    }
  }

  Future<void> _acceptRequest(int userId) async {
    setState(() => _processingIds.add(userId));

    try {
      final userService = ref.read(userServiceProvider);
      final success = await userService.acceptFollowRequest(userId);

      if (success && mounted) {
        setState(() {
          _requests.removeWhere((req) => req['id'] == userId);
          _processingIds.remove(userId);
        });

        // Refresh friends list to show new friend
        ref.invalidate(friendsProvider);
        ref.invalidate(allUsersProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Follow request accepted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processingIds.remove(userId));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _declineRequest(int userId) async {
    setState(() => _processingIds.add(userId));

    try {
      final userService = ref.read(userServiceProvider);
      final success = await userService.declineFollowRequest(userId);

      if (success && mounted) {
        setState(() {
          _requests.removeWhere((req) => req['id'] == userId);
          _processingIds.remove(userId);
        });

        // Refresh user list to update follow status
        ref.invalidate(allUsersProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Follow request declined'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processingIds.remove(userId));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Follow Requests')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No pending requests',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadRequests,
              child: ListView.builder(
                itemCount: _requests.length,
                padding: const EdgeInsets.all(8),
                itemBuilder: (context, index) {
                  final request = _requests[index];
                  final userId = request['id'];
                  final isProcessing = _processingIds.contains(userId);

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: request['avatarUrl'] != null
                            ? NetworkImage(request['avatarUrl'])
                            : null,
                        child: request['avatarUrl'] == null
                            ? Text(
                                (request['fullName'] ?? 'U')[0].toUpperCase(),
                              )
                            : null,
                      ),
                      title: Text(request['fullName'] ?? 'Unknown'),
                      subtitle: Text(request['email'] ?? ''),
                      trailing: isProcessing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  ),
                                  onPressed: () => _acceptRequest(userId),
                                  tooltip: 'Accept',
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.cancel,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _declineRequest(userId),
                                  tooltip: 'Decline',
                                ),
                              ],
                            ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
