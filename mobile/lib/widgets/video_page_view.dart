// ABOUTME: Consolidated video feed PageView component with intelligent preloading
// ABOUTME: Provides consistent vertical scrolling behavior across home feed and explore screens

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/providers/computed_active_video_provider.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/services/video_prewarmer.dart';
import 'package:openvine/widgets/video_feed_item.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Consolidated video feed PageView widget
///
/// Provides consistent vertical scrolling video feed behavior with:
/// - Mouse/trackpad drag support (web + desktop)
/// - Touch gesture support (mobile)
/// - Intelligent prewarming of neighbor videos
/// - Optional preloading for upcoming videos
/// - Pull-to-refresh support
/// - Pagination callback when near end of list
class VideoPageView extends ConsumerStatefulWidget {
  const VideoPageView({
    super.key,
    required this.videos,
    this.controller,
    this.initialIndex = 0,
    this.hasBottomNavigation = true,
    this.enablePrewarming = true,
    this.enablePreloading = false,
    this.enableLifecycleManagement = true,
    this.screenId, // Screen ID for reactive context (e.g., 'home', 'explore', 'profile:npub123')
    this.contextTitle,
    this.onPageChanged,
    this.onLoadMore,
    this.onRefresh,
  });

  final List<VideoEvent> videos;
  final PageController? controller;
  final int initialIndex;
  final bool hasBottomNavigation;
  final bool enablePrewarming;
  final bool enablePreloading;
  final bool enableLifecycleManagement;
  final String? screenId; // Screen ID for reactive page context management
  final String? contextTitle; // Optional context title to display (e.g., "#funny")
  final void Function(int index, VideoEvent video)? onPageChanged;
  final VoidCallback? onLoadMore;
  final Future<void> Function()? onRefresh;

  @override
  ConsumerState<VideoPageView> createState() => _VideoPageViewState();
}

class _VideoPageViewState extends ConsumerState<VideoPageView> {
  late PageController _pageController;
  late VideoPrewarmer _prewarmer;
  CurrentPageContextNotifier? _contextNotifier; // Captured in initState for safe dispose access
  bool _isAppForeground = true; // Cached app foreground state
  int _currentIndex = 0;
  late int _claimEpoch; // Unique epoch for context ownership

  @override
  void initState() {
    super.initState();
    Log.debug('🎬 VideoPageView.initState: screenId=${widget.screenId}, enableLifecycle=${widget.enableLifecycleManagement}, initialIndex=${widget.initialIndex}',
        name: 'VideoPageView', category: LogCategory.video);

    _currentIndex = widget.initialIndex;
    _pageController = widget.controller ?? PageController(initialPage: widget.initialIndex);
    _prewarmer = ref.read(videoPrewarmerProvider);

    // Claim unique epoch for context ownership (microseconds ensures uniqueness)
    _claimEpoch = DateTime.now().microsecondsSinceEpoch;
    Log.debug('🎯 VideoPageView claimed epoch: $_claimEpoch for screenId=${widget.screenId}',
        name: 'VideoPageView', category: LogCategory.video);

    // Capture notifier and initial state values while widget is mounted
    if (widget.enableLifecycleManagement && widget.screenId != null) {
      _contextNotifier = ref.read(currentPageContextProvider.notifier);
      // Announce this widget's pending claim
      Log.debug('📢 VideoPageView announcing pending claim: epoch=$_claimEpoch, screenId=${widget.screenId}',
          name: 'VideoPageView', category: LogCategory.video);
      _contextNotifier!.announcePending(_claimEpoch, widget.screenId!);
    } else {
      Log.debug('⏭️ VideoPageView skipping context claim: enableLifecycle=${widget.enableLifecycleManagement}, screenId=${widget.screenId}',
          name: 'VideoPageView', category: LogCategory.video);
    }
    _isAppForeground = ref.read(appForegroundProvider);

    // Listen to app foreground state changes and update cached value
    ref.listenManual(appForegroundProvider, (prev, next) {
      _isAppForeground = next;
    });

    // Set initial page context if screenId is provided
    // Use Future.microtask to avoid modifying provider during build
    if (widget.enableLifecycleManagement && widget.screenId != null) {
      Future.microtask(() {
        if (!mounted) return;

        Log.debug('🔍 VideoPageView initState check: isAppForeground=$_isAppForeground, index=$_currentIndex',
            name: 'VideoPageView', category: LogCategory.video);
        if (_isAppForeground && _currentIndex >= 0 && _currentIndex < widget.videos.length) {
          final accepted = _contextNotifier?.setIfNewer(
            widget.screenId!,
            _currentIndex,
            widget.videos[_currentIndex].id,
            _claimEpoch,
          );
          Log.debug('🎯 VideoPageView claimed context: epoch=$_claimEpoch accepted=$accepted',
              name: 'VideoPageView', category: LogCategory.video);

          // Schedule prewarming
          if (widget.enablePrewarming) {
            _prewarmNeighbors(_currentIndex);
          }
        } else {
          Log.debug('⏭️ Skipping setContext in initState - conditions not met',
              name: 'VideoPageView', category: LogCategory.video);
        }
      });
    }
  }

  @override
  void didUpdateWidget(VideoPageView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle initialIndex changes
    if (widget.initialIndex != oldWidget.initialIndex) {
      _currentIndex = widget.initialIndex;
      // Note: PageController's initialPage can't be changed after creation,
      // but we update our tracking and context will update accordingly
      Log.debug('🔄 VideoPageView.didUpdateWidget: initialIndex changed from ${oldWidget.initialIndex} to ${widget.initialIndex}',
          name: 'VideoPageView', category: LogCategory.video);
    }

    // Handle screenId changes - claim new context if screenId changed
    if (widget.screenId != oldWidget.screenId && widget.enableLifecycleManagement && widget.screenId != null) {
      // Claim new epoch for the new screenId
      _claimEpoch = DateTime.now().microsecondsSinceEpoch;
      _contextNotifier = ref.read(currentPageContextProvider.notifier);

      Log.debug('🔄 VideoPageView.didUpdateWidget: screenId changed from ${oldWidget.screenId} to ${widget.screenId}, claiming new epoch=$_claimEpoch',
          name: 'VideoPageView', category: LogCategory.video);

      // Announce new claim
      _contextNotifier!.announcePending(_claimEpoch, widget.screenId!);

      // Update context immediately with current index
      Future.microtask(() {
        if (!mounted) return;

        if (_isAppForeground && _currentIndex >= 0 && _currentIndex < widget.videos.length) {
          final accepted = _contextNotifier?.setIfNewer(
            widget.screenId!,
            _currentIndex,
            widget.videos[_currentIndex].id,
            _claimEpoch,
          );
          Log.debug('🎯 VideoPageView claimed context after screenId change: epoch=$_claimEpoch index=$_currentIndex accepted=$accepted',
              name: 'VideoPageView', category: LogCategory.video);
        }
      });
    }
  }

  @override
  void dispose() {
    // Clear context if this widget still owns it (epoch-based ownership)
    // Defer to avoid modifying provider during dispose lifecycle
    if (_contextNotifier != null && widget.screenId != null) {
      final notifier = _contextNotifier!;
      final screenId = widget.screenId!;
      final claimEpoch = _claimEpoch;

      // Schedule for next frame to avoid modifying provider during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          final cleared = notifier.clearIfOwner(claimEpoch, screenId);
          if (cleared) {
            Log.debug('🧹 VideoPageView cleared context: epoch=$claimEpoch screenId=$screenId',
                name: 'VideoPageView', category: LogCategory.video);
          } else {
            Log.debug('⏭️ VideoPageView skipped clear (outdated): epoch=$claimEpoch screenId=$screenId',
                name: 'VideoPageView', category: LogCategory.video);
          }
        } catch (e) {
          // Suppress errors - context may have been claimed by another widget
          debugPrint('[OWNERSHIP] suppressed error during deferred context clear: $e');
        }
      });
    }

    // Only dispose controller if we created it
    if (widget.controller == null) {
      _pageController.dispose();
    }
    super.dispose();
  }

  void _prewarmNeighbors(int index) {
    if (!widget.enablePrewarming) return;

    final params = <VideoControllerParams>[];

    // AGGRESSIVE prewarming for demo-quality instant scrolling
    // Prewarm 10 videos ahead (more important for forward scrolling)
    // and 3 videos behind (less important for backward scrolling)
    // This ensures buttery-smooth infinite scrolling experience
    for (int offset = -3; offset <= 10; offset++) {
      final i = index + offset;
      if (i >= 0 && i < widget.videos.length) {
        final v = widget.videos[i];
        if (v.videoUrl != null && v.videoUrl!.isNotEmpty) {
          params.add(VideoControllerParams(
            videoId: v.id,
            videoUrl: v.videoUrl!,
            videoEvent: v,
          ));
        }
      }
    }

    if (params.isNotEmpty) {
      try {
        _prewarmer.prewarmVideos(params);
      } catch (e) {
        Log.error('Error prewarming neighbors: $e',
            name: 'VideoPageView', category: LogCategory.video);
      }
    }
  }

  void _handlePageChanged(int index) {
    Log.debug('📄 VideoPageView: Page changed to index $index',
        name: 'VideoPageView', category: LogCategory.video);
    setState(() => _currentIndex = index);

    if (index >= 0 && index < widget.videos.length) {
      final video = widget.videos[index];

      // Update page context if app is in foreground and screenId is provided
      if (widget.enableLifecycleManagement && widget.screenId != null) {
        if (_isAppForeground) {
          try {
            _contextNotifier?.setIfNewer(widget.screenId!, index, video.id, _claimEpoch);
          } catch (e) {
            Log.error('Error setting page context: $e',
                name: 'VideoPageView', category: LogCategory.video);
          }
        } else {
          Log.debug('⏭️ Skipping setContext - app is backgrounded',
              name: 'VideoPageView', category: LogCategory.video);
        }
      }

      // Prewarm neighbors
      if (widget.enablePrewarming) {
        _prewarmNeighbors(index);
      }

      // Check for pagination
      if (widget.onLoadMore != null && index >= widget.videos.length - 3) {
        widget.onLoadMore!();
      }

      // Notify parent
      widget.onPageChanged?.call(index, video);
    }
  }

  Widget _buildPageView() {
    Log.debug('🎮 VideoPageView: Building PageView with controller=${_pageController.hashCode}, '
        'hasClients=${_pageController.hasClients}, '
        'position=${_pageController.hasClients ? _pageController.position.pixels : "no position"}, '
        'videoCount=${widget.videos.length}, '
        'hasBottomNav=${widget.hasBottomNavigation}',
        name: 'VideoPageView', category: LogCategory.video);

    return PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          onPageChanged: _handlePageChanged,
          itemCount: widget.videos.length,
          pageSnapping: true,
          itemBuilder: (context, index) {
            if (index >= widget.videos.length) return const SizedBox.shrink();

            return VideoFeedItem(
              key: ValueKey('video-${widget.videos[index].id}'),
              video: widget.videos[index],
              index: index,
              hasBottomNavigation: widget.hasBottomNavigation,
              contextTitle: widget.contextTitle,
            );
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    Widget pageView = _buildPageView();

    // Wrap with ScrollConfiguration to enable mouse/trackpad dragging
    pageView = ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
        },
      ),
      child: pageView,
    );

    // Note: RefreshIndicator cannot wrap vertical PageView as it conflicts with scrolling
    // Pull-to-refresh should be implemented differently (e.g., custom gesture detection
    // or a separate refresh button). For now, onRefresh callback is available but not
    // used with RefreshIndicator to avoid blocking vertical scrolling.

    return pageView;
  }
}
