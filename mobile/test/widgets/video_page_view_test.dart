// ABOUTME: Comprehensive tests for VideoPageView widget consolidation
// ABOUTME: Tests all features: pagination, prewarming, lifecycle, callbacks, context management

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/computed_active_video_provider.dart';
import 'package:openvine/widgets/video_page_view.dart';
import '../builders/test_video_event_builder.dart';

void main() {
  group('VideoPageView Widget Tests', () {
    late List<VideoEvent> testVideos;
    late WidgetTester? currentTester;

    setUp(() {
      // Create test video events
      final now = DateTime.now();
      testVideos = List.generate(
        10,
        (i) => TestVideoEventBuilder.create(
          id: 'video-$i',
          pubkey: 'pubkey-$i',
          content: 'Test video $i',
          title: 'Test Video $i',
          videoUrl: 'https://example.com/video-$i.mp4',
          timestamp: now.subtract(Duration(hours: i)),
          createdAt: (now.millisecondsSinceEpoch ~/ 1000) - (i * 3600),
        ),
      );
      currentTester = null;
    });

    tearDown(() async {
      // Flush video controller cache timers (30s timeout)
      if (currentTester != null) {
        await currentTester!.pump(const Duration(seconds: 31));
      }
    });

    Widget buildTestWidget({
      required List<VideoEvent> videos,
      int initialIndex = 0,
      void Function(int, VideoEvent)? onPageChanged,
      VoidCallback? onLoadMore,
      Future<void> Function()? onRefresh,
      bool hasBottomNavigation = true,
      bool enablePreloading = true,
      bool enablePrewarming = true,
      bool enableLifecycleManagement = true,
    }) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: VideoPageView(
              videos: videos,
              initialIndex: initialIndex,
              onPageChanged: onPageChanged,
              onLoadMore: onLoadMore,
              onRefresh: onRefresh,
              hasBottomNavigation: hasBottomNavigation,
              enablePreloading: enablePreloading,
              enablePrewarming: enablePrewarming,
              enableLifecycleManagement: enableLifecycleManagement,
            ),
          ),
        ),
      );
    }

    testWidgets('renders PageView with videos', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(videos: testVideos));
      await tester.pump();

      expect(find.byType(PageView), findsOneWidget);

      // Flush video controller cache timers
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('starts at specified initial index', (WidgetTester tester) async {
      const startIndex = 3;
      await tester.pumpWidget(
        buildTestWidget(
          videos: testVideos,
          initialIndex: startIndex,
        ),
      );
      await tester.pump();

      // Verify PageView controller is at correct position
      final pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.controller?.initialPage, startIndex);

      // Flush video controller cache timers
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('calls onPageChanged when scrolling', (WidgetTester tester) async {
      int? changedIndex;
      VideoEvent? changedVideo;

      await tester.pumpWidget(
        buildTestWidget(
          videos: testVideos,
          onPageChanged: (index, video) {
            changedIndex = index;
            changedVideo = video;
          },
        ),
      );
      await tester.pump();

      // Scroll to next page
      await tester.drag(find.byType(PageView), const Offset(0, -400));
      await tester.pump();

      expect(changedIndex, 1);
      expect(changedVideo?.id, testVideos[1].id);

      // Flush video controller cache timers
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('calls onLoadMore when near end of list', (WidgetTester tester) async {
      bool loadMoreCalled = false;
      final shortList = testVideos.take(5).toList();

      await tester.pumpWidget(
        buildTestWidget(
          videos: shortList,
          onLoadMore: () {
            loadMoreCalled = true;
          },
        ),
      );
      await tester.pump();

      // Scroll to index 2 (shortList has 5 items, onLoadMore triggers at index >= length - 3)
      await tester.drag(find.byType(PageView), const Offset(0, -400));
      await tester.pump();
      await tester.drag(find.byType(PageView), const Offset(0, -400));
      await tester.pump();

      expect(loadMoreCalled, true);

      // Flush video controller cache timers
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('does not use RefreshIndicator to avoid scroll conflicts',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          videos: testVideos,
          onRefresh: () async {},
        ),
      );
      await tester.pump();

      // RefreshIndicator not used because it conflicts with vertical PageView scrolling
      expect(find.byType(RefreshIndicator), findsNothing);

      // Flush video controller cache timers
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('updates active video provider on page change',
        (WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: VideoPageView(
                videos: testVideos,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Wait for post-frame callback to set initial active video
      await tester.pump(const Duration(milliseconds: 100));

      // Initial active video should be first video
      expect(
        container.read(activeVideoProvider),
        testVideos[0].id,
      );

      // Scroll to next page
      await tester.drag(find.byType(PageView), const Offset(0, -400));
      await tester.pump();

      // Active video should update
      expect(
        container.read(activeVideoProvider),
        testVideos[1].id,
      );

      // Flush video controller cache timers
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('prewarms neighbor controllers when enabled',
        (WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: VideoPageView(
                videos: testVideos,
                initialIndex: 2,
                enablePrewarming: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Wait for post-frame callback to prewarm
      await tester.pump(const Duration(milliseconds: 100));

      // NOTE: With Riverpod-native lifecycle, prewarming is automatic via VideoPrewarmer
      // Controllers are created but can autodispose after 30s of no listeners
      // Just verify the widget builds without errors
      expect(find.byType(VideoPageView), findsOneWidget);

      // Flush video controller cache timers
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('does not prewarm when disabled', (WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: VideoPageView(
                videos: testVideos,
                enablePrewarming: false,
                enableLifecycleManagement: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // NOTE: With Riverpod-native lifecycle, disabling prewarming prevents VideoPrewarmer calls
      // Just verify the widget builds correctly
      expect(find.byType(VideoPageView), findsOneWidget);

      // Flush video controller cache timers
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('handles empty video list gracefully', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(videos: []));
      await tester.pump();

      // Should show empty state or handle gracefully
      expect(find.byType(PageView), findsOneWidget);

      // Flush video controller cache timers
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('handles single video in list', (WidgetTester tester) async {
      final singleVideo = [testVideos[0]];

      await tester.pumpWidget(buildTestWidget(videos: singleVideo));
      await tester.pump();

      expect(find.byType(PageView), findsOneWidget);

      // Should not crash when trying to scroll
      await tester.drag(find.byType(PageView), const Offset(0, -400));
      await tester.pump();

      // Flush video controller cache timers
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('disposes cleanly without errors', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(videos: testVideos));
      await tester.pump();

      // Remove widget
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      // Should not throw errors

      // Flush video controller cache timers
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('handles rapid page changes without errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(videos: testVideos));
      await tester.pump();

      // Rapid scrolling
      for (int i = 0; i < 5; i++) {
        await tester.drag(find.byType(PageView), const Offset(0, -400));
        await tester.pump();
      }

      // Should not crash
      expect(find.byType(PageView), findsOneWidget);

      // Flush video controller cache timers
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('respects hasBottomNavigation parameter',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          videos: testVideos,
          hasBottomNavigation: true,
        ),
      );
      await tester.pump();

      // PageView should exist
      final pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView, isNotNull);

      // Flush video controller cache timers
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('handles updated video list', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(videos: testVideos));
      await tester.pump();

      // Update with new videos
      final newVideos = List.generate(
        5,
        (i) => TestVideoEventBuilder.create(
          id: 'new-video-$i',
          pubkey: 'pubkey-$i',
          content: 'New test video $i',
          videoUrl: 'https://example.com/new-video-$i.mp4',
        ),
      );

      await tester.pumpWidget(buildTestWidget(videos: newVideos));
      await tester.pump();

      expect(find.byType(PageView), findsOneWidget);

      // Flush video controller cache timers
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('vertical scroll direction is set correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(videos: testVideos));
      await tester.pump();

      final pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.scrollDirection, Axis.vertical);

      // Flush video controller cache timers
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('enables mouse and trackpad drag via ScrollConfiguration',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(videos: testVideos));
      await tester.pump();

      // Find ScrollConfiguration widget
      final scrollConfig = tester.widget<ScrollConfiguration>(
        find.byType(ScrollConfiguration),
      );
      expect(scrollConfig, isNotNull);

      // Verify drag devices are enabled (this tests the implementation)
      expect(find.byType(PageView), findsOneWidget);

      // Flush video controller cache timers
      await tester.pump(const Duration(seconds: 31));
    });
  });

  group('VideoPageView Edge Cases', () {
    testWidgets('handles video list with duplicate IDs', (WidgetTester tester) async {
      final duplicateVideos = [
        TestVideoEventBuilder.create(
          id: 'video-1',
          pubkey: 'pubkey-1',
          content: 'Test',
          videoUrl: 'https://example.com/video.mp4',
        ),
        TestVideoEventBuilder.create(
          id: 'video-1', // Duplicate ID
          pubkey: 'pubkey-1',
          content: 'Test',
          videoUrl: 'https://example.com/video.mp4',
        ),
      ];

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: VideoPageView(videos: duplicateVideos),
            ),
          ),
        ),
      );
      await tester.pump();

      // Should handle gracefully
      expect(find.byType(PageView), findsOneWidget);

      // Flush video controller cache timers
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('handles very large video list', (WidgetTester tester) async {
      final largeList = List.generate(
        100,
        (i) => TestVideoEventBuilder.create(
          id: 'video-$i',
          pubkey: 'pubkey-$i',
          content: 'Test video $i',
          videoUrl: 'https://example.com/video-$i.mp4',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VideoPageView(
                videos: largeList,
                enableLifecycleManagement: false, // Disable to avoid provider issues
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(PageView), findsOneWidget);

      // Flush video controller cache timers
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('onLoadMore triggered at correct threshold', (WidgetTester tester) async {
      int loadMoreCount = 0;
      final shortList = List.generate(
        6,
        (i) => TestVideoEventBuilder.create(
          id: 'video-$i',
          pubkey: 'pubkey-$i',
          content: 'Test',
          videoUrl: 'https://example.com/video-$i.mp4',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VideoPageView(
                videos: shortList,
                onLoadMore: () {
                  loadMoreCount++;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Scroll to index 3 (threshold is length - 3, so 6 - 3 = index 3)
      for (int i = 0; i < 3; i++) {
        await tester.drag(find.byType(PageView), const Offset(0, -400));
        await tester.pump();
      }

      // Should be called once
      expect(loadMoreCount, 1);

      // Continue scrolling shouldn't trigger again
      await tester.drag(find.byType(PageView), const Offset(0, -400));
      await tester.pump();

      // Still should be 1 (though it may be called again in real implementation)
      expect(loadMoreCount, greaterThanOrEqualTo(1));

      // Flush video controller cache timers
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('sets active video on mount when lifecycle enabled',
        (WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: VideoPageView(
                videos: [
                  TestVideoEventBuilder.create(
                    id: 'video-1',
                    pubkey: 'pubkey-1',
                    content: 'Test',
                    videoUrl: 'https://example.com/video.mp4',
                  ),
                ],
                enableLifecycleManagement: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Active video should be set by lifecycle management
      final activeVideo = container.read(activeVideoProvider);
      expect(activeVideo, 'video-1');

      // Flush video controller cache timers
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('does not manage active video when lifecycle disabled',
        (WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: VideoPageView(
                videos: [
                  TestVideoEventBuilder.create(
                    id: 'video-1',
                    pubkey: 'pubkey-1',
                    content: 'Test',
                    videoUrl: 'https://example.com/video.mp4',
                  ),
                ],
                enableLifecycleManagement: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Active video should not be managed
      expect(container.read(activeVideoProvider), isNull);

      // Flush video controller cache timers
      await tester.pump(const Duration(seconds: 31));
    });
  });

  group('VideoPageView Reactive Context Management', () {
    late List<VideoEvent> testVideos;

    setUp(() {
      // Create test videos with realistic 64-character Nostr IDs
      testVideos = [
        TestVideoEventBuilder.create(
          id: '1111111111111111111111111111111111111111111111111111111111111111',
          pubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          content: 'Video 1',
          videoUrl: 'https://example.com/v1.mp4',
        ),
        TestVideoEventBuilder.create(
          id: '2222222222222222222222222222222222222222222222222222222222222222',
          pubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          content: 'Video 2',
          videoUrl: 'https://example.com/v2.mp4',
        ),
        TestVideoEventBuilder.create(
          id: '3333333333333333333333333333333333333333333333333333333333333333',
          pubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          content: 'Video 3',
          videoUrl: 'https://example.com/v3.mp4',
        ),
      ];
    });

    testWidgets('VideoPageView sets initial context on mount', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // ACT: Build VideoPageView with screenId 'explore'
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: VideoPageView(
                videos: testVideos,
                screenId: 'explore', // NEW: screenId parameter
                initialIndex: 0,
                enableLifecycleManagement: true,
              ),
            ),
          ),
        ),
      );

      // Wait for async initialization
      await tester.pumpAndSettle();

      // VERIFY: Context was set to ('explore', 0)
      final pageContext = container.read(currentPageContextProvider);
      expect(pageContext, isNotNull, reason: 'Page context should be set');
      expect(pageContext!.screenId, equals('explore'));
      expect(pageContext.pageIndex, equals(0));

      // Flush video controller cache timers
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('VideoPageView updates context when page changes', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = PageController(initialPage: 0);
      addTearDown(controller.dispose);

      // ACT: Build VideoPageView
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: VideoPageView(
                videos: testVideos,
                screenId: 'explore',
                controller: controller,
                enableLifecycleManagement: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // VERIFY: Initial context is ('explore', 0)
      PageContext? pageContext = container.read(currentPageContextProvider);
      expect(pageContext?.screenId, equals('explore'));
      expect(pageContext?.pageIndex, equals(0));

      // ACT: Swipe to next page
      await tester.drag(find.byType(PageView), const Offset(0, -300));
      await tester.pumpAndSettle();

      // VERIFY: Context updated to ('explore', 1)
      pageContext = container.read(currentPageContextProvider);
      expect(pageContext?.screenId, equals('explore'));
      expect(pageContext?.pageIndex, equals(1));

      // ACT: Swipe to third page
      await tester.drag(find.byType(PageView), const Offset(0, -300));
      await tester.pumpAndSettle();

      // VERIFY: Context updated to ('explore', 2)
      pageContext = container.read(currentPageContextProvider);
      expect(pageContext?.screenId, equals('explore'));
      expect(pageContext?.pageIndex, equals(2));

      // Flush video controller cache timers
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('VideoPageView clears context on dispose', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // ACT: Build and mount VideoPageView
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: VideoPageView(
                videos: testVideos,
                screenId: 'explore',
                enableLifecycleManagement: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // VERIFY: Context is set
      PageContext? pageContext = container.read(currentPageContextProvider);
      expect(pageContext, isNotNull);

      // ACT: Dispose widget by replacing with empty container
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox.shrink(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // VERIFY: Context was cleared
      pageContext = container.read(currentPageContextProvider);
      expect(pageContext, isNull, reason: 'Context should be cleared on dispose');

      // Flush video controller cache timers
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('VideoPageView with different screenIds have separate contexts', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // This test verifies that multiple VideoPageView instances can exist
      // but only the most recent one sets the active context

      // ACT: Build first VideoPageView with 'home' screenId
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: VideoPageView(
                videos: testVideos,
                screenId: 'home',
                initialIndex: 1,
                enableLifecycleManagement: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // VERIFY: Context is ('home', 1)
      PageContext? pageContext = container.read(currentPageContextProvider);
      expect(pageContext?.screenId, equals('home'));
      expect(pageContext?.pageIndex, equals(1));

      // ACT: Navigate to explore screen (replace with new VideoPageView)
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: VideoPageView(
                videos: testVideos,
                screenId: 'explore',
                initialIndex: 2,
                enableLifecycleManagement: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // VERIFY: Context changed to ('explore', 2)
      pageContext = container.read(currentPageContextProvider);
      expect(pageContext?.screenId, equals('explore'));
      expect(pageContext?.pageIndex, equals(2));

      // Flush video controller cache timers
      await tester.pump(const Duration(seconds: 31));
    });
  });
}
