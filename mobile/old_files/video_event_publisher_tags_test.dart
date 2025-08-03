// ABOUTME: Test that video event publisher creates all required and optional tags correctly
// ABOUTME: Verifies NIP-32222 compliance with dimensions, duration, alt, and published_at tags

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_publisher.dart';

class MockUploadManager extends Mock implements UploadManager {}
class MockNostrService extends Mock implements INostrService {}
class MockAuthService extends Mock implements AuthService {}
class MockPersonalEventCacheService extends Mock implements PersonalEventCacheService {}
class MockEvent extends Mock implements Event {}

void main() {
  setUpAll(() {
    registerFallbackValue(MockEvent());
  });
  
  group('VideoEventPublisher Tags', () {
    late VideoEventPublisher publisher;
    late MockUploadManager mockUploadManager;
    late MockNostrService mockNostrService;
    late MockAuthService mockAuthService;
    late MockPersonalEventCacheService mockPersonalEventCache;
    
    setUp(() {
      mockUploadManager = MockUploadManager();
      mockNostrService = MockNostrService();
      mockAuthService = MockAuthService();
      mockPersonalEventCache = MockPersonalEventCacheService();
      
      publisher = VideoEventPublisher(
        uploadManager: mockUploadManager,
        nostrService: mockNostrService,
        authService: mockAuthService,
        personalEventCache: mockPersonalEventCache,
      );
      
      // Setup auth service
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn('test-pubkey');
    });
    
    test('creates event with all optional tags when dimensions and duration are provided', () async {
      // Create a test upload with all metadata
      final upload = PendingUpload(
        id: 'test-upload-id',
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'test-pubkey',
        status: UploadStatus.readyToPublish,
        createdAt: DateTime.now(),
        videoId: 'test-video-id',
        cdnUrl: 'https://example.com/video.mp4',
        title: 'Test Video Title',
        description: 'Test video description',
        hashtags: ['test', 'video'],
        videoWidth: 1920,
        videoHeight: 1080,
        videoDuration: const Duration(seconds: 30),
      );
      
      // Capture the event that would be created
      Event? capturedEvent;
      when(() => mockAuthService.createAndSignEvent(
        kind: any(named: 'kind'),
        content: any(named: 'content'),
        tags: any(named: 'tags'),
      )).thenAnswer((invocation) async {
        // Create a mock event with the provided parameters
        final mockEvent = MockEvent();
        when(() => mockEvent.id).thenReturn('test-event-id');
        when(() => mockEvent.pubkey).thenReturn('test-pubkey');
        when(() => mockEvent.kind).thenReturn(invocation.namedArguments[#kind] as int);
        when(() => mockEvent.content).thenReturn(invocation.namedArguments[#content] as String);
        when(() => mockEvent.tags).thenReturn(invocation.namedArguments[#tags] as List<List<String>>);
        when(() => mockEvent.createdAt).thenReturn(DateTime.now().millisecondsSinceEpoch ~/ 1000);
        when(() => mockEvent.sig).thenReturn('test-signature');
        when(() => mockEvent.isValid).thenReturn(true);
        when(() => mockEvent.isSigned).thenReturn(true);
        capturedEvent = mockEvent;
        return mockEvent;
      });
      
      // Setup other mocks
      when(() => mockNostrService.broadcastEvent(any())).thenAnswer((_) async {
        return NostrBroadcastResult(
          event: capturedEvent!,
          successCount: 1,
          totalRelays: 1,
          results: {'relay1': true},
          errors: {},
        );
      });
      when(() => mockUploadManager.updateUploadStatus(
        any(),
        any(),
        nostrEventId: any(named: 'nostrEventId'),
      )).thenAnswer((_) async {});
      when(() => mockPersonalEventCache.cacheUserEvent(any())).thenReturn(null);
      
      // Test publishing
      final result = await publisher.publishDirectUpload(upload);
      
      expect(result, isTrue);
      expect(capturedEvent, isNotNull);
      
      // Verify all tags are present
      final tags = capturedEvent!.tags;
      
      // Check required tags
      expect(tags.any((tag) => tag[0] == 'd' && tag[1] == 'test-video-id'), isTrue);
      expect(tags.any((tag) => tag[0] == 'title' && tag[1] == 'Test Video Title'), isTrue);
      expect(tags.any((tag) => tag[0] == 'summary' && tag[1] == 'Test video description'), isTrue);
      expect(tags.any((tag) => tag[0] == 't' && tag[1] == 'test'), isTrue);
      expect(tags.any((tag) => tag[0] == 't' && tag[1] == 'video'), isTrue);
      expect(tags.any((tag) => tag[0] == 'client' && tag[1] == 'openvine'), isTrue);
      
      // Check imeta tag with dimensions
      final imetaTag = tags.firstWhere((tag) => tag[0] == 'imeta');
      expect(imetaTag.contains('url https://example.com/video.mp4'), isTrue);
      expect(imetaTag.contains('m video/mp4'), isTrue);
      expect(imetaTag.contains('dim 1920x1080'), isTrue);
      
      // Check new optional tags
      expect(tags.any((tag) => tag[0] == 'published_at' && int.tryParse(tag[1]) != null), isTrue);
      expect(tags.any((tag) => tag[0] == 'duration' && tag[1] == '30'), isTrue);
      expect(tags.any((tag) => tag[0] == 'alt' && tag[1] == 'Test Video Title'), isTrue);
    });
    
    test('uses description as alt text when title is null', () async {
      // Create a test upload without title
      final upload = PendingUpload(
        id: 'test-upload-id',
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'test-pubkey',
        status: UploadStatus.readyToPublish,
        createdAt: DateTime.now(),
        videoId: 'test-video-id',
        cdnUrl: 'https://example.com/video.mp4',
        title: null,
        description: 'Test video description',
        hashtags: ['test'],
      );
      
      Event? capturedEvent;
      when(() => mockAuthService.createAndSignEvent(
        kind: any(named: 'kind'),
        content: any(named: 'content'),
        tags: any(named: 'tags'),
      )).thenAnswer((invocation) async {
        final mockEvent = MockEvent();
        when(() => mockEvent.id).thenReturn('test-event-id');
        when(() => mockEvent.tags).thenReturn(invocation.namedArguments[#tags] as List<List<String>>);
        capturedEvent = mockEvent;
        return mockEvent;
      });
      
      when(() => mockNostrService.broadcastEvent(any())).thenAnswer((_) async {
        return NostrBroadcastResult(
          event: capturedEvent!,
          successCount: 1,
          totalRelays: 1,
          results: {'relay1': true},
          errors: {},
        );
      });
      when(() => mockUploadManager.updateUploadStatus(any(), any(), nostrEventId: any(named: 'nostrEventId'))).thenAnswer((_) async {});
      when(() => mockPersonalEventCache.cacheUserEvent(any())).thenReturn(null);
      
      await publisher.publishDirectUpload(upload);
      
      final tags = capturedEvent!.tags;
      expect(tags.any((tag) => tag[0] == 'alt' && tag[1] == 'Test video description'), isTrue);
    });
    
    test('omits optional tags when metadata is not available', () async {
      // Create a minimal upload
      final upload = PendingUpload(
        id: 'test-upload-id',
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'test-pubkey',
        status: UploadStatus.readyToPublish,
        createdAt: DateTime.now(),
        videoId: 'test-video-id',
        cdnUrl: 'https://example.com/video.mp4',
      );
      
      Event? capturedEvent;
      when(() => mockAuthService.createAndSignEvent(
        kind: any(named: 'kind'),
        content: any(named: 'content'),
        tags: any(named: 'tags'),
      )).thenAnswer((invocation) async {
        final mockEvent = MockEvent();
        when(() => mockEvent.id).thenReturn('test-event-id');
        when(() => mockEvent.tags).thenReturn(invocation.namedArguments[#tags] as List<List<String>>);
        capturedEvent = mockEvent;
        return mockEvent;
      });
      
      when(() => mockNostrService.broadcastEvent(any())).thenAnswer((_) async {
        return NostrBroadcastResult(
          event: capturedEvent!,
          successCount: 1,
          totalRelays: 1,
          results: {'relay1': true},
          errors: {},
        );
      });
      when(() => mockUploadManager.updateUploadStatus(any(), any(), nostrEventId: any(named: 'nostrEventId'))).thenAnswer((_) async {});
      when(() => mockPersonalEventCache.cacheUserEvent(any())).thenReturn(null);
      
      await publisher.publishDirectUpload(upload);
      
      final tags = capturedEvent!.tags;
      
      // Verify imeta doesn't include dimensions when not provided
      final imetaTag = tags.firstWhere((tag) => tag[0] == 'imeta');
      expect(imetaTag.any((component) => component.startsWith('dim ')), isFalse);
      
      // Verify duration tag is not present
      expect(tags.any((tag) => tag[0] == 'duration'), isFalse);
      
      // Alt tag should default to 'Short video'
      expect(tags.any((tag) => tag[0] == 'alt' && tag[1] == 'Short video'), isTrue);
    });
  });
}