// ABOUTME: Tests for computed active video provider (reactive architecture)
// ABOUTME: Verifies active video is computed from page context and app state, not set imperatively

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/computed_active_video_provider.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/providers/app_providers.dart';

void main() {
  group('Computed Active Video Provider', () {
    late ProviderContainer container;
    late VideoEventService videoService;

    setUp(() {
      // Create REAL VideoEventService with minimal fake dependencies
      final fakeNostrService = FakeNostrService();
      final fakeSubscriptionManager = FakeSubscriptionManager();

      videoService = VideoEventService(fakeNostrService, subscriptionManager: fakeSubscriptionManager);

      // Inject test videos directly into the service's discovery list
      // Use realistic 64-character hex IDs like Nostr
      final testVideos = [
        VideoEvent(
          id: '1111111111111111111111111111111111111111111111111111111111111111',
          pubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          content: 'Video 1',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/v1.mp4',
        ),
        VideoEvent(
          id: '2222222222222222222222222222222222222222222222222222222222222222',
          pubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          content: 'Video 2',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/v2.mp4',
        ),
        VideoEvent(
          id: '3333333333333333333333333333333333333333333333333333333333333333',
          pubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          content: 'Video 3',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/v3.mp4',
        ),
      ];

      // Use the service's test helper to inject videos
      videoService.injectTestVideos(testVideos);

      container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWith((ref) => videoService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('activeVideoProvider returns null when app backgrounded', () {
      // SETUP: Set page context to explore screen, page 0
      container.read(currentPageContextProvider.notifier).setContext('explore', 0, '1111111111111111111111111111111111111111111111111111111111111111');

      // VERIFY: Initially returns video 1 (app is foreground by default)
      expect(container.read(activeVideoProvider), equals('1111111111111111111111111111111111111111111111111111111111111111'));

      // ACT: Background the app
      container.read(appForegroundProvider.notifier).setForeground(false);

      // VERIFY: Active video becomes null
      expect(container.read(activeVideoProvider), isNull,
          reason: 'Active video should be null when app is backgrounded');
    });

    test('activeVideoProvider returns correct video ID from context', () {
      // SETUP: No context set initially
      expect(container.read(activeVideoProvider), isNull,
          reason: 'Should be null with no context');

      // ACT: Set context to explore screen, page 0
      container.read(currentPageContextProvider.notifier).setContext('explore', 0, '1111111111111111111111111111111111111111111111111111111111111111');

      // VERIFY: Returns video 1
      expect(container.read(activeVideoProvider), equals('1111111111111111111111111111111111111111111111111111111111111111'));

      // ACT: Change to page 1
      container.read(currentPageContextProvider.notifier).setContext('explore', 1, '2222222222222222222222222222222222222222222222222222222222222222');

      // VERIFY: Returns video 2
      expect(container.read(activeVideoProvider), equals('2222222222222222222222222222222222222222222222222222222222222222'));

      // ACT: Change to page 2
      container.read(currentPageContextProvider.notifier).setContext('explore', 2, '3333333333333333333333333333333333333333333333333333333333333333');

      // VERIFY: Returns video 3
      expect(container.read(activeVideoProvider), equals('3333333333333333333333333333333333333333333333333333333333333333'));
    });

    test('activeVideoProvider returns videoId directly from context', () {
      // With new architecture, activeVideoProvider simply returns pageContext.videoId
      // Validation of page indexes is VideoPageView's responsibility, not activeVideoProvider's

      // ACT: Set context with any page index and videoId
      container.read(currentPageContextProvider.notifier).setContext('explore', -1, 'video-at-negative-index');

      // VERIFY: Returns the videoId that was set, regardless of page index validity
      expect(container.read(activeVideoProvider), equals('video-at-negative-index'),
          reason: 'activeVideoProvider returns videoId directly from context, no index validation');

      // ACT: Set context with high page index
      container.read(currentPageContextProvider.notifier).setContext('explore', 999, 'video-at-high-index');

      // VERIFY: Returns the videoId that was set
      expect(container.read(activeVideoProvider), equals('video-at-high-index'),
          reason: 'activeVideoProvider returns videoId directly, no bounds checking');
    });

    test('activeVideoProvider returns null when context is cleared', () {
      // SETUP: Set context
      container.read(currentPageContextProvider.notifier).setContext('explore', 0, '1111111111111111111111111111111111111111111111111111111111111111');
      expect(container.read(activeVideoProvider), equals('1111111111111111111111111111111111111111111111111111111111111111'));

      // ACT: Clear context
      container.read(currentPageContextProvider.notifier).clear();

      // VERIFY: Returns null
      expect(container.read(activeVideoProvider), isNull,
          reason: 'Should return null when context is cleared');
    });

    test('isVideoActiveProvider only true for active video', () {
      // SETUP: Set context to page 1 (video 2)
      container.read(currentPageContextProvider.notifier).setContext('explore', 1, '2222222222222222222222222222222222222222222222222222222222222222');

      // VERIFY: Only video 2 is active
      expect(container.read(isVideoActiveProvider('1111111111111111111111111111111111111111111111111111111111111111')), isFalse);
      expect(container.read(isVideoActiveProvider('2222222222222222222222222222222222222222222222222222222222222222')), isTrue);
      expect(container.read(isVideoActiveProvider('3333333333333333333333333333333333333333333333333333333333333333')), isFalse);

      // ACT: Change to page 0
      container.read(currentPageContextProvider.notifier).setContext('explore', 0, '1111111111111111111111111111111111111111111111111111111111111111');

      // VERIFY: Only video 1 is active
      expect(container.read(isVideoActiveProvider('1111111111111111111111111111111111111111111111111111111111111111')), isTrue);
      expect(container.read(isVideoActiveProvider('2222222222222222222222222222222222222222222222222222222222222222')), isFalse);
      expect(container.read(isVideoActiveProvider('3333333333333333333333333333333333333333333333333333333333333333')), isFalse);
    });

    test('activeVideoProvider returns videoId regardless of screenId', () {
      // With new architecture, activeVideoProvider doesn't validate screenId
      // It simply returns the videoId from pageContext

      // ACT: Set context with unknown screenId
      container.read(currentPageContextProvider.notifier).setContext('unknown_screen', 0, 'video-from-unknown-screen');

      // VERIFY: Returns the videoId that was set, regardless of screenId validity
      expect(container.read(activeVideoProvider), equals('video-from-unknown-screen'),
          reason: 'activeVideoProvider returns videoId directly, no screenId validation');
    });

    test('activeVideoProvider notifies listeners when context changes', () {
      final states = <String?>[];

      // SETUP: Listen to provider changes BEFORE making changes
      final sub = container.listen(
        activeVideoProvider,
        (previous, next) {
          states.add(next);
        },
        fireImmediately: false,
      );

      // ACT: Set context to page 0
      container.read(currentPageContextProvider.notifier).setContext('explore', 0, '1111111111111111111111111111111111111111111111111111111111111111');

      // Force provider to rebuild
      container.read(activeVideoProvider);

      // ACT: Change to page 1
      container.read(currentPageContextProvider.notifier).setContext('explore', 1, '2222222222222222222222222222222222222222222222222222222222222222');

      // Force provider to rebuild
      container.read(activeVideoProvider);

      // ACT: Background app
      container.read(appForegroundProvider.notifier).setForeground(false);

      // Force provider to rebuild
      container.read(activeVideoProvider);

      // VERIFY: Listener was notified for each change
      expect(states, equals(['1111111111111111111111111111111111111111111111111111111111111111', '2222222222222222222222222222222222222222222222222222222222222222', null]),
          reason: 'Should notify listeners for each state change');

      sub.close();
    });
  });
}

// Minimal fake implementations for testing - just enough to construct VideoEventService
class FakeNostrService implements INostrService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeSubscriptionManager implements SubscriptionManager {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
