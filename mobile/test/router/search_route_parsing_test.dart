// ABOUTME: Tests for search route parsing and navigation
// ABOUTME: Verifies /search route is correctly parsed and returns RouteType.search

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/route_utils.dart';

void main() {
  group('Search route parsing', () {
    test('parseRoute recognizes /search path', () {
      final result = parseRoute('/search');

      expect(result.type, RouteType.search);
      expect(result.videoIndex, isNull);
      expect(result.npub, isNull);
      expect(result.hashtag, isNull);
    });

    test('buildRoute creates /search path for RouteType.search', () {
      const context = RouteContext(type: RouteType.search);

      final result = buildRoute(context);

      expect(result, '/search');
    });

    test('parseRoute handles root search path', () {
      // Verify search at root level without any path segments after
      final result = parseRoute('/search/');

      expect(result.type, RouteType.search);
    });
  });
}
