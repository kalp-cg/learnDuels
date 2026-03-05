import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/socket_service.dart';
import '../../core/services/friend_service.dart';
import '../../providers/user_provider.dart';

class GeneralChatScreen extends ConsumerStatefulWidget {
  final String? initialMessage;
  const GeneralChatScreen({super.key, this.initialMessage});

  @override
  ConsumerState<GeneralChatScreen> createState() => _GeneralChatScreenState();
}

class _GeneralChatScreenState extends ConsumerState<GeneralChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _replyMessage;
  Map<String, dynamic>? _pinnedMessage;
  final Set<String> _typingUsers = {};
  Timer? _typingTimer;
  final ImagePicker _picker = ImagePicker();
  int _onlineUsers = 0;
  late final SocketService _socketService;

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage != null) {
      _messageController.text = widget.initialMessage!;
    }
    _socketService = ref.read(socketServiceProvider);
    _initSocket();
    _messageController.addListener(_onTextChanged);
  }

  void _initSocket() {
    final socketService = ref.read(socketServiceProvider);

    // Check if connected
    if (socketService.isConnected) {
      _setupChat(socketService);
    } else {
      // Retry after a short delay to allow MainScreen to initialize the socket
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _initSocket();
      });
    }
  }

  void _setupChat(SocketService socketService) {
    // Join the general chat room
    socketService.emit('chat:join', {});

    // Listen for reconnection to rejoin the room
    socketService.on('connect', (_) {
      if (mounted) {
        debugPrint('Reconnected to chat, rejoining room...');
        socketService.emit('chat:join', {});
      }
    });

    // Listen for incoming messages
    socketService.on('chat:message', (data) {
      if (mounted) {
        setState(() {
          _messages.add(Map<String, dynamic>.from(data));
        });
        _scrollToBottom();
      }
    });

    // Listen for chat history
    socketService.on('chat:history', (data) {
      if (mounted && data is List) {
        setState(() {
          _messages.clear();
          _messages.addAll(data.map((e) => Map<String, dynamic>.from(e)));
        });
        _scrollToBottom();
      }
    });

    // Listen for pinned message updates
    socketService.on('chat:pinned_message', (data) {
      if (mounted) {
        setState(() {
          _pinnedMessage = data != null
              ? Map<String, dynamic>.from(data)
              : null;
        });
      }
    });

    // Listen for typing events
    socketService.on('chat:typing', (data) {
      if (mounted && data != null) {
        final username = data['username'];
        final isTyping = data['isTyping'];
        setState(() {
          if (isTyping) {
            _typingUsers.add(username);
          } else {
            _typingUsers.remove(username);
          }
        });
      }
    });

    // Listen for user count
    socketService.on('chat:user_count', (data) {
      if (mounted && data != null) {
        setState(() {
          _onlineUsers = data['count'] ?? 0;
        });
      }
    });

    // Listen for message deletion
    socketService.on('chat:message_deleted', (data) {
      if (mounted && data != null) {
        final deletedId = data['messageId'];
        setState(() {
          _messages.removeWhere(
            (m) => m['id'].toString() == deletedId.toString(),
          );
        });
      }
    });
  }

  void _onTextChanged() {
    final socketService = ref.read(socketServiceProvider);
    if (!socketService.isConnected) return;

    if (_typingTimer?.isActive ?? false) _typingTimer!.cancel();

    socketService.emit('chat:typing', true);

    _typingTimer = Timer(const Duration(seconds: 2), () {
      socketService.emit('chat:typing', false);
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    if (_socketService.isConnected) {
      _socketService.emit('chat:typing', false);
      _socketService.emit('chat:leave', {});
      _socketService.off('chat:message');
      _socketService.off('chat:history');
      _socketService.off('chat:pinned_message');
      _socketService.off('chat:typing');
      _socketService.off('chat:user_count');
      _socketService.off('chat:message_deleted');
      _socketService.off('connect');
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage({
    String? attachmentUrl,
    String type = 'text',
  }) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && type == 'text') return;

    final socketService = ref.read(socketServiceProvider);

    if (!socketService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not connected to chat server. Retrying...'),
          backgroundColor: Colors.red,
        ),
      );
      _initSocket();
      return;
    }

    final messageData = {
      'message': text,
      'type': type,
      'attachmentUrl': attachmentUrl,
      'replyTo': _replyMessage,
    };

    socketService.emit('chat:send', messageData);

    _messageController.clear();
    setState(() {
      _replyMessage = null;
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        final String base64Image =
            'data:image/jpeg;base64,${base64Encode(bytes)}';
        _sendMessage(type: 'image', attachmentUrl: base64Image);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _pinMessage(Map<String, dynamic> msg) {
    final socketService = ref.read(socketServiceProvider);
    socketService.emit('chat:pin', msg);
  }

  void _unpinMessage() {
    final socketService = ref.read(socketServiceProvider);
    socketService.emit('chat:unpin', {});
  }

  void _deleteMessage(String messageId) {
    final socketService = ref.read(socketServiceProvider);
    socketService.emit('chat:delete', {'messageId': messageId});
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      // With reverse: true, 0.0 is the bottom (newest messages)
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Column(
          children: [
            const Text(
              'General Chat',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            Text(
              '$_onlineUsers online',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Please login to chat'));
          }
          final currentUserId = user['id'];

          return Column(
            children: [
              if (_pinnedMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  child: Row(
                    children: [
                      Icon(
                        Icons.push_pin,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pinned Message',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Text(
                              _pinnedMessage!['content'] ?? 'Image',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (user['role'] ==
                          'admin') // Only admin can unpin? Or anyone for now? Let's allow anyone for demo
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: _unpinMessage,
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: _messages.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.builder(
                        reverse: true,
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          // Calculate real index in _messages list (which is Oldest -> Newest)
                          final int realIndex = _messages.length - 1 - index;
                          final msg = _messages[realIndex];

                          // Robust comparison by converting both to string
                          final isMe =
                              msg['senderId'].toString() ==
                              currentUserId.toString();

                          // Show avatar if this is the first message (oldest, realIndex 0)
                          // or if the previous message (realIndex - 1) is from a different sender
                          final showAvatar =
                              realIndex == 0 ||
                              _messages[realIndex - 1]['senderId'].toString() !=
                                  msg['senderId'].toString();

                          // Date Header Logic
                          bool showDateHeader = false;
                          DateTime? currentMsgDate;

                          if (msg['timestamp'] != null) {
                            currentMsgDate = DateTime.parse(
                              msg['timestamp'],
                            ).toLocal();
                            if (realIndex == 0) {
                              showDateHeader = true;
                            } else {
                              final prevTimestamp =
                                  _messages[realIndex - 1]['timestamp'];
                              if (prevTimestamp != null) {
                                final prevMsgDate = DateTime.parse(
                                  prevTimestamp,
                                ).toLocal();
                                showDateHeader = !_isSameDay(
                                  currentMsgDate,
                                  prevMsgDate,
                                );
                              } else {
                                showDateHeader = true;
                              }
                            }
                          }

                          final messageBubble = _buildMessageBubble(
                            context,
                            msg,
                            isMe,
                            showAvatar,
                          );

                          if (showDateHeader && currentMsgDate != null) {
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16.0,
                                  ),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.light
                                            ? Colors.grey[300]
                                            : Colors.grey[800],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _formatDate(currentMsgDate),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                messageBubble,
                              ],
                            );
                          }

                          return messageBubble;
                        },
                      ),
              ),
              if (_typingUsers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 8,
                  ),
                  child: Text(
                    '${_typingUsers.join(", ")} is typing...',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ),
              _buildInputArea(context),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 40,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome to General Chat!',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Say hello to the community 👋',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  void _showUserProfileDialog(Map<String, dynamic> sender) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: sender['senderAvatar'] != null
                  ? NetworkImage(sender['senderAvatar'])
                  : null,
              child: sender['senderAvatar'] == null
                  ? Text((sender['senderName'] ?? '?')[0].toUpperCase())
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(sender['senderName'] ?? 'Unknown')),
          ],
        ),
        content: const Text('Do you want to follow this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await ref
                  .read(friendServiceProvider)
                  .followUser(sender['senderId']);
              if (!context.mounted) return;

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'Followed successfully!'
                        : 'Failed to follow (or already following)',
                  ),
                ),
              );
            },
            child: const Text('Follow'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    Map<String, dynamic> msg,
    bool isMe,
    bool showAvatar,
  ) {
    final isImage = msg['type'] == 'image';
    final replyTo = msg['replyTo'];

    return Dismissible(
      key: Key(msg['id'] ?? DateTime.now().toString()),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (direction) async {
        setState(() {
          _replyMessage = msg;
        });
        return false; // Don't dismiss
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Icon(Icons.reply, color: Theme.of(context).colorScheme.primary),
      ),
      child: GestureDetector(
        onLongPress: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.push_pin),
                  title: const Text('Pin Message'),
                  onTap: () {
                    Navigator.pop(context);
                    _pinMessage(msg);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.reply),
                  title: const Text('Reply'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _replyMessage = msg;
                    });
                  },
                ),
                if (isMe)
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text(
                      'Delete Message',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _deleteMessage(msg['id'].toString());
                    },
                  ),
              ],
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.only(top: showAvatar ? 16 : 4),
          child: Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                if (showAvatar)
                  GestureDetector(
                    onTap: () => _showUserProfileDialog(msg),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      backgroundImage: msg['senderAvatar'] != null
                          ? NetworkImage(msg['senderAvatar'])
                          : null,
                      child: msg['senderAvatar'] == null
                          ? Text(
                              (msg['senderName'] ?? '?')[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            )
                          : null,
                    ),
                  )
                else
                  const SizedBox(width: 32),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMe
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).brightness == Brightness.light
                        ? Colors.grey[200]
                        : Colors.grey[800],
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isMe && showAvatar)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: GestureDetector(
                            onTap: () => _showUserProfileDialog(msg),
                            child: Text(
                              msg['senderName'] ?? 'Unknown',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      if (replyTo != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border(
                              left: BorderSide(
                                color: isMe
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.primary,
                                width: 4,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                replyTo['senderName'] ?? 'Unknown',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isMe
                                      ? Colors.white70
                                      : Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              Text(
                                replyTo['content'] ?? 'Image',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isMe ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (isImage)
                        GestureDetector(
                          onTap: () {
                            // Open full screen image
                            showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                child: Image.network(msg['attachmentUrl']),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              msg['attachmentUrl'],
                              height: 200,
                              width: 200,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image),
                            ),
                          ),
                        )
                      else
                        MarkdownBody(
                          data: msg['content'] ?? '',
                          selectable: true,
                          onTapLink: (text, href, title) async {
                            if (href != null) {
                              if (!await launchUrl(Uri.parse(href))) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Could not launch URL'),
                                  ),
                                );
                              }
                            }
                          },
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              color: isMe
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface,
                              fontSize: 15,
                            ),
                            a: TextStyle(
                              color: isMe ? Colors.white : Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                            code: TextStyle(
                              backgroundColor: isMe
                                  ? Colors.black.withValues(alpha: 0.2)
                                  : Theme.of(context).brightness ==
                                        Brightness.light
                                  ? Colors.grey[300]
                                  : Colors.grey[900],
                              fontFamily: 'monospace',
                              fontSize: 14,
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: isMe
                                  ? Colors.black.withValues(alpha: 0.2)
                                  : Theme.of(context).brightness ==
                                        Brightness.light
                                  ? Colors.grey[300]
                                  : Colors.grey[900],
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTime(msg['timestamp']),
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.7)
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (_replyMessage != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.grey[200]
                      : Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 4,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Replying to ${_replyMessage!['senderName']}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _replyMessage!['content'] ?? 'Image',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        setState(() {
                          _replyMessage = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image_outlined),
                  onPressed: _pickImage,
                  color: Theme.of(context).colorScheme.primary,
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).dividerColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    onPressed: () => _sendMessage(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    final date = DateTime.parse(timestamp).toLocal();
    return DateFormat('h:mm a').format(date);
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) {
      return 'Today';
    } else if (dateToCheck == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, y').format(date);
    }
  }
}
