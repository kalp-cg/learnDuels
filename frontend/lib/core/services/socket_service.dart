import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

final socketServiceProvider = Provider<SocketService>((ref) {
  return SocketService();
});

class SocketService {
  io.Socket? _socket;
  io.Socket? _duelSocket;
  bool _isConnected = false;
  bool _isDuelConnecting = false;

  bool get isConnected => _isConnected;
  io.Socket? get socket => _socket;
  io.Socket? get duelSocket => _duelSocket;

  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) return;

    // Extract base URL without /api
    final baseUrl = ApiConstants.baseUrl.replaceAll('/api', '');

    // Main Socket (Chat, Notifications)
    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      debugPrint('✅ Main Socket connected');
      _isConnected = true;
    });

    _socket!.onDisconnect((_) {
      debugPrint('❌ Main Socket disconnected');
      _isConnected = false;
    });

    _socket!.onError((data) => debugPrint('Main Socket error: $data'));

    // Connect to Duel Namespace
    connectDuel();
  }

  Future<void> connectDuel() async {
    if ((_duelSocket != null && _duelSocket!.connected) || _isDuelConnecting) {
      return;
    }

    _isDuelConnecting = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      if (token == null) {
        _isDuelConnecting = false;
        return;
      }

      final baseUrl = ApiConstants.baseUrl.replaceAll('/api', '');
      final duelUrl = '$baseUrl/duel'; // Namespace URL

      debugPrint('🔌 Connecting to Duel Socket: $duelUrl');

      _duelSocket = io.io(
        duelUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setAuth({'token': token})
            .build(),
      );

      _duelSocket!.connect();

      _duelSocket!.onConnect((_) {
        debugPrint('⚔️ Duel Socket connected');
        _isDuelConnecting = false;
      });

      _duelSocket!.onDisconnect((_) {
        debugPrint('⚔️ Duel Socket disconnected');
        _isDuelConnecting = false;
      });

      _duelSocket!.onError((data) {
        debugPrint('Duel Socket error: $data');
        _isDuelConnecting = false;
      });
    } catch (e) {
      debugPrint('Error connecting to duel socket: $e');
      _isDuelConnecting = false;
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _duelSocket?.disconnect();
    _duelSocket = null;
    _isConnected = false;
  }

  void emit(String event, dynamic data) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit(event, data);
    } else {
      // ... existing reconnect logic ...
    }
  }

  // Emit to Duel Namespace
  void emitDuel(String event, dynamic data) {
    if (_duelSocket != null && _duelSocket!.connected) {
      _duelSocket!.emit(event, data);
    } else {
      debugPrint(
        '⚠️ Duel Socket not connected for $event - Attempting reconnect...',
      );
      connectDuel().then((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_duelSocket != null && _duelSocket!.connected) {
            debugPrint('✅ Reconnected Duel! Emitting $event');
            _duelSocket!.emit(event, data);
          }
        });
      });
    }
  }

  void on(String event, Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  // Listen on Duel Namespace
  void onDuel(String event, Function(dynamic) handler) {
    _duelSocket?.on(event, handler);
  }

  void off(String event, [Function(dynamic)? handler]) {
    _socket?.off(event, handler);
  }

  void offDuel(String event, [Function(dynamic)? handler]) {
    _duelSocket?.off(event, handler);
  }

  // Duel-specific methods
  void joinDuel(int duelId) {
    emit('joinDuel', {'duelId': duelId});
  }

  void joinSpectator(int duelId, {String? roomId}) {
    emit('spectator:join', {'duelId': duelId, 'roomId': roomId});
  }

  void leaveSpectator(String roomId) {
    emit('spectator:leave', {'roomId': roomId});
  }

  void leaveDuel(int duelId) {
    emit('leaveDuel', {'duelId': duelId});
  }

  void submitDuelAnswer(int duelId, int questionId, dynamic answer) {
    emit('submitAnswer', {
      'duelId': duelId,
      'questionId': questionId,
      'answer': answer,
    });
  }

  void onDuelUpdate(Function(dynamic) handler) {
    on('duelUpdate', handler);
  }

  void onDuelFinished(Function(dynamic) handler) {
    on('duelFinished', handler);
  }

  void onOpponentAnswer(Function(dynamic) handler) {
    on('opponentAnswer', handler);
  }

  void onDuelStarted(Function(dynamic) handler) {
    on('duelStarted', handler);
  }

  /// Update user profile in socket (call after profile changes)
  void updateUserProfile({String? avatarUrl, String? fullName}) {
    emit('user:updateProfile', {'avatarUrl': avatarUrl, 'fullName': fullName});
  }
}
