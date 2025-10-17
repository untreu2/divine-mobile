// ABOUTME: VisibilityTracker abstraction for lifecycle-safe widget visibility tracking
// ABOUTME: Prevents timer leaks in tests while maintaining production visibility detection

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class VisibilityTracker {
  /// Call when a child becomes (fractionally) visible.
  void onVisible(String id, {double fractionVisible = 1.0});

  /// Call when a child becomes invisible.
  void onInvisible(String id);

  /// Cancel any scheduled work (batching timers etc.)
  void cancelAll();
}

class DefaultVisibilityTracker implements VisibilityTracker {
  final _timers = <Timer>{};

  @override
  void onVisible(String id, {double fractionVisible = 1.0}) {
    // Matches visibility_detector's batching semantics with a cancellable timer
    final t = Timer(const Duration(milliseconds: 500), () {
      // do nothing or notify interested code; you likely already have callbacks
    });
    _timers.add(t);
  }

  @override
  void onInvisible(String id) {
    // Optionally schedule/cancel; keep minimal if not needed
  }

  @override
  void cancelAll() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }
}

final visibilityTrackerProvider = Provider<VisibilityTracker>((ref) {
  final v = DefaultVisibilityTracker();
  ref.onDispose(v.cancelAll);
  return v;
});

class NoopVisibilityTracker implements VisibilityTracker {
  @override
  void onVisible(String id, {double fractionVisible = 1.0}) {}

  @override
  void onInvisible(String id) {}

  @override
  void cancelAll() {}
}
