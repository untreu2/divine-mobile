// ABOUTME: Tests for video feed item tap navigation to specific video indices
// ABOUTME: Validates URL navigation when tapping inactive videos in the feed

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/services/visibility_tracker.dart';
import 'package:openvine/widgets/video_feed_item.dart';

void main() {
  group('VideoFeedItem Navigation Tests', () {
    late List<VideoEvent> testVideos;

    setUp(() {
      // Create test video events
      final baseTime = DateTime.now();
      testVideos = List.generate(
        5,
        (i) => VideoEvent(
          id: 'video_$i',
          pubkey: 'test_pubkey',
          createdAt: baseTime.subtract(Duration(hours: i)).millisecondsSinceEpoch ~/ 1000,
          content: 'Test video $i',
          timestamp: baseTime.subtract(Duration(hours: i)),
          videoUrl: 'https://example.com/video_$i.mp4',
          thumbnailUrl: 'https://example.com/thumb_$i.jpg',
        ),
      );
    });

    testWidgets('Tapping inactive video in home feed navigates to /home/:index',
        (WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/home/0',
        routes: [
          GoRoute(
            path: '/home/:index',
            builder: (context, state) {
              final index = int.parse(state.pathParameters['index'] ?? '0');
              return Scaffold(
                body: Text('Home Index: $index'),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Use Noop visibility tracker to prevent timer leaks in tests
            visibilityTrackerProvider.overrideWithValue(NoopVisibilityTracker()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Create VideoFeedItem for video at index 2 (inactive)
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visibilityTrackerProvider.overrideWithValue(NoopVisibilityTracker()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => Scaffold(
              body: VideoFeedItem(
                video: testVideos[2],
                index: 2,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the inactive video
      await tester.tap(find.byType(VideoFeedItem));
      await tester.pumpAndSettle();

      // Verify navigation to /home/2
      expect(router.routeInformationProvider.value.uri.toString(), '/home/2');
    });

    testWidgets('Tapping inactive video in explore feed navigates to /explore/:index',
        (WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/explore/0',
        routes: [
          GoRoute(
            path: '/explore/:index',
            builder: (context, state) {
              final index = int.parse(state.pathParameters['index'] ?? '0');
              return Scaffold(
                body: Text('Explore Index: $index'),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visibilityTrackerProvider.overrideWithValue(NoopVisibilityTracker()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Create VideoFeedItem for video at index 3 (inactive)
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visibilityTrackerProvider.overrideWithValue(NoopVisibilityTracker()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => Scaffold(
              body: VideoFeedItem(
                video: testVideos[3],
                index: 3,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the inactive video
      await tester.tap(find.byType(VideoFeedItem));
      await tester.pumpAndSettle();

      // Verify navigation to /explore/3
      expect(router.routeInformationProvider.value.uri.toString(), '/explore/3');
    });

    testWidgets('Tapping inactive video in profile feed navigates to /profile/:npub/:index',
        (WidgetTester tester) async {
      const testNpub = 'npub1test123';
      final router = GoRouter(
        initialLocation: '/profile/$testNpub/0',
        routes: [
          GoRoute(
            path: '/profile/:npub/:index',
            builder: (context, state) {
              final npub = state.pathParameters['npub'];
              final index = int.parse(state.pathParameters['index'] ?? '0');
              return Scaffold(
                body: Text('Profile $npub Index: $index'),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visibilityTrackerProvider.overrideWithValue(NoopVisibilityTracker()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Create VideoFeedItem for video at index 1 (inactive)
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visibilityTrackerProvider.overrideWithValue(NoopVisibilityTracker()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => Scaffold(
              body: VideoFeedItem(
                video: testVideos[1],
                index: 1,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the inactive video
      await tester.tap(find.byType(VideoFeedItem));
      await tester.pumpAndSettle();

      // Verify navigation to /profile/:npub/1
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/profile/$testNpub/1',
      );
    });

    testWidgets('Tapping inactive video in hashtag feed navigates to /hashtag/:tag/:index',
        (WidgetTester tester) async {
      const testTag = 'funny';
      final router = GoRouter(
        initialLocation: '/hashtag/$testTag/0',
        routes: [
          GoRoute(
            path: '/hashtag/:tag/:index',
            builder: (context, state) {
              final tag = state.pathParameters['tag'];
              final index = int.parse(state.pathParameters['index'] ?? '0');
              return Scaffold(
                body: Text('Hashtag #$tag Index: $index'),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visibilityTrackerProvider.overrideWithValue(NoopVisibilityTracker()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Create VideoFeedItem for video at index 4 (inactive)
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visibilityTrackerProvider.overrideWithValue(NoopVisibilityTracker()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => Scaffold(
              body: VideoFeedItem(
                video: testVideos[4],
                index: 4,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the inactive video
      await tester.tap(find.byType(VideoFeedItem));
      await tester.pumpAndSettle();

      // Verify navigation to /hashtag/funny/4
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/hashtag/$testTag/4',
      );
    });

    testWidgets('Tapping active video does not navigate (pauses/plays instead)',
        (WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/home/0',
        routes: [
          GoRoute(
            path: '/home/:index',
            builder: (context, state) {
              final index = int.parse(state.pathParameters['index'] ?? '0');
              return Scaffold(
                body: Text('Home Index: $index'),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visibilityTrackerProvider.overrideWithValue(NoopVisibilityTracker()),
            // Mock active video provider to make video 0 active
            isVideoActiveProvider('video_0').overrideWith((ref) => true),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => Scaffold(
              body: VideoFeedItem(
                video: testVideos[0],
                index: 0,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final initialLocation = router.routeInformationProvider.value.uri.toString();

      // Tap the active video
      await tester.tap(find.byType(VideoFeedItem));
      await tester.pumpAndSettle();

      // Verify navigation did NOT occur (location unchanged)
      expect(
        router.routeInformationProvider.value.uri.toString(),
        initialLocation,
      );
    });

    testWidgets('Navigation works with index 0', (WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/explore/5',
        routes: [
          GoRoute(
            path: '/explore/:index',
            builder: (context, state) {
              final index = int.parse(state.pathParameters['index'] ?? '0');
              return Scaffold(
                body: Text('Explore Index: $index'),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visibilityTrackerProvider.overrideWithValue(NoopVisibilityTracker()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => Scaffold(
              body: VideoFeedItem(
                video: testVideos[0],
                index: 0,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the inactive video at index 0
      await tester.tap(find.byType(VideoFeedItem));
      await tester.pumpAndSettle();

      // Verify navigation to /explore/0
      expect(router.routeInformationProvider.value.uri.toString(), '/explore/0');
    });
  });
}
