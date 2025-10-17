// ABOUTME: Route-aware feed providers that select correct video source per route
// ABOUTME: Enables router-driven screens to reactively get route-appropriate data

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/home_feed_provider.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/state/video_feed_state.dart';

/// Home feed state (follows only)
/// Returns AsyncValue<VideoFeedState> for route-aware home screen
final videosForHomeRouteProvider =
    Provider<AsyncValue<VideoFeedState>>((ref) {
  final contextAsync = ref.watch(pageContextProvider);

  return contextAsync.when(
    data: (ctx) {
      if (ctx.type != RouteType.home) {
        // Not on home route - return loading
        return const AsyncValue.loading();
      }
      // On home route - return home feed state
      return ref.watch(homeFeedProvider);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Explore feed state (discovery/all videos)
/// Returns AsyncValue<VideoFeedState> for route-aware explore screen
/// Sorted by loop count (descending) to match ExploreScreen tabs
final videosForExploreRouteProvider =
    Provider<AsyncValue<VideoFeedState>>((ref) {
  final contextAsync = ref.watch(pageContextProvider);

  return contextAsync.when(
    data: (ctx) {
      if (ctx.type != RouteType.explore) {
        // Not on explore route - return loading
        return const AsyncValue.loading();
      }
      // On explore route - watch video events and convert to VideoFeedState
      final eventsAsync = ref.watch(videoEventsProvider);
      return eventsAsync.when(
        data: (videos) {
          // Sort by loop count (descending) to match ExploreScreen tabs
          final sortedVideos = List<VideoEvent>.from(videos);
          sortedVideos.sort((a, b) {
            final aLoops = a.originalLoops ?? 0;
            final bLoops = b.originalLoops ?? 0;
            return bLoops.compareTo(aLoops); // Descending order
          });
          return AsyncValue.data(
            VideoFeedState(
              videos: sortedVideos,
              hasMoreContent: true,
              lastUpdated: DateTime.now(),
            ),
          );
        },
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});
