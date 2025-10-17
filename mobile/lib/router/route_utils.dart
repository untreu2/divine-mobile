// ABOUTME: Route parsing and building utilities
// ABOUTME: Converts between URLs and structured route context

import 'package:openvine/utils/unified_logger.dart';

/// Route types supported by the app
enum RouteType {
  home,
  explore,
  notifications,
  profile,
  hashtag, // Still supported as push route within explore
  search,
  camera,
  settings,
}

/// Structured representation of a route
class RouteContext {
  const RouteContext({
    required this.type,
    this.videoIndex,
    this.npub,
    this.hashtag,
  });

  final RouteType type;
  final int? videoIndex;
  final String? npub;
  final String? hashtag;
}

/// Parse a URL path into a structured RouteContext
/// Normalizes negative indices to 0 and decodes URL-encoded parameters
RouteContext parseRoute(String path) {
  Log.info('ROUTE parse: $path', name: 'Route', category: LogCategory.ui);
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();

  if (segments.isEmpty) {
    return const RouteContext(type: RouteType.home, videoIndex: 0);
  }

  final firstSegment = segments[0];

  switch (firstSegment) {
    case 'home':
      final rawIndex = segments.length > 1 ? int.tryParse(segments[1]) ?? 0 : 0;
      final index = rawIndex < 0 ? 0 : rawIndex; // Normalize negative indices
      return RouteContext(type: RouteType.home, videoIndex: index);

    case 'explore':
      // No index segment = grid mode (null videoIndex)
      // With index segment = feed mode (videoIndex set)
      final rawIndex = segments.length > 1 ? int.tryParse(segments[1]) : null;
      final index = rawIndex != null && rawIndex < 0 ? 0 : rawIndex; // Normalize negative indices
      return RouteContext(type: RouteType.explore, videoIndex: index);

    case 'profile':
      if (segments.length < 2) {
        return const RouteContext(type: RouteType.home, videoIndex: 0);
      }
      final npub = Uri.decodeComponent(segments[1]); // Decode URL encoding
      final rawIndex = segments.length > 2 ? int.tryParse(segments[2]) ?? 0 : 0;
      final index = rawIndex < 0 ? 0 : rawIndex; // Normalize negative indices
      return RouteContext(
        type: RouteType.profile,
        npub: npub,
        videoIndex: index,
      );

    case 'notifications':
      final rawIndex = segments.length > 1 ? int.tryParse(segments[1]) ?? 0 : 0;
      final index = rawIndex < 0 ? 0 : rawIndex; // Normalize negative indices
      return RouteContext(type: RouteType.notifications, videoIndex: index);

    case 'hashtag':
      if (segments.length < 2) {
        return const RouteContext(type: RouteType.home, videoIndex: 0);
      }
      final tag = Uri.decodeComponent(segments[1]); // Decode URL encoding
      // No index segment = grid mode (null videoIndex)
      // With index segment = feed mode (videoIndex set)
      final rawIndex = segments.length > 2 ? int.tryParse(segments[2]) : null;
      final index = rawIndex != null && rawIndex < 0 ? 0 : rawIndex; // Normalize negative indices
      return RouteContext(
        type: RouteType.hashtag,
        hashtag: tag,
        videoIndex: index,
      );

    case 'search':
      return const RouteContext(type: RouteType.search);

    case 'camera':
      return const RouteContext(type: RouteType.camera);

    case 'settings':
      return const RouteContext(type: RouteType.settings);

    default:
      return const RouteContext(type: RouteType.home, videoIndex: 0);
  }
}

/// Build a URL path from a RouteContext
/// Encodes dynamic parameters and normalizes indices to >= 0
String buildRoute(RouteContext context) {
  switch (context.type) {
    case RouteType.home:
      final rawIndex = context.videoIndex ?? 0;
      final index = rawIndex < 0 ? 0 : rawIndex; // Normalize negative indices
      return '/home/$index';

    case RouteType.explore:
      // Grid mode (null videoIndex) returns '/explore'
      // Feed mode (videoIndex set) returns '/explore/{index}'
      if (context.videoIndex == null) return '/explore';
      final rawIndex = context.videoIndex!;
      final index = rawIndex < 0 ? 0 : rawIndex; // Normalize negative indices
      return '/explore/$index';

    case RouteType.notifications:
      final rawIndex = context.videoIndex ?? 0;
      final index = rawIndex < 0 ? 0 : rawIndex; // Normalize negative indices
      return '/notifications/$index';

    case RouteType.profile:
      final npub = Uri.encodeComponent(context.npub ?? ''); // Encode URL
      final rawIndex = context.videoIndex ?? 0;
      final index = rawIndex < 0 ? 0 : rawIndex; // Normalize negative indices
      return '/profile/$npub/$index';

    case RouteType.hashtag:
      final hashtag = Uri.encodeComponent(context.hashtag ?? ''); // Encode URL
      // Grid mode (null videoIndex) returns '/hashtag/{tag}'
      // Feed mode (videoIndex set) returns '/hashtag/{tag}/{index}'
      if (context.videoIndex == null) return '/hashtag/$hashtag';
      final rawIndex = context.videoIndex!;
      final index = rawIndex < 0 ? 0 : rawIndex; // Normalize negative indices
      return '/hashtag/$hashtag/$index';

    case RouteType.search:
      return '/search';

    case RouteType.camera:
      return '/camera';

    case RouteType.settings:
      return '/settings';
  }
}
