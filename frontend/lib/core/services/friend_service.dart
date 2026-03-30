import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import 'api_service.dart';

final friendServiceProvider = Provider<FriendService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return FriendService(apiService.client);
});

class FriendService {
  final Dio _dio;

  FriendService(this._dio);

  Future<List<dynamic>> getUsers({
    int page = 1,
    String search = '',
    String sortBy = 'newest',
    int limit = 20,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/users',
        queryParameters: {
          'page': page,
          'search': search,
          'sortBy': sortBy,
          'limit': limit,
        },
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
      );

      if (response.data['success']) {
        return response.data['data'] ?? [];
      }
      return [];
    } catch (e) {
      debugPrint('Error getting users: $e');
      return [];
    }
  }

  Future<List<dynamic>> getFollowing({int page = 1}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/users/me/following',
        queryParameters: {'page': page},
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
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

  Future<List<dynamic>> getFollowers({int page = 1}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/users/me/followers',
        queryParameters: {'page': page},
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
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

  Future<bool> followUser(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      final response = await _dio.post(
        '${ApiConstants.baseUrl}/users/$userId/follow',
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
      );

      return response.data['success'] ?? false;
    } catch (e) {
      debugPrint('Error following user: $e');
      return false;
    }
  }

  Future<bool> unfollowUser(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      // Backend uses DELETE /:id/follow (not POST to /unfollow)
      final response = await _dio.delete(
        '${ApiConstants.baseUrl}/users/$userId/follow',
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
      );

      return response.data['success'] ?? false;
    } catch (e) {
      debugPrint('Error unfollowing user: $e');
      return false;
    }
  }

  Future<List<dynamic>> searchUsers(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/users/search',
        queryParameters: {'q': query},
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
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

  Future<List<dynamic>> getRecommendations({int limit = 10}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/recommendations/users',
        queryParameters: {'limit': limit},
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
      );

      if (response.data['success']) {
        return response.data['data'] ?? [];
      }
      return [];
    } catch (e) {
      debugPrint('Error getting recommendations: $e');
      // Fallback to popular users
      return getUsers(sortBy: 'popular');
    }
  }
}
