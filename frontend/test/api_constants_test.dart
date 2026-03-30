import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_new/core/constants/api_constants.dart';

void main() {
  group('ApiConstants', () {
    test('baseUrl ends with /api', () {
      expect(ApiConstants.baseUrl.endsWith('/api'), isTrue);
    });

    test('core endpoints are stable', () {
      expect(ApiConstants.login, '/auth/login');
      expect(ApiConstants.register, '/auth/signup');
      expect(ApiConstants.me, '/auth/me');
      expect(ApiConstants.topics, '/topics');
      expect(ApiConstants.duels, '/duels');
      expect(ApiConstants.notifications, '/notifications');
    });
  });
}
