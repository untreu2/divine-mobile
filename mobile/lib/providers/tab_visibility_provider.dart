// ABOUTME: Tab visibility provider that manages active tab state for IndexedStack coordination
// ABOUTME: Provides reactive tab switching and visibility state management for video lifecycle

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tab_visibility_provider.g.dart';

@riverpod
class TabVisibility extends _$TabVisibility {
  @override
  int build() => 0; // Current active tab index

  void setActiveTab(int index) {
    // Router-driven architecture: tab changes trigger route changes which automatically
    // update activeVideoIdProvider - no manual state management needed

    // NOTE: With Riverpod-native lifecycle (onCancel/onResume + 30s timeout),
    // controllers autodispose automatically - no manual cleanup needed

    state = index;
  }
}

// Tab-specific visibility providers
@riverpod
bool isFeedTabActive(Ref ref) {
  return ref.watch(tabVisibilityProvider) == 0;
}

@riverpod
bool isExploreTabActive(Ref ref) {
  return ref.watch(tabVisibilityProvider) == 2;
}

@riverpod
bool isProfileTabActive(Ref ref) {
  return ref.watch(tabVisibilityProvider) == 3;
}
