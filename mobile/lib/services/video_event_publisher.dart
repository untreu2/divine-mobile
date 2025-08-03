// ABOUTME: Service for publishing videos directly to Nostr without backend processing
// ABOUTME: Handles event creation, signing, and relay broadcasting for direct uploads

import 'dart:convert';

import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/blurhash_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service for publishing processed videos to Nostr relays
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class VideoEventPublisher  {
  VideoEventPublisher({
    required UploadManager uploadManager,
    required INostrService nostrService,
    AuthService? authService,
    PersonalEventCacheService? personalEventCache,
  })  : _uploadManager = uploadManager,
        _nostrService = nostrService,
        _authService = authService,
        _personalEventCache = personalEventCache;
  final UploadManager _uploadManager;
  final INostrService _nostrService;
  final AuthService? _authService;
  final PersonalEventCacheService? _personalEventCache;

  // Statistics
  int _totalEventsPublished = 0;
  int _totalEventsFailed = 0;
  DateTime? _lastPublishTime;


  /// Initialize the publisher
  Future<void> initialize() async {
    Log.debug('Initializing VideoEventPublisher',
        name: 'VideoEventPublisher', category: LogCategory.video);

    Log.info('VideoEventPublisher initialized',
        name: 'VideoEventPublisher', category: LogCategory.video);
  }

  /// Publish event to Nostr relays
  Future<bool> _publishEventToNostr(Event event) async {
    try {
      Log.debug('Publishing event to Nostr relays: ${event.id}',
          name: 'VideoEventPublisher', category: LogCategory.video);

      // Log the complete event details
      Log.info('📤 FULL EVENT TO PUBLISH:',
          name: 'VideoEventPublisher', category: LogCategory.video);
      Log.info('  ID: ${event.id}',
          name: 'VideoEventPublisher', category: LogCategory.video);
      Log.info('  Pubkey: ${event.pubkey}',
          name: 'VideoEventPublisher', category: LogCategory.video);
      Log.info('  Created At: ${event.createdAt}',
          name: 'VideoEventPublisher', category: LogCategory.video);
      Log.info('  Kind: ${event.kind}',
          name: 'VideoEventPublisher', category: LogCategory.video);
      Log.info('  Content: "${event.content}"',
          name: 'VideoEventPublisher', category: LogCategory.video);
      Log.info('  Tags (${event.tags.length} total):',
          name: 'VideoEventPublisher', category: LogCategory.video);
      for (final tag in event.tags) {
        Log.info('    - ${tag.join(", ")}',
            name: 'VideoEventPublisher', category: LogCategory.video);
      }
      Log.info('  Signature: ${event.sig}',
          name: 'VideoEventPublisher', category: LogCategory.video);
      Log.info('  Is Valid: ${event.isValid}',
          name: 'VideoEventPublisher', category: LogCategory.video);
      Log.info('  Is Signed: ${event.isSigned}',
          name: 'VideoEventPublisher', category: LogCategory.video);
      
      // Log the raw JSON representation
      try {
        final eventMap = event.toJson();
        final jsonStr = jsonEncode(eventMap);
        Log.info('📋 FULL EVENT JSON:',
            name: 'VideoEventPublisher', category: LogCategory.video);
        Log.info(jsonStr,
            name: 'VideoEventPublisher', category: LogCategory.video);
      } catch (e) {
        Log.warning('Could not serialize event to JSON: $e',
            name: 'VideoEventPublisher', category: LogCategory.video);
      }

      // Use the existing Nostr service to broadcast
      await _nostrService.broadcastEvent(event);

      Log.info('✅ Event broadcast completed, verifying publication...',
          name: 'VideoEventPublisher', category: LogCategory.video);
      
      // Wait a moment for relay to process the event
      await Future.delayed(const Duration(seconds: 2));
      
      // Try to fetch the event back from the relay to verify it was stored
      try {
        Log.debug('Fetching event ${event.id} from relay to verify...',
            name: 'VideoEventPublisher', category: LogCategory.video);
        
        // Import Filter class
        final filter = Filter(
          ids: [event.id],
          kinds: [32222],
        );
        
        // Subscribe temporarily to fetch the event
        final eventStream = _nostrService.subscribeToEvents(
          filters: [filter],
          bypassLimits: true,
        );
        
        // Wait for the event to come back
        Event? verifiedEvent;
        await for (final receivedEvent in eventStream.timeout(
          const Duration(seconds: 5),
          onTimeout: (sink) {
            Log.warning('Timeout waiting for event verification',
                name: 'VideoEventPublisher', category: LogCategory.video);
            sink.close();
          },
        )) {
          if (receivedEvent.id == event.id) {
            verifiedEvent = receivedEvent;
            Log.info('✅ Event verified on relay: ${event.id}',
                name: 'VideoEventPublisher', category: LogCategory.video);
            break;
          }
        }
        
        if (verifiedEvent != null) {
          Log.info('Event successfully verified on relay',
              name: 'VideoEventPublisher', category: LogCategory.video);
          return true;
        } else {
          Log.error('❌ Event not found on relay after publishing',
              name: 'VideoEventPublisher', category: LogCategory.video);
          return false;
        }
      } catch (e) {
        Log.warning('Could not verify event on relay (relay might not support fetching): $e',
            name: 'VideoEventPublisher', category: LogCategory.video);
        // Return true anyway as broadcast succeeded
        return true;
      }
    } catch (e) {
      Log.error('Failed to publish event to relays: $e',
          name: 'VideoEventPublisher', category: LogCategory.video);
      return false;
    }
  }


  /// Get publishing statistics
  Map<String, dynamic> get publishingStats => {
        'total_published': _totalEventsPublished,
        'total_failed': _totalEventsFailed,
        'last_publish_time': _lastPublishTime?.toIso8601String(),
      };


  /// Publish a video event with custom metadata
  Future<bool> publishVideoEvent({
    required PendingUpload upload,
    String? title,
    String? description,
    List<String>? hashtags,
    int? expirationTimestamp,
  }) async {
    // Create a temporary upload with updated metadata
    final updatedUpload = upload.copyWith(
      title: title ?? upload.title,
      description: description ?? upload.description,
      hashtags: hashtags ?? upload.hashtags,
    );

    return publishDirectUpload(updatedUpload,
        expirationTimestamp: expirationTimestamp);
  }

  /// Publish a video directly without polling (for direct upload)
  Future<bool> publishDirectUpload(PendingUpload upload,
      {int? expirationTimestamp}) async {
    if (upload.videoId == null || upload.cdnUrl == null) {
      Log.error('Cannot publish upload - missing videoId or cdnUrl',
          name: 'VideoEventPublisher', category: LogCategory.video);
      return false;
    }

    try {
      Log.debug('Publishing direct upload: ${upload.videoId}',
          name: 'VideoEventPublisher', category: LogCategory.video);

      // Create NIP-32222 compliant tags for the video
      final tags = <List<String>>[];

      // Generate unique identifier for the addressable event
      // Use videoId if available, otherwise generate from timestamp and random component
      final dTag = upload.videoId ?? 
        '${DateTime.now().millisecondsSinceEpoch}_${upload.id.substring(0, 8)}';
      tags.add(['d', dTag]);

      // Build imeta tag components
      final imetaComponents = <String>[];
      imetaComponents.add('url ${upload.cdnUrl!}');
      imetaComponents.add('m video/mp4');
      
      // Add thumbnail to imeta if available
      if (upload.thumbnailPath != null && upload.thumbnailPath!.isNotEmpty) {
        imetaComponents.add('image ${upload.thumbnailPath!}');
        Log.verbose('Including thumbnail in imeta: ${upload.thumbnailPath}',
            name: 'VideoEventPublisher', category: LogCategory.video);
      }
      
      // Generate blurhash from local video file
      if (upload.localVideoPath.isNotEmpty) {
        try {
          // Extract thumbnail bytes from the video at 500ms
          final thumbnailBytes = await VideoThumbnailService.extractThumbnailBytes(
            videoPath: upload.localVideoPath,
            timeMs: 500, // Same as used in DirectUploadService
            quality: 80,
          );
          
          if (thumbnailBytes != null) {
            final blurhash = await BlurhashService.generateBlurhash(thumbnailBytes);
            if (blurhash != null) {
              imetaComponents.add('blurhash $blurhash');
              Log.info('Generated blurhash from video: ${blurhash.substring(0, 10)}...',
                  name: 'VideoEventPublisher', category: LogCategory.video);
            }
          }
        } catch (e) {
          Log.warning('Failed to generate blurhash from video: $e',
              name: 'VideoEventPublisher', category: LogCategory.video);
        }
      }

      // Add dimensions to imeta if available
      if (upload.videoWidth != null && upload.videoHeight != null) {
        imetaComponents.add('dim ${upload.videoWidth}x${upload.videoHeight}');
      }

      // Add the complete imeta tag
      tags.add(['imeta', ...imetaComponents]);

      // Optional tags
      if (upload.title != null) tags.add(['title', upload.title!]);
      if (upload.description != null) {
        tags.add(['summary', upload.description!]);
      }

      // Add hashtags
      if (upload.hashtags != null) {
        for (final hashtag in upload.hashtags!) {
          tags.add(['t', hashtag]);
        }
      }

      // Add client tag
      tags.add(['client', 'openvine']);

      // Add published_at tag (current timestamp)
      tags.add(['published_at', (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString()]);

      // Add duration tag if available
      if (upload.videoDuration != null) {
        tags.add(['duration', upload.videoDuration!.inSeconds.toString()]);
      }

      // Add alt tag for accessibility (use title or description as alt text)
      final altText = upload.title ?? upload.description ?? 'Short video';
      tags.add(['alt', altText]);

      // Add expiration tag if specified
      if (expirationTimestamp != null) {
        tags.add(['expiration', expirationTimestamp.toString()]);
      }

      // Create the event content
      final content = upload.description ?? upload.title ?? '';

      // Create and sign the event
      if (_authService == null) {
        Log.error('Auth service is null - cannot create video event',
            name: 'VideoEventPublisher', category: LogCategory.video);
        return false;
      }

      if (!_authService!.isAuthenticated) {
        Log.error('User not authenticated - cannot create video event',
            name: 'VideoEventPublisher', category: LogCategory.video);
        return false;
      }

      Log.debug('📱 Creating and signing video event...',
          name: 'VideoEventPublisher', category: LogCategory.video);
      Log.verbose('Content: "$content"',
          name: 'VideoEventPublisher', category: LogCategory.video);
      Log.verbose('Tags: ${tags.length} tags',
          name: 'VideoEventPublisher', category: LogCategory.video);

      final event = await _authService!.createAndSignEvent(
        kind: 32222, // NIP-32222 addressable short looping video
        content: content,
        tags: tags,
      );

      if (event == null) {
        Log.error(
            'Failed to create and sign video event - createAndSignEvent returned null',
            name: 'VideoEventPublisher',
            category: LogCategory.video);
        return false;
      }

      // Cache the video event immediately after creation
      _personalEventCache?.cacheUserEvent(event);

      Log.info('Created video event: ${event.id}',
          name: 'VideoEventPublisher', category: LogCategory.video);

      // Publish to Nostr relays
      Log.info('🚀 Starting relay publication for event ${event.id}',
          name: 'VideoEventPublisher', category: LogCategory.video);
      final publishResult = await _publishEventToNostr(event);

      if (publishResult) {
        // Update upload status
        await _uploadManager.updateUploadStatus(
          upload.id,
          UploadStatus.published,
          nostrEventId: event.id,
        );

        _totalEventsPublished++;
        _lastPublishTime = DateTime.now();

        Log.info('Successfully published direct upload: ${event.id}',
            name: 'VideoEventPublisher', category: LogCategory.video);
        Log.debug('Video URL: ${upload.cdnUrl}',
            name: 'VideoEventPublisher', category: LogCategory.video);

        return true;
      } else {
        Log.error('Failed to publish to Nostr relays',
            name: 'VideoEventPublisher', category: LogCategory.video);
        return false;
      }
    } catch (e, stackTrace) {
      Log.error('Error publishing direct upload: $e',
          name: 'VideoEventPublisher', category: LogCategory.video);
      Log.verbose('📱 Stack trace: $stackTrace',
          name: 'VideoEventPublisher', category: LogCategory.video);
      _totalEventsFailed++;
      return false;
    }
  }

  void dispose() {
    Log.debug('📱️ Disposing VideoEventPublisher',
        name: 'VideoEventPublisher', category: LogCategory.video);
  }
}
