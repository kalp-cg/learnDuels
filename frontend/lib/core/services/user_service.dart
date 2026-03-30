import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import 'api_service.dart';

final userServiceProvider = Provider<UserService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return UserService(apiService.client);
});

class UserService {
  final Dio _dio;

  UserService(this._dio);

  Future<Map<String, dynamic>?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) {
      debugPrint('❌ No access token found in getProfile');
      throw Exception('Not logged in. Please sign in again.');
    }

    try {
      final response = await _dio.get(
        ApiConstants.me,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>?;
      }
      throw Exception(response.data['message'] ?? 'Failed to load profile');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Token expired or invalid — clear it so user is prompted to re-login
        await prefs.remove('accessToken');
        await prefs.remove('refreshToken');
        throw Exception('Session expired. Please log in again.');
      }
      debugPrint('Error getting profile: ${e.message}');
      throw Exception('Network error. Check your connection.');
    } catch (e) {
      debugPrint('Error getting profile: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getUserStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      final response = await _dio.get(
        '${ApiConstants.users}/me/stats',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.data['success']) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user stats: $e');
      return null;
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      final response = await _dio.put(
        '${ApiConstants.users}/update',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return response.data['success'] == true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    }
  }

  /// Upload avatar image (for local file uploads)
  /// Returns the new avatar URL if successful, null otherwise
  Future<String?> uploadAvatar(Uint8List bytes, String filename) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      final formData = FormData.fromMap({
        'avatar': MultipartFile.fromBytes(bytes, filename: filename),
      });

      final response = await _dio.post(
        '${ApiConstants.users}/avatar',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.data['success'] == true) {
        return response.data['data']?['avatarUrl'];
      }
      return null;
    } catch (e) {
      debugPrint('Error uploading avatar: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserById(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      final response = await _dio.get(
        '${ApiConstants.users}/$id',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.data['success']) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  /// Follow a user
  Future<Map<String, dynamic>> followUser(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      final response = await _dio.post(
        '${ApiConstants.users}/$userId/follow',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return {
        'success': response.data['success'] == true,
        'status': response.data['data']?['status'] ?? 'unknown',
        'message': response.data['message'] ?? 'Request sent',
      };
    } catch (e) {
      debugPrint('Error following user: $e');
      return {
        'success': false,
        'status': 'error',
        'message': 'Failed to send follow request',
      };
    }
  }

  /// Unfollow a user
  Future<bool> unfollowUser(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      final response = await _dio.delete(
        '${ApiConstants.users}/$userId/follow',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return response.data['success'] == true;
    } catch (e) {
      debugPrint('Error unfollowing user: $e');
      return false;
    }
  }

  /// Get user's followers list
  Future<List<dynamic>> getFollowers(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      final response = await _dio.get(
        '${ApiConstants.users}/$userId/followers',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.data['success']) {
        return response.data['data'] ?? [];
      }
      return [];
    } catch (e) {
      debugPrint('Error getting followers: $e');
      return [];
    }
  }

  /// Get user's following list
  Future<List<dynamic>> getFollowing(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      final response = await _dio.get(
        '${ApiConstants.users}/$userId/following',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.data['success']) {
        return response.data['data'] ?? [];
      }
      return [];
    } catch (e) {
      debugPrint('Error getting following: $e');
      return [];
    }
  }

  /// Get pending follow requests (received)
  Future<List<dynamic>> getPendingFollowRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      debugPrint('📥 Fetching follow requests...');

      final response = await _dio.get(
        '${ApiConstants.users}/follow-requests',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      debugPrint('✅ Follow requests response: ${response.data}');

      if (response.data['success']) {
        return response.data['data'] ?? [];
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error getting follow requests: $e');
      if (e is DioException) {
        debugPrint('Response data: ${e.response?.data}');
        debugPrint('Status code: ${e.response?.statusCode}');
      }
      return [];
    }
  }

  /// Accept follow request
  Future<bool> acceptFollowRequest(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      final response = await _dio.post(
        '${ApiConstants.users}/$userId/follow/accept',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return response.data['success'] == true;
    } catch (e) {
      debugPrint('Error accepting follow request: $e');
      return false;
    }
  }

  /// Decline follow request
  Future<bool> declineFollowRequest(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      final response = await _dio.post(
        '${ApiConstants.users}/$userId/follow/decline',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return response.data['success'] == true;
    } catch (e) {
      debugPrint('Error declining follow request: $e');
      return false;
    }
  }

  /// Search users
  Future<List<dynamic>> searchUsers(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      final response = await _dio.get(
        '${ApiConstants.users}/search?q=$query',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.data['success']) {
        return response.data['data'] ?? [];
      }
      return [];
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }
}
