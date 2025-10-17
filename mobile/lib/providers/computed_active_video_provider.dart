// ABOUTME: Computed active video provider using reactive architecture
// ABOUTME: Active video is derived from page context and app state, never set imperatively

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Page context - which screen and page are currently showing
class PageContext {
  final String screenId; // 'home', 'explore', 'profile:npub123', 'hashtag:funny'
  final int pageIndex;
  final String videoId; // The actual video being displayed at this index

  const PageContext({
    required this.screenId,
    required this.pageIndex,
    required this.videoId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PageContext &&
          runtimeType == other.runtimeType &&
          screenId == other.screenId &&
          pageIndex == other.pageIndex &&
          videoId == other.videoId;

  @override
  int get hashCode => screenId.hashCode ^ pageIndex.hashCode ^ videoId.hashCode;
}

/// Current page context notifier using Riverpod 2.0+ Notifier
class CurrentPageContextNotifier extends Notifier<PageContext?> {
  int _epoch = 0;
  int _pendingEpoch = -1;
  int get epoch => _epoch;

  @override
  PageContext? build() => null;

  void setContext(String screenId, int pageIndex, String videoId) {
    state = PageContext(screenId: screenId, pageIndex: pageIndex, videoId: videoId);
  }

  void clear() {
    state = null;
  }

  /// Announce that a new claim with this epoch is incoming (no state write)
  void announcePending(int claimEpoch, String screenId) {
    if (claimEpoch > _pendingEpoch) {
      _pendingEpoch = claimEpoch;
      debugPrint('[CTX] pending claim=$claimEpoch screen=$screenId pending=$_pendingEpoch');
      Log.info('CTX:pending'
               ' claim=$claimEpoch'
               ' screen=$screenId'
               ' pending=$_pendingEpoch',
               name: 'PageCtx', category: LogCategory.ui);
    }
  }

  /// Check if a claim epoch is outdated compared to pending or current epoch
  bool isOutdated(int claimEpoch) => claimEpoch < _pendingEpoch || claimEpoch < _epoch;

  /// Only set if caller's epoch is >= current epoch
  bool setIfNewer(String screenId, int pageIndex, String videoId, int claimEpoch) {
    final oldEpoch = _epoch;
    final accepted = claimEpoch >= _epoch;
    if (accepted) {
      _epoch = claimEpoch;
      state = PageContext(screenId: screenId, pageIndex: pageIndex, videoId: videoId);
    }
    debugPrint('[CTX] setIfNewer claim=$claimEpoch old=$oldEpoch->${_epoch} accepted=$accepted screen=$screenId idx=$pageIndex videoId=$videoId state=${state?.screenId}:${state?.pageIndex}:${state?.videoId}');
    Log.info('CTX:setIfNewer'
             ' claim=$claimEpoch'
             ' old=$oldEpoch->${_epoch}'
             ' accepted=$accepted'
             ' screen=$screenId idx=$pageIndex videoId=$videoId'
             ' state=${state?.screenId}:${state?.pageIndex}:${state?.videoId}',
             name: 'PageCtx', category: LogCategory.ui);
    return accepted;
  }

  /// Clear only if the epoch still matches (owner)
  bool clearIfOwner(int claimEpoch, String screenId) {
    if (isOutdated(claimEpoch)) {
      debugPrint('[CTX] clearIfOwner SKIP outdated claim=$claimEpoch epoch=$_epoch pending=$_pendingEpoch');
      Log.info('CTX:clearIfOwner SKIP outdated'
               ' claim=$claimEpoch epoch=$_epoch pending=$_pendingEpoch',
               name: 'PageCtx', category: LogCategory.ui);
      return false;
    }
    final isOwner = (_epoch == claimEpoch) && (state?.screenId == screenId);
    if (isOwner) state = null;
    debugPrint('[CTX] clearIfOwner claim=$claimEpoch epoch=$_epoch isOwner=$isOwner screen=$screenId state=${state?.screenId}:${state?.pageIndex}');
    Log.info('CTX:clearIfOwner'
             ' claim=$claimEpoch'
             ' epoch=$_epoch'
             ' isOwner=$isOwner'
             ' screen=$screenId'
             ' state=${state?.screenId}:${state?.pageIndex}',
             name: 'PageCtx', category: LogCategory.ui);
    return isOwner;
  }
}

/// Current page context provider
final currentPageContextProvider =
    NotifierProvider<CurrentPageContextNotifier, PageContext?>(
  CurrentPageContextNotifier.new,
);

/// Computed active video ID based on page context and app state
final activeVideoProvider = Provider<String?>((ref) {
  // Check app foreground state
  final isAppForeground = ref.watch(appForegroundProvider);
  if (!isAppForeground) return null;

  // Get current page context
  final pageContext = ref.watch(currentPageContextProvider);
  if (pageContext == null) return null;

  // Return the video ID directly from the page context
  // PageView screens know exactly which video they're showing via page context
  return pageContext.videoId;
});

/// Per-video active state (for efficient VideoFeedItem updates)
final isVideoActiveProvider = Provider.family<bool, String>((ref, videoId) {
  final activeVideoId = ref.watch(activeVideoProvider);
  return activeVideoId == videoId;
});
