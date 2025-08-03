# OpenVine Memory

## Project Overview
OpenVine is a decentralized vine-like video sharing application powered by Nostr with:
- **Flutter Mobile App**: Cross-platform client for capturing and sharing short videos
- **Cloudflare Workers Backend**: Serverless backend for GIF creation and media processing

## Current Focus  
**Video Feed Architecture Complete** - Fixed video display issues and optimized Riverpod-based video management

## Technology Stack
- **Frontend**: Flutter (Dart) with Camera plugin
- **Backend**: Cloudflare Workers + R2 Storage
- **Protocol**: Nostr (decentralized social network)
- **Media Processing**: Real-time frame capture → GIF creation

## Nostr Event Requirements
OpenVine requires specific Nostr event types for proper functionality:
- **Kind 0**: User profiles (NIP-01) - Required for user display names and avatars
- **Kind 6**: Reposts (NIP-18) - Required for video repost/reshare functionality  
- **Kind 32222**: Addressable short looping videos (NIP-32222) - Primary video content with editable metadata
- **Kind 7**: Reactions (NIP-25) - Like/heart interactions
- **Kind 3**: Contact lists (NIP-02) - Follow/following relationships

See `mobile/docs/NOSTR_EVENT_TYPES.md` for complete event type documentation.

## Development Environment

### Local Development Server
**App URL**: http://localhost:53424/

The Flutter app is typically already running locally on Chrome when working on development. Use this URL to access the running app during debugging sessions.

### Debug Environment
- **Platform**: Chrome browser (flutter run -d chrome)
- **Hot Reload**: Available for rapid development
- **Debug Tools**: Chrome DevTools for Flutter debugging

## Build/Test Commands
```bash
# Flutter commands (run from /mobile directory)
flutter run -d chrome --release    # Run in Chrome browser
flutter build apk --debug          # Build Android debug APK
flutter test                       # Run unit tests
flutter analyze                    # Static analysis

# Backend commands (run from /backend directory)  
npm run dev                        # Local Cloudflare Workers development
npm run deploy                     # Deploy to Cloudflare
npm test                           # Run backend tests

# Analytics database management
./flush-analytics-simple.sh true   # Dry run - preview analytics keys to delete
./flush-analytics-simple.sh false  # Actually flush analytics database
```

## API Documentation

**Backend API Reference**: See `docs/BACKEND_API_REFERENCE.md` for complete documentation of all backend endpoints.

**Domain Architecture**:
- `api.openvine.co` - Main backend (uploads, media, video management, NIP-05, moderation, analytics)

**Key Endpoints**:
- File uploads: `POST api.openvine.co/api/upload`
- Video analytics: `POST api.openvine.co/analytics/view`
- Trending content: `GET api.openvine.co/analytics/trending/vines`

## Native Build Scripts
**IMPORTANT**: Use these scripts instead of direct Flutter builds for iOS/macOS to prevent CocoaPods sync errors.

```bash
# Native builds (run from /mobile directory)
./build_native.sh ios debug        # Build iOS debug with proper CocoaPods sync
./build_native.sh ios release      # Build iOS release  
./build_native.sh macos debug      # Build macOS debug
./build_native.sh macos release    # Build macOS release
./build_native.sh both debug       # Build both platforms

# Platform-specific scripts
./build_ios.sh debug               # iOS-only build script
./build_macos.sh release           # macOS-only build script

# Pre-build scripts for Xcode integration
./pre_build_ios.sh                 # Ensure iOS CocoaPods sync before Xcode build
./pre_build_macos.sh               # Ensure macOS CocoaPods sync before Xcode build
```

**Common CocoaPods Issues**: The scripts automatically handle "sandbox is not in sync with Podfile.lock" errors by ensuring `pod install` runs at the proper time. See `BUILD_SCRIPTS_README.md` for detailed usage and Xcode integration instructions.

## Development Workflow Requirements

### Code Quality Checks
**MANDATORY**: Always run `flutter analyze` after completing any task that modifies Dart code. This catches:
- Syntax errors
- Linting issues  
- Type errors
- Import problems
- Dead code warnings

**Process**:
1. Complete code changes
2. Run `flutter analyze` 
3. Fix any issues found
4. Confirm clean analysis before considering task complete

**Never** mark a Flutter task as complete without running analysis and addressing all issues.

### Asynchronous Programming Standards
**CRITICAL RULE**: NEVER use arbitrary delays or `Future.delayed()` as a solution to timing issues. This is crude, unreliable, and unprofessional.

**ALWAYS use proper asynchronous patterns instead**:
- **Callbacks**: Use proper event callbacks and listeners
- **Completers**: Use `Completer<T>` for custom async operations
- **Streams**: Use `Stream` and `StreamController` for event sequences  
- **Future chaining**: Use `then()`, `catchError()`, and `whenComplete()`
- **State management**: Use proper state change notifications
- **Platform channels**: Use method channels with proper completion handling

**Examples of FORBIDDEN patterns**:
```dart
// ❌ NEVER DO THIS
await Future.delayed(Duration(milliseconds: 500));
await Future.delayed(Duration(seconds: 2));
Timer(Duration(milliseconds: 100), () => checkAgain());
```

**Examples of CORRECT patterns**:
```dart
// ✅ Use callbacks and completers
final completer = Completer<String>();
controller.onInitialized = () => completer.complete('ready');
return completer.future;

// ✅ Use streams for events
final controller = StreamController<CameraEvent>();
await controller.stream.where((e) => e.type == 'initialized').first;

// ✅ Use proper state notifications
class Controller extends ChangeNotifier {
  bool _initialized = false;
  bool get isInitialized => _initialized;
  Future<void> waitForInitialization() async {
    if (_initialized) return;
    final completer = Completer<void>();
    void listener() {
      if (_initialized) {
        removeListener(listener);
        completer.complete();
      }
    }
    addListener(listener);
    return completer.future;
  }
}
```

## Video Feed Architecture

OpenVine uses a **Riverpod-based reactive architecture** for managing video feeds with multiple subscription types:

### Core Components

**VideoEventService** (`mobile/lib/services/video_event_service.dart`):
- Manages Nostr video event subscriptions by type (homeFeed, discovery, trending, etc.)
- Uses per-subscription-type event lists (`_eventLists` map)
- Supports multiple feed types: `SubscriptionType.homeFeed`, `SubscriptionType.discovery`, `SubscriptionType.hashtag`, etc.
- Provides getters: `homeFeedVideos`, `discoveryVideos`, `getVideos(subscriptionType)`

**VideoManager** (`mobile/lib/providers/video_manager_providers.dart`):
- Riverpod provider managing video player controllers and preloading
- **CRITICAL**: Listens to BOTH `videoEventsProvider` (discovery) AND `homeFeedProvider` (home feed)
- Automatically adds received videos to internal state via `_addVideoEvent()`
- Prevents `VideoManagerException: Video not found in manager state` errors during preloading
- Manages memory efficiently with controller limits and cleanup

**Feed Providers**:
- `videoEventsProvider` → Discovery videos (general public feed)
- `homeFeedProvider` → Videos from users you follow only
- Both providers automatically sync with VideoManager for seamless playback

### Video Feed Flow

1. **Nostr Events** → VideoEventService receives and categorizes by subscription type
2. **Provider Reactivity** → `videoEventsProvider` and `homeFeedProvider` emit updates
3. **VideoManager Sync** → Automatically adds videos from both providers to internal state
4. **UI Display** → Video feed screens render from respective providers
5. **Preloading** → VideoManager can preload any video because it has all videos in state

### Feed Types

- **Home Feed** (`VideoFeedScreen` with `homeFeedProvider`): Shows videos only from followed users
- **Discovery Feed** (`explore_screen.dart` with `videoEventsProvider`): Shows all public videos
- **Hashtag Feeds**: Filter videos by hashtags
- **Profile Feeds**: Show videos from specific users

### Critical Fix (2024-07-30)

Fixed broken bridge between VideoEventService and VideoManager:
- VideoManager was only listening to discovery videos (`videoEventsProvider`)
- Home feed videos (`homeFeedProvider`) weren't being added to VideoManager state
- Result: Videos appeared in feed providers but caused preload failures
- **Solution**: Added home feed listener to VideoManager alongside discovery listener

## Analytics Database Management

**Flush Script**: `/backend/flush-analytics-simple.sh` - Clears all analytics data from KV storage

```bash
./flush-analytics-simple.sh true   # Preview deletions
./flush-analytics-simple.sh false  # Actually delete
```

## Key Files
- `mobile/lib/services/camera_service.dart` - Hybrid frame capture implementation
- `mobile/lib/screens/camera_screen.dart` - Camera UI with real preview
- `mobile/spike/frame_capture_approaches/` - Research prototypes and analysis
- `backend/src/` - Cloudflare Workers GIF creation logic
- `backend/flush-analytics-simple.sh` - Analytics database flush script

[See ./.claude/memories/ for universal standards]