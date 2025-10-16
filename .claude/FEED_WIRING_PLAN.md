# Feed Wiring Research - Minimal Fix Required

## Research Complete: Everything Exists, Just Needs Wiring

### ✅ Service Methods EXIST
```dart
// In VideoEventService (lib/services/video_event_service.dart):
Future<void> subscribeToHashtagVideos(List<String> hashtags, {int limit = 50})
Future<void> subscribeToUserVideos(String pubkey, {int limit = 50})
List<VideoEvent> get hashtagVideos
List<VideoEvent> get profileVideos
List<VideoEvent> getVideosByAuthor(String pubkey)
```

### ✅ Route Params EXIST
```dart
// RouteContext already has:
final String? hashtag;  // populated by parseRoute for /hashtag/<tag>/<i>
final String? npub;     // populated by parseRoute for /profile/<npub>/<i>
```

### ✅ Active Video Chain WIRED
```dart
// activeVideoIdProvider (lib/providers/active_video_provider.dart):
case RouteType.hashtag:
  videosAsync = ref.watch(videosForHashtagRouteProvider);  // line 38
case RouteType.profile:
  videosAsync = ref.watch(videosForProfileRouteProvider);  // line 35
```

### ❌ Gap: Providers Return Empty Stubs

**Current (hashtag_feed_providers.dart:22):**
```dart
// TODO(#148): Implement actual hashtag feed fetching based on ctx.hashtag
return AsyncValue.data(VideoFeedState(
  videos: const [],
  hasMoreContent: false,
  isLoadingMore: false,
));
```

**Current (profile_feed_providers.dart:22):**
```dart
// TODO(#149): Implement actual profile feed fetching based on ctx.profilePubkey
return AsyncValue.data(VideoFeedState(
  videos: const [],
  hasMoreContent: false,
  isLoadingMore: false,
));
```

## Minimal Fix: Rewire Only (No New Architecture)

### Fix 1: Hashtag Feed Provider

**File:** `lib/providers/hashtag_feed_providers.dart`

**Change:** Replace stub with call to existing service

**Pattern to copy:** Look at how `videosForHomeRouteProvider` does it:
```dart
// route_feed_providers.dart:23
return ref.watch(homeFeedProvider);
```

We need a `hashtagFeedProvider` that:
1. Reads `ctx.hashtag` from page context
2. Subscribes to `videoEventService.subscribeToHashtagVideos([tag])`
3. Returns `AsyncValue<VideoFeedState>` from service's `hashtagVideos` list

### Fix 2: Profile Feed Provider

**File:** `lib/providers/profile_feed_providers.dart`

**Change:** Replace stub with call to existing service

Similar pattern - need a `profileFeedProvider` that:
1. Reads `ctx.npub` from page context
2. Converts npub → hex pubkey (utility may already exist)
3. Subscribes to `videoEventService.subscribeToUserVideos(hex)`
4. Returns `AsyncValue<VideoFeedState>` from service's `profileVideos` list

## Questions for Service Wiring

1. **Does VideoEventService need a provider?**
   - Check if `videoEventServiceProvider` exists
   - Or do we use `ref.read(appProvidersProvider).videoEventService`?

2. **How does homeFeedProvider subscribe?**
   - Does it call `subscribeToHomeFeed()` in initState/build?
   - Or is subscription managed elsewhere?

3. **Is there an npub↔hex converter?**
   - Check `lib/utils/` for npub/bech32 utilities

4. **How to handle lifecycle?**
   - Should we call `unsubscribeFromVideoFeed()` on dispose?
   - Or is service already managing subscriptions centrally?

## Next Steps

1. Read `lib/providers/home_feed_provider.dart` to understand the pattern
2. Check for npub/hex utilities
3. Check how VideoEventService is accessed in providers
4. Implement minimal rewiring (copy pattern, don't invent new architecture)
5. Write probe tests to verify feeds emit non-empty

## Estimated Time

- Read home_feed_provider pattern: 5 min
- Implement hashtag provider rewiring: 10 min
- Implement profile provider rewiring: 10 min
- Write 2 probe tests: 10 min
- **Total: ~35 minutes**

This is purely wiring existing pieces, not building new architecture.
