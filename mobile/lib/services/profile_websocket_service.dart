// ABOUTME: Persistent WebSocket service dedicated to profile (kind 0) requests  
// ABOUTME: Implements proper Nostr architecture with immediate completion and minimal timeouts

import 'dart:async';
import 'dart:collection';

import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Persistent WebSocket service for profile requests with proper Nostr architecture
class ProfileWebSocketService {
  ProfileWebSocketService(this._nostrService);
  
  final INostrService _nostrService;
  
  // Persistent connection state
  StreamSubscription<Event>? _profileSubscription;
  bool _isConnected = false;
  bool _isConnecting = false;
  
  // Request queueing and batching
  final Queue<String> _requestQueue = Queue<String>();
  final Set<String> _currentlyRequested = <String>{};
  Timer? _batchTimer;
  static const Duration _batchInterval = Duration(milliseconds: 100);
  static const int _maxBatchSize = 10;
  
  // Profile callbacks - allow multiple listeners per pubkey
  final Map<String, List<Completer<UserProfile?>>> _pendingCallbacks = {};
  
  // Connection management
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 5);
  
  // Statistics
  int _totalRequests = 0;
  int _successfulRequests = 0;
  int _batchesSent = 0;
  DateTime? _lastActivity;

  /// Get profile with automatic batching and persistent connection
  Future<UserProfile?> getProfile(String pubkey) async {
    if (pubkey.isEmpty) {
      throw ArgumentError('Pubkey cannot be empty');
    }
    
    _totalRequests++;
    _lastActivity = DateTime.now();
    
    Log.debug(
      '👤 ProfileWebSocket: Requesting profile for ${_safePubkeyTrunc(pubkey)}',
      name: 'ProfileWebSocketService',
      category: LogCategory.ui,
    );
    
    // Try to ensure connection is active, but handle gracefully if not ready
    try {
      await _ensureConnection();
    } catch (e) {
      Log.debug(
        'ProfileWebSocket not ready for ${_safePubkeyTrunc(pubkey)}: $e',
        name: 'ProfileWebSocketService',
        category: LogCategory.ui,
      );
      return null; // Return null instead of throwing - let caller handle retry
    }
    
    // Check if already requested in current batch
    if (_currentlyRequested.contains(pubkey)) {
      Log.debug(
        '⏳ Profile already requested in current batch: ${_safePubkeyTrunc(pubkey)}',
        name: 'ProfileWebSocketService',
        category: LogCategory.ui,
      );
      
      // Create completer and add to callbacks
      final completer = Completer<UserProfile?>();
      _pendingCallbacks.putIfAbsent(pubkey, () => []).add(completer);
      return completer.future;
    }
    
    // Add to queue and pending callbacks
    _requestQueue.add(pubkey);
    _currentlyRequested.add(pubkey);
    
    final completer = Completer<UserProfile?>();
    _pendingCallbacks.putIfAbsent(pubkey, () => []).add(completer);
    
    // Schedule batch execution
    _scheduleBatchExecution();
    
    return completer.future;
  }
  
  /// Get multiple profiles with efficient batching
  Future<Map<String, UserProfile?>> getMultipleProfiles(List<String> pubkeys) async {
    final results = <String, UserProfile?>{};
    final futures = <String, Future<UserProfile?>>{}; 
    
    Log.info(
      '📋 ProfileWebSocket: Batch requesting ${pubkeys.length} profiles',
      name: 'ProfileWebSocketService', 
      category: LogCategory.ui,
    );
    
    // Check if service is ready before starting requests
    try {
      await _ensureConnection();
    } catch (e) {
      Log.debug(
        'ProfileWebSocket not ready for batch request: $e',
        name: 'ProfileWebSocketService',
        category: LogCategory.ui,
      );
      // Return empty results - all profiles will be null
      for (final pubkey in pubkeys) {
        if (pubkey.isNotEmpty) {
          results[pubkey] = null;
        }
      }
      return results;
    }
    
    // Start all requests simultaneously - they'll be batched automatically
    for (final pubkey in pubkeys) {
      if (pubkey.isNotEmpty) {
        futures[pubkey] = getProfile(pubkey);
      }
    }
    
    // Wait for all to complete
    for (final entry in futures.entries) {
      try {
        results[entry.key] = await entry.value;
      } catch (e) {
        Log.error(
          'Error fetching profile ${_safePubkeyTrunc(entry.key)}: $e',
          name: 'ProfileWebSocketService',
          category: LogCategory.ui,
        );
        results[entry.key] = null;
      }
    }
    
    return results;
  }
  
  /// Get connection statistics
  Map<String, dynamic> getStats() {
    return {
      'isConnected': _isConnected,
      'isConnecting': _isConnecting, 
      'queueSize': _requestQueue.length,
      'currentlyRequested': _currentlyRequested.length,
      'pendingCallbacks': _pendingCallbacks.length,
      'totalRequests': _totalRequests,
      'successfulRequests': _successfulRequests,
      'batchesSent': _batchesSent,
      'successRate': _totalRequests > 0 ? (_successfulRequests / _totalRequests * 100).toStringAsFixed(1) : '0.0',
      'lastActivity': _lastActivity?.toIso8601String(),
      'reconnectAttempts': _reconnectAttempts,
    };
  }
  
  /// Dispose and cleanup all resources
  void dispose() {
    Log.info(
      'ProfileWebSocket: Disposing service',
      name: 'ProfileWebSocketService',
      category: LogCategory.system,
    );
    
    _batchTimer?.cancel();
    _reconnectTimer?.cancel();
    _profileSubscription?.cancel();
    
    // Complete all pending callbacks with null
    for (final callbacks in _pendingCallbacks.values) {
      for (final completer in callbacks) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      }
    }
    _pendingCallbacks.clear();
    
    _requestQueue.clear();
    _currentlyRequested.clear();
    _isConnected = false;
    _isConnecting = false;
  }
  
  // Private implementation methods
  
  Future<void> _ensureConnection() async {
    if (_isConnected || _isConnecting) return;
    
    if (!_nostrService.isInitialized) {
      throw Exception('NostrService not initialized');
    }
    
    if (_nostrService.connectedRelayCount == 0) {
      throw Exception('No connected relays');
    }
    
    _isConnecting = true;
    
    try {
      Log.info(
        '🔌 ProfileWebSocket: Service ready - using direct batch subscriptions',
        name: 'ProfileWebSocketService',
        category: LogCategory.system,
      );
      
      // FIX: No persistent subscription needed - batch subscriptions handle everything
      // This simplifies the architecture and fixes the broken dual subscription issue
      
      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      
      Log.info(
        '✅ ProfileWebSocket: Service ready for direct batch requests',
        name: 'ProfileWebSocketService',
        category: LogCategory.system,
      );
      
    } catch (e) {
      _isConnecting = false;
      Log.error(
        'Failed to establish profile connection: $e',
        name: 'ProfileWebSocketService',
        category: LogCategory.system,
      );
      _scheduleReconnect();
      rethrow;
    }
  }
  
  void _scheduleBatchExecution() {
    _batchTimer?.cancel();
    _batchTimer = Timer(_batchInterval, _executeBatch);
  }
  
  void _executeBatch() {
    if (_requestQueue.isEmpty || !_isConnected) return;
    
    // Collect batch of pubkeys to request
    final batch = <String>[];
    while (batch.length < _maxBatchSize && _requestQueue.isNotEmpty) {
      batch.add(_requestQueue.removeFirst());
    }
    
    if (batch.isEmpty) return;
    
    _batchesSent++;
    
    Log.info(
      '📡 ProfileWebSocket: Sending REQ for ${batch.length} profiles',
      name: 'ProfileWebSocketService',
      category: LogCategory.ui,
    );
    
    // Log the first few pubkeys for debugging
    final displayPubkeys = batch.take(3).map(_safePubkeyTrunc).join(', ');
    final remaining = batch.length > 3 ? ' and ${batch.length - 3} more' : '';
    Log.debug(
      '   - Requesting: $displayPubkeys$remaining',
      name: 'ProfileWebSocketService',
      category: LogCategory.ui,
    );
    
    try {
      // Create new filter with this batch of authors
      final filter = Filter(
        kinds: const [0],
        authors: batch,
        limit: batch.length,
      );
      
      // ✅ Create subscription that handles events immediately without timeouts
      final batchStream = _nostrService.subscribeToEvents(filters: [filter]);
      late StreamSubscription batchSubscription;
      
      // Track which pubkeys from this batch have been received
      final batchPubkeys = Set<String>.from(batch);
      final receivedPubkeys = <String>{};
      
      // Process events immediately as they arrive
      batchSubscription = batchStream.listen(
        (event) {
          // Handle profile events immediately as they arrive
          if (event.kind == 0 && batchPubkeys.contains(event.pubkey)) {
            receivedPubkeys.add(event.pubkey);
            _handleProfileEvent(event);
            
            // If all profiles from this batch are received, close subscription
            if (receivedPubkeys.length == batchPubkeys.length) {
              Log.debug(
                '✅ All ${batch.length} profiles received, closing batch subscription',
                name: 'ProfileWebSocketService', 
                category: LogCategory.ui,
              );
              batchSubscription.cancel();
            }
          }
        },
        onError: (error) {
          Log.error(
            'Batch request error: $error',
            name: 'ProfileWebSocketService',
            category: LogCategory.ui,
          );
          batchSubscription.cancel();
          _handleRemainingCallbacks(batch);
        },
        onDone: () {
          // Stream closed by relay (EOSE or connection closed)
          Log.debug(
            '📡 ProfileWebSocket: Stream closed for batch of ${batch.length} (received ${receivedPubkeys.length})',
            name: 'ProfileWebSocketService',
            category: LogCategory.ui,
          );
          batchSubscription.cancel();
          _handleRemainingCallbacks(batch);
        },
      );
      
    } catch (e) {
      Log.error(
        'Failed to execute profile batch: $e',
        name: 'ProfileWebSocketService',
        category: LogCategory.ui,
      );
      _handleRemainingCallbacks(batch);
    }
  }
  
  void _handleProfileEvent(Event event) {
    if (event.kind != 0) return;
    
    final pubkey = event.pubkey;
    
    Log.debug(
      '📥 ProfileWebSocket: Received profile for ${_safePubkeyTrunc(pubkey)}',
      name: 'ProfileWebSocketService',
      category: LogCategory.ui,
    );
    
    try {
      final profile = UserProfile.fromNostrEvent(event);
      _successfulRequests++;
      
      // Complete all pending callbacks for this pubkey
      final callbacks = _pendingCallbacks.remove(pubkey);
      if (callbacks != null) {
        for (final completer in callbacks) {
          if (!completer.isCompleted) {
            completer.complete(profile);
          }
        }
        
        Log.debug(
          '✅ Completed ${callbacks.length} callbacks for ${profile.bestDisplayName}',
          name: 'ProfileWebSocketService',
          category: LogCategory.ui,
        );
      }
      
      // Remove from currently requested
      _currentlyRequested.remove(pubkey);
      
    } catch (e) {
      Log.error(
        'Error parsing profile event: $e',
        name: 'ProfileWebSocketService',
        category: LogCategory.ui,
      );
      
      // Complete callbacks with null on parse error
      final callbacks = _pendingCallbacks.remove(pubkey);
      if (callbacks != null) {
        for (final completer in callbacks) {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        }
      }
      _currentlyRequested.remove(pubkey);
    }
  }
  
  // Connection error handlers removed - no longer needed with direct batch subscriptions
  
  void _handleRemainingCallbacks(List<String> batch) {
    // Complete any remaining callbacks with null (profiles not received)
    final remainingCallbacks = batch.where((pubkey) => _pendingCallbacks.containsKey(pubkey)).length;
    
    if (remainingCallbacks > 0) {
      Log.debug(
        'Profile batch completed - ${batch.length - remainingCallbacks}/${batch.length} profiles received',
        name: 'ProfileWebSocketService',
        category: LogCategory.ui,
      );
      
      // Complete pending callbacks with null (these profiles weren't received)
      final unfulfilled = <String>[];
      for (final pubkey in batch) {
        final callbacks = _pendingCallbacks.remove(pubkey);
        if (callbacks != null) {
          unfulfilled.add(_safePubkeyTrunc(pubkey));
          for (final completer in callbacks) {
            if (!completer.isCompleted) {
              completer.complete(null);
            }
          }
        }
        _currentlyRequested.remove(pubkey);
      }
      
      if (unfulfilled.isNotEmpty) {
        Log.debug(
          '📭 Profiles not found on relays: ${unfulfilled.join(', ')}',
          name: 'ProfileWebSocketService',
          category: LogCategory.ui,
        );
      }
    } else {
      // All callbacks already completed - just clean up tracking
      for (final pubkey in batch) {
        _currentlyRequested.remove(pubkey);
      }
    }
  }
  
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      Log.error(
        'Max reconnect attempts reached, giving up',
        name: 'ProfileWebSocketService',
        category: LogCategory.system,
      );
      return;
    }
    
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    
    final delay = Duration(seconds: _reconnectDelay.inSeconds * _reconnectAttempts);
    
    Log.warning(
      'Scheduling reconnect attempt $_reconnectAttempts/$_maxReconnectAttempts in ${delay.inSeconds}s',
      name: 'ProfileWebSocketService',
      category: LogCategory.system,
    );
    
    _reconnectTimer = Timer(delay, () {
      if (!_isConnected && !_isConnecting) {
        Log.info(
          'Attempting reconnect $_reconnectAttempts/$_maxReconnectAttempts',
          name: 'ProfileWebSocketService',
          category: LogCategory.system,
        );
        _ensureConnection().catchError((e) {
          Log.error(
            'Reconnect attempt $_reconnectAttempts failed: $e',
            name: 'ProfileWebSocketService',
            category: LogCategory.system,
          );
        });
      }
    });
  }
}

/// Helper function for safe pubkey truncation in logs  
String _safePubkeyTrunc(String pubkey) => 
    pubkey.length > 8 ? pubkey.substring(0, 8) : pubkey;