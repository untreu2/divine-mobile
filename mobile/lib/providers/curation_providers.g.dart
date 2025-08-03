// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'curation_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$curationLoadingHash() => r'e1a04d9f8d90870d340665613c0938b356085039';

/// Provider to check if curation is loading
///
/// Copied from [curationLoading].
@ProviderFor(curationLoading)
final curationLoadingProvider = AutoDisposeProvider<bool>.internal(
  curationLoading,
  name: r'curationLoadingProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$curationLoadingHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurationLoadingRef = AutoDisposeProviderRef<bool>;
String _$editorsPicksHash() => r'47f6f4c73a8e2f6f8aafa718986c063feb530d08';

/// Provider to get editor's picks
///
/// Copied from [editorsPicks].
@ProviderFor(editorsPicks)
final editorsPicksProvider = AutoDisposeProvider<List<VideoEvent>>.internal(
  editorsPicks,
  name: r'editorsPicksProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$editorsPicksHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef EditorsPicksRef = AutoDisposeProviderRef<List<VideoEvent>>;
String _$curationHash() => r'cc52c49a2b2eaab0bb1e846b8d850bc97632d8e7';

/// Main curation provider that manages curated content sets
///
/// Copied from [Curation].
@ProviderFor(Curation)
final curationProvider =
    AutoDisposeNotifierProvider<Curation, CurationState>.internal(
  Curation.new,
  name: r'curationProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$curationHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$Curation = AutoDisposeNotifier<CurationState>;
String _$analyticsTrendingHash() => r'b7bb95a62cbc822807e116dfa4993eff23d71141';

/// Provider for analytics-based trending videos
///
/// Copied from [AnalyticsTrending].
@ProviderFor(AnalyticsTrending)
final analyticsTrendingProvider =
    AutoDisposeNotifierProvider<AnalyticsTrending, List<VideoEvent>>.internal(
  AnalyticsTrending.new,
  name: r'analyticsTrendingProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$analyticsTrendingHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AnalyticsTrending = AutoDisposeNotifier<List<VideoEvent>>;
String _$analyticsPopularHash() => r'4b5382aa579b0e35d9d560ce1a12875d28f7deca';

/// Provider for analytics-based popular videos (same as trending for now)
///
/// Copied from [AnalyticsPopular].
@ProviderFor(AnalyticsPopular)
final analyticsPopularProvider =
    AutoDisposeNotifierProvider<AnalyticsPopular, List<VideoEvent>>.internal(
  AnalyticsPopular.new,
  name: r'analyticsPopularProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$analyticsPopularHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AnalyticsPopular = AutoDisposeNotifier<List<VideoEvent>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
