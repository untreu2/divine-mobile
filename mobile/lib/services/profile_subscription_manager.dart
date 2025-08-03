// ABOUTME: Advanced REQ message management for profile subscriptions with proper Nostr patterns
// ABOUTME: Handles subscription lifecycle, REQ batching, and relay-side filtering optimization  

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Advanced subscription manager for profile requests with proper REQ lifecycle
class ProfileSubscriptionManager {
  ProfileSubscriptionManager(this._nostrService);
  
  final INostrService _nostrService;
  
  // Subscription state
  final Map<String, ActiveProfileSubscription> _activeSubscriptions = {};
  final Map<String, Timer> _subscriptionTimeouts = {};
  
  // REQ optimization  
  final Queue<ProfileRequest> _pendingRequests = Queue<ProfileRequest>();
  final Set<String> _currentlyRequested = <String>{};
  Timer? _batchTimer;
  
  // Configuration
  static const Duration _batchDelay = Duration(milliseconds: 100);
  static const Duration _subscriptionTimeout = Duration(minutes: 10); // Extended for persistent subscriptions
  static const int _maxBatchSize = 20;
  static const int _maxConcurrentSubscriptions = 10; // Allow more concurrent for real-time
  
  // Statistics
  int _totalRequestsProcessed = 0;
  int _totalSubscriptionsCreated = 0;
  int _totalBatchesSent = 0;
  DateTime? _lastActivity;

  /// Create optimized subscription for profile requests  
  Future<String> createProfileSubscription({
    required List<String> pubkeys,
    required Function(Event) onProfileEvent,
    Function(dynamic)? onError,
    VoidCallback? onComplete,
    Duration? timeout,
  }) async {
    if (pubkeys.isEmpty) {
      throw ArgumentError('Pubkeys list cannot be empty');
    }
    
    // Clean up old subscriptions if at limit
    if (_activeSubscriptions.length >= _maxConcurrentSubscriptions) {
      await _cleanupOldestSubscription();
    }
    
    final subscriptionId = 'profiles_${DateTime.now().millisecondsSinceEpoch}';
    _totalSubscriptionsCreated++;
    _lastActivity = DateTime.now();
    
    Log.info(
      '🔔 Creating profile subscription: $subscriptionId for ${pubkeys.length} pubkeys',
      name: 'ProfileSubscriptionManager',
      category: LogCategory.system,
    );
    
    // Log first few pubkeys for debugging
    final displayPubkeys = pubkeys.take(3).map(_safePubkeyTrunc).join(', ');
    final remaining = pubkeys.length > 3 ? ' +${pubkeys.length - 3}' : '';
    Log.debug(
      '   - Authors: $displayPubkeys$remaining',
      name: 'ProfileSubscriptionManager', 
      category: LogCategory.system,
    );
    
    try {
      // Create optimized filter for profiles  
      final filter = Filter(
        kinds: const [0], // Only profile events
        authors: pubkeys,
        limit: pubkeys.length, // Request exactly what we need
      );
      
      // Create subscription
      final eventStream = _nostrService.subscribeToEvents(filters: [filter]);
      late StreamSubscription<Event> subscription;
      
      subscription = eventStream.listen(
        (event) {
          Log.debug(
            '📥 Profile subscription $subscriptionId received: ${_safePubkeyTrunc(event.pubkey)}',
            name: 'ProfileSubscriptionManager',
            category: LogCategory.system,
          );
          onProfileEvent(event);
        },
        onError: (error) {
          Log.error(
            'Profile subscription $subscriptionId error: $error',
            name: 'ProfileSubscriptionManager',
            category: LogCategory.system,
          );
          onError?.call(error);
          _cleanupSubscription(subscriptionId);
        },
        onDone: () {
          Log.info(
            'Profile subscription $subscriptionId completed',
            name: 'ProfileSubscriptionManager',
            category: LogCategory.system,
          );
          onComplete?.call();
          _cleanupSubscription(subscriptionId);
        },
      );
      
      // Set up timeout
      final timeoutDuration = timeout ?? _subscriptionTimeout;
      final timeoutTimer = Timer(timeoutDuration, () {
        Log.debug(
          '⏰ Profile subscription $subscriptionId timed out',
          name: 'ProfileSubscriptionManager',
          category: LogCategory.system,
        );
        subscription.cancel();
        _cleanupSubscription(subscriptionId);
      });
      
      // Store subscription
      _activeSubscriptions[subscriptionId] = ActiveProfileSubscription(
        id: subscriptionId,
        subscription: subscription,
        timeoutTimer: timeoutTimer,
        pubkeys: pubkeys,
        createdAt: DateTime.now(),
      );
      
      _subscriptionTimeouts[subscriptionId] = timeoutTimer;
      
      Log.info(
        '✅ Profile subscription created: $subscriptionId (${_activeSubscriptions.length} active)',
        name: 'ProfileSubscriptionManager',
        category: LogCategory.system,
      );
      
      return subscriptionId;
      
    } catch (e) {
      Log.error(
        'Failed to create profile subscription: $e',
        name: 'ProfileSubscriptionManager',
        category: LogCategory.system,
      );
      rethrow;
    }
  }
  
  /// Queue profile request for batched processing
  void queueProfileRequest(ProfileRequest request) {
    _totalRequestsProcessed++;
    _lastActivity = DateTime.now();
    
    // Check if already requested
    if (_currentlyRequested.contains(request.pubkey)) {
      Log.debug(
        'Profile already queued: ${_safePubkeyTrunc(request.pubkey)}',
        name: 'ProfileSubscriptionManager',
        category: LogCategory.system,
      );
      return;
    }
    
    _pendingRequests.add(request);
    _currentlyRequested.add(request.pubkey);
    
    Log.debug(
      '📋 Queued profile request: ${_safePubkeyTrunc(request.pubkey)} (queue: ${_pendingRequests.length})',
      name: 'ProfileSubscriptionManager',
      category: LogCategory.system,
    );
    
    _scheduleBatchProcessing();
  }
  
  /// Cancel specific subscription
  Future<void> cancelSubscription(String subscriptionId) async {
    final subscription = _activeSubscriptions[subscriptionId];
    if (subscription != null) {
      Log.debug(
        'Cancelling profile subscription: $subscriptionId',
        name: 'ProfileSubscriptionManager',
        category: LogCategory.system,
      );
      
      await subscription.subscription.cancel();
      subscription.timeoutTimer.cancel();
      _cleanupSubscription(subscriptionId);
    }
  }
  
  /// Cancel all active subscriptions
  Future<void> cancelAllSubscriptions() async {
    Log.info(
      'Cancelling all ${_activeSubscriptions.length} profile subscriptions',
      name: 'ProfileSubscriptionManager',
      category: LogCategory.system,
    );
    
    final subscriptionIds = _activeSubscriptions.keys.toList();
    for (final id in subscriptionIds) {
      await cancelSubscription(id);
    }
  }
  
  /// Get subscription statistics
  Map<String, dynamic> getStats() {
    return {
      'activeSubscriptions': _activeSubscriptions.length,
      'maxConcurrentSubscriptions': _maxConcurrentSubscriptions,
      'pendingRequests': _pendingRequests.length,
      'currentlyRequested': _currentlyRequested.length,
      'totalRequestsProcessed': _totalRequestsProcessed,
      'totalSubscriptionsCreated': _totalSubscriptionsCreated,
      'totalBatchesSent': _totalBatchesSent,
      'lastActivity': _lastActivity?.toIso8601String(),
      'subscriptionDetails': _activeSubscriptions.map(
        (id, sub) => MapEntry(id, {
          'pubkeyCount': sub.pubkeys.length,
          'ageSeconds': DateTime.now().difference(sub.createdAt).inSeconds,
        }),
      ),
    };
  }
  
  /// Dispose and cleanup all resources
  void dispose() {
    Log.info(
      'Disposing ProfileSubscriptionManager',
      name: 'ProfileSubscriptionManager',
      category: LogCategory.system,
    );
    
    _batchTimer?.cancel();
    
    // Cancel all subscriptions
    for (final subscription in _activeSubscriptions.values) {
      subscription.subscription.cancel();
      subscription.timeoutTimer.cancel();
    }
    _activeSubscriptions.clear();
    
    // Cancel all timeouts
    for (final timer in _subscriptionTimeouts.values) {
      timer.cancel();
    }
    _subscriptionTimeouts.clear();
    
    _pendingRequests.clear();
    _currentlyRequested.clear();
  }
  
  // Private implementation methods
  
  void _scheduleBatchProcessing() {
    _batchTimer?.cancel();
    _batchTimer = Timer(_batchDelay, _processBatch);
  }
  
  Future<void> _processBatch() async {
    if (_pendingRequests.isEmpty) return;
    
    // Collect batch of requests
    final batch = <ProfileRequest>[];
    while (batch.length < _maxBatchSize && _pendingRequests.isNotEmpty) {
      batch.add(_pendingRequests.removeFirst());
    }
    
    if (batch.isEmpty) return;
    
    _totalBatchesSent++;
    
    Log.info(
      '🚀 Processing profile batch: ${batch.length} requests',
      name: 'ProfileSubscriptionManager',
      category: LogCategory.system,
    );
    
    // Group requests by callback to create efficient subscriptions
    final callbackGroups = <Function(Event), List<ProfileRequest>>{};
    for (final request in batch) {
      callbackGroups.putIfAbsent(request.onProfileEvent, () => []).add(request);
    }
    
    // Create subscription for each callback group
    for (final entry in callbackGroups.entries) {
      final callback = entry.key;
      final requests = entry.value;
      final pubkeys = requests.map((r) => r.pubkey).toList();
      
      try {
        await createProfileSubscription(
          pubkeys: pubkeys,
          onProfileEvent: callback,
          onError: (error) {
            // Mark these requests as failed  
            for (final request in requests) {
              request.onError?.call(error);
              _currentlyRequested.remove(request.pubkey);
            }
          },
          onComplete: () {
            // Mark these requests as complete
            for (final request in requests) {
              request.onComplete?.call();
              _currentlyRequested.remove(request.pubkey);
            }
          },
        );
      } catch (e) {
        Log.error(
          'Failed to create subscription for batch: $e',
          name: 'ProfileSubscriptionManager',
          category: LogCategory.system,
        );
        
        // Mark requests as failed
        for (final request in requests) {
          request.onError?.call(e);
          _currentlyRequested.remove(request.pubkey);
        }
      }
    }
  }
  
  Future<void> _cleanupOldestSubscription() async {
    if (_activeSubscriptions.isEmpty) return;
    
    // Find oldest subscription
    String? oldestId;
    DateTime? oldestTime;
    
    for (final entry in _activeSubscriptions.entries) {
      if (oldestTime == null || entry.value.createdAt.isBefore(oldestTime)) {
        oldestTime = entry.value.createdAt;
        oldestId = entry.key;
      }
    }
    
    if (oldestId != null) {
      Log.debug(
        'Cleaning up oldest subscription: $oldestId',
        name: 'ProfileSubscriptionManager',
        category: LogCategory.system,
      );
      await cancelSubscription(oldestId);
    }
  }
  
  void _cleanupSubscription(String subscriptionId) {
    _activeSubscriptions.remove(subscriptionId);
    _subscriptionTimeouts.remove(subscriptionId)?.cancel();
  }
}

/// Profile request for batch processing
class ProfileRequest {
  const ProfileRequest({
    required this.pubkey,
    required this.onProfileEvent,
    this.onError,
    this.onComplete,
  });
  
  final String pubkey;
  final Function(Event) onProfileEvent;
  final Function(dynamic)? onError;
  final VoidCallback? onComplete;
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProfileRequest && other.pubkey == pubkey;
  }
  
  @override
  int get hashCode => pubkey.hashCode;
}

/// Active profile subscription tracking
class ActiveProfileSubscription {
  const ActiveProfileSubscription({
    required this.id,
    required this.subscription,
    required this.timeoutTimer,
    required this.pubkeys,
    required this.createdAt,
  });
  
  final String id;
  final StreamSubscription<Event> subscription;
  final Timer timeoutTimer;
  final List<String> pubkeys;
  final DateTime createdAt;
}

/// Helper function for safe pubkey truncation
String _safePubkeyTrunc(String pubkey) => 
    pubkey.length > 8 ? pubkey.substring(0, 8) : pubkey;