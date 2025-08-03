// ABOUTME: Riverpod provider for content curation with reactive updates
// ABOUTME: Manages only editor picks - trending/popular handled by infinite feeds

import 'package:openvine/models/curation_set.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/state/curation_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'curation_providers.g.dart';


/// Main curation provider that manages curated content sets
@riverpod
class Curation extends _$Curation {
  @override
  CurationState build() {
    // Auto-refresh when video events change
    ref.listen(videoEventsProvider, (previous, next) {
      // Only refresh if we have new video events
      if (next.hasValue &&
          previous?.valueOrNull?.length != next.valueOrNull?.length) {
        _refreshCurationSets();
      }
    });

    // Initialize with empty state
    _initializeCuration();

    return const CurationState(
      editorsPicks: [],
      isLoading: true,
    );
  }

  Future<void> _initializeCuration() async {
    try {
      final service = ref.read(curationServiceProvider);

      Log.debug(
        'Curation: Initializing curation sets',
        name: 'CurationProvider',
        category: LogCategory.system,
      );

      // CurationService initializes itself in constructor
      // Just get the current data
      state = CurationState(
        editorsPicks: service.getVideosForSetType(CurationSetType.editorsPicks),
        isLoading: false,
      );

      Log.info(
        'Curation: Loaded ${state.editorsPicks.length} editor picks',
        name: 'CurationProvider',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Curation: Initialization error: $e',
        name: 'CurationProvider',
        category: LogCategory.system,
      );

      state = CurationState(
        editorsPicks: [],
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> _refreshCurationSets() async {
    final service = ref.read(curationServiceProvider);

    try {
      service.refreshIfNeeded();

      // Update state with refreshed data
      state = state.copyWith(
        editorsPicks: service.getVideosForSetType(CurationSetType.editorsPicks),
        error: null,
      );

      Log.debug(
        'Curation: Refreshed curation sets',
        name: 'CurationProvider',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Curation: Refresh error: $e',
        name: 'CurationProvider',
        category: LogCategory.system,
      );

      state = state.copyWith(error: e.toString());
    }
  }

  /// Refresh all curation sets (currently just Editor's Picks)
  Future<void> refreshAll() async {
    await _refreshCurationSets();
  }

  /// Force refresh all curation sets
  Future<void> forceRefresh() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true);

    try {
      final service = ref.read(curationServiceProvider);

      // Force refresh from remote
      await service.refreshCurationSets();

      // Update state
      state = CurationState(
        editorsPicks: service.getVideosForSetType(CurationSetType.editorsPicks),
        isLoading: false,
      );

      Log.info(
        'Curation: Force refreshed editor picks',
        name: 'CurationProvider',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Curation: Force refresh error: $e',
        name: 'CurationProvider',
        category: LogCategory.system,
      );

      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

/// Provider to check if curation is loading
@riverpod
bool curationLoading(Ref ref) =>
    ref.watch(curationProvider).isLoading;

/// Provider to get editor's picks
@riverpod
List<VideoEvent> editorsPicks(Ref ref) =>
    ref.watch(curationProvider.select((state) => state.editorsPicks));

/// Provider for analytics-based trending videos
@riverpod
class AnalyticsTrending extends _$AnalyticsTrending {
  @override
  List<VideoEvent> build() {
    // Return cached trending videos from service
    final service = ref.read(curationServiceProvider);
    return service.analyticsTrendingVideos;
  }

  /// Refresh trending videos from analytics API
  Future<void> refresh() async {
    final service = ref.read(curationServiceProvider);
    
    Log.info(
      'AnalyticsTrending: Refreshing trending videos from analytics API',
      name: 'AnalyticsTrendingProvider',
      category: LogCategory.system,
    );

    try {
      await service.refreshTrendingFromAnalytics();
      
      // Update state with new trending videos
      state = service.analyticsTrendingVideos;
      
      Log.info(
        'AnalyticsTrending: Loaded ${state.length} trending videos',
        name: 'AnalyticsTrendingProvider',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'AnalyticsTrending: Error refreshing: $e',
        name: 'AnalyticsTrendingProvider',
        category: LogCategory.system,
      );
      // Keep existing state on error
    }
  }

  /// Load more trending videos for pagination
  Future<void> loadMore() async {
    // For now, load more just triggers a refresh to get more content
    // In the future, this could be enhanced with proper pagination offset/cursor
    Log.info(
      'AnalyticsTrending: Loading more trending videos via refresh',
      name: 'AnalyticsTrendingProvider',
      category: LogCategory.system,
    );
    
    await refresh();
  }
}

/// Provider for analytics-based popular videos (same as trending for now)
@riverpod
class AnalyticsPopular extends _$AnalyticsPopular {
  @override
  List<VideoEvent> build() {
    // For now, popular videos use the same analytics data as trending
    // In the future, this could be enhanced with different time windows or metrics
    final service = ref.read(curationServiceProvider);
    return service.analyticsTrendingVideos;
  }

  /// Refresh popular videos from analytics API
  Future<void> refresh() async {
    final service = ref.read(curationServiceProvider);
    
    Log.info(
      'AnalyticsPopular: Refreshing popular videos from analytics API',
      name: 'AnalyticsPopularProvider',
      category: LogCategory.system,
    );

    try {
      await service.refreshTrendingFromAnalytics();
      
      // Update state with new popular videos (same as trending for now)
      state = service.analyticsTrendingVideos;
      
      Log.info(
        'AnalyticsPopular: Loaded ${state.length} popular videos',
        name: 'AnalyticsPopularProvider',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'AnalyticsPopular: Error refreshing: $e',
        name: 'AnalyticsPopularProvider',
        category: LogCategory.system,
      );
      // Keep existing state on error
    }
  }
}
