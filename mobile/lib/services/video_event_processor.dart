// ABOUTME: Service for processing Nostr events into VideoEvent objects
// ABOUTME: Handles event transformation, error recovery, and stream management

import 'dart:async';

import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service responsible for processing raw Nostr events into VideoEvents
class VideoEventProcessor {
  // Stream controllers for processed events and errors
  final StreamController<VideoEvent> _videoEventController =
      StreamController<VideoEvent>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  // Active stream subscription
  StreamSubscription<Event>? _eventSubscription;

  // Public streams
  Stream<VideoEvent> get videoEventStream => _videoEventController.stream;
  Stream<String> get errorStream => _errorController.stream;

  /// Process a single event
  void processEvent(Event event) {
    try {
      if (event.kind == 32222) {
        final videoEvent = VideoEvent.fromNostrEvent(event);
        _videoEventController.add(videoEvent);
        Log.debug(
          'Processed video event: ${event.id.substring(0, 8)}',
          name: 'VideoEventProcessor',
          category: LogCategory.video,
        );
      } else if (event.kind == 6) {
        // Handle reposts - extract the original video event
        _processRepostEvent(event);
      }
    } catch (e) {
      final errorMessage = 'Error processing video event: $e';
      _errorController.add(errorMessage);
      Log.error(
        errorMessage,
        name: 'VideoEventProcessor',
        category: LogCategory.video,
      );
    }
  }

  /// Connect to a stream of events for processing
  void connectToEventStream(Stream<Event> eventStream) {
    _eventSubscription?.cancel();
    _eventSubscription = eventStream.listen(
      processEvent,
      onError: (error) {
        final errorMessage = error.toString();
        _errorController.add(errorMessage);
        Log.error(
          'Stream error: $errorMessage',
          name: 'VideoEventProcessor',
          category: LogCategory.video,
        );
      },
    );
  }

  /// Disconnect from event stream
  void disconnectFromEventStream() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  void dispose() {
    disconnectFromEventStream();
    _videoEventController.close();
    _errorController.close();
  }

  void _processRepostEvent(Event event) {
    // TODO: Implement repost processing
    // This would need to extract the original event ID from tags
    // and potentially fetch the original event
    Log.debug(
      'Received repost event, processing not yet implemented',
      name: 'VideoEventProcessor',
      category: LogCategory.video,
    );
  }
}
