// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'video_feed_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$VideoFeedState {
  /// List of videos in the feed
  List<VideoEvent> get videos => throw _privateConstructorUsedError;

  /// Whether more content can be loaded
  bool get hasMoreContent => throw _privateConstructorUsedError;

  /// Loading state for pagination
  bool get isLoadingMore => throw _privateConstructorUsedError;

  /// Refreshing state for pull-to-refresh
  bool get isRefreshing => throw _privateConstructorUsedError;

  /// Error message if any
  String? get error => throw _privateConstructorUsedError;

  /// Timestamp of last update
  DateTime? get lastUpdated => throw _privateConstructorUsedError;

  /// Create a copy of VideoFeedState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VideoFeedStateCopyWith<VideoFeedState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VideoFeedStateCopyWith<$Res> {
  factory $VideoFeedStateCopyWith(
          VideoFeedState value, $Res Function(VideoFeedState) then) =
      _$VideoFeedStateCopyWithImpl<$Res, VideoFeedState>;
  @useResult
  $Res call(
      {List<VideoEvent> videos,
      bool hasMoreContent,
      bool isLoadingMore,
      bool isRefreshing,
      String? error,
      DateTime? lastUpdated});
}

/// @nodoc
class _$VideoFeedStateCopyWithImpl<$Res, $Val extends VideoFeedState>
    implements $VideoFeedStateCopyWith<$Res> {
  _$VideoFeedStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VideoFeedState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? videos = null,
    Object? hasMoreContent = null,
    Object? isLoadingMore = null,
    Object? isRefreshing = null,
    Object? error = freezed,
    Object? lastUpdated = freezed,
  }) {
    return _then(_value.copyWith(
      videos: null == videos
          ? _value.videos
          : videos // ignore: cast_nullable_to_non_nullable
              as List<VideoEvent>,
      hasMoreContent: null == hasMoreContent
          ? _value.hasMoreContent
          : hasMoreContent // ignore: cast_nullable_to_non_nullable
              as bool,
      isLoadingMore: null == isLoadingMore
          ? _value.isLoadingMore
          : isLoadingMore // ignore: cast_nullable_to_non_nullable
              as bool,
      isRefreshing: null == isRefreshing
          ? _value.isRefreshing
          : isRefreshing // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      lastUpdated: freezed == lastUpdated
          ? _value.lastUpdated
          : lastUpdated // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$VideoFeedStateImplCopyWith<$Res>
    implements $VideoFeedStateCopyWith<$Res> {
  factory _$$VideoFeedStateImplCopyWith(_$VideoFeedStateImpl value,
          $Res Function(_$VideoFeedStateImpl) then) =
      __$$VideoFeedStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<VideoEvent> videos,
      bool hasMoreContent,
      bool isLoadingMore,
      bool isRefreshing,
      String? error,
      DateTime? lastUpdated});
}

/// @nodoc
class __$$VideoFeedStateImplCopyWithImpl<$Res>
    extends _$VideoFeedStateCopyWithImpl<$Res, _$VideoFeedStateImpl>
    implements _$$VideoFeedStateImplCopyWith<$Res> {
  __$$VideoFeedStateImplCopyWithImpl(
      _$VideoFeedStateImpl _value, $Res Function(_$VideoFeedStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of VideoFeedState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? videos = null,
    Object? hasMoreContent = null,
    Object? isLoadingMore = null,
    Object? isRefreshing = null,
    Object? error = freezed,
    Object? lastUpdated = freezed,
  }) {
    return _then(_$VideoFeedStateImpl(
      videos: null == videos
          ? _value._videos
          : videos // ignore: cast_nullable_to_non_nullable
              as List<VideoEvent>,
      hasMoreContent: null == hasMoreContent
          ? _value.hasMoreContent
          : hasMoreContent // ignore: cast_nullable_to_non_nullable
              as bool,
      isLoadingMore: null == isLoadingMore
          ? _value.isLoadingMore
          : isLoadingMore // ignore: cast_nullable_to_non_nullable
              as bool,
      isRefreshing: null == isRefreshing
          ? _value.isRefreshing
          : isRefreshing // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      lastUpdated: freezed == lastUpdated
          ? _value.lastUpdated
          : lastUpdated // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc

class _$VideoFeedStateImpl implements _VideoFeedState {
  const _$VideoFeedStateImpl(
      {required final List<VideoEvent> videos,
      required this.hasMoreContent,
      this.isLoadingMore = false,
      this.isRefreshing = false,
      this.error,
      this.lastUpdated})
      : _videos = videos;

  /// List of videos in the feed
  final List<VideoEvent> _videos;

  /// List of videos in the feed
  @override
  List<VideoEvent> get videos {
    if (_videos is EqualUnmodifiableListView) return _videos;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_videos);
  }

  /// Whether more content can be loaded
  @override
  final bool hasMoreContent;

  /// Loading state for pagination
  @override
  @JsonKey()
  final bool isLoadingMore;

  /// Refreshing state for pull-to-refresh
  @override
  @JsonKey()
  final bool isRefreshing;

  /// Error message if any
  @override
  final String? error;

  /// Timestamp of last update
  @override
  final DateTime? lastUpdated;

  @override
  String toString() {
    return 'VideoFeedState(videos: $videos, hasMoreContent: $hasMoreContent, isLoadingMore: $isLoadingMore, isRefreshing: $isRefreshing, error: $error, lastUpdated: $lastUpdated)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VideoFeedStateImpl &&
            const DeepCollectionEquality().equals(other._videos, _videos) &&
            (identical(other.hasMoreContent, hasMoreContent) ||
                other.hasMoreContent == hasMoreContent) &&
            (identical(other.isLoadingMore, isLoadingMore) ||
                other.isLoadingMore == isLoadingMore) &&
            (identical(other.isRefreshing, isRefreshing) ||
                other.isRefreshing == isRefreshing) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.lastUpdated, lastUpdated) ||
                other.lastUpdated == lastUpdated));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_videos),
      hasMoreContent,
      isLoadingMore,
      isRefreshing,
      error,
      lastUpdated);

  /// Create a copy of VideoFeedState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VideoFeedStateImplCopyWith<_$VideoFeedStateImpl> get copyWith =>
      __$$VideoFeedStateImplCopyWithImpl<_$VideoFeedStateImpl>(
          this, _$identity);
}

abstract class _VideoFeedState implements VideoFeedState {
  const factory _VideoFeedState(
      {required final List<VideoEvent> videos,
      required final bool hasMoreContent,
      final bool isLoadingMore,
      final bool isRefreshing,
      final String? error,
      final DateTime? lastUpdated}) = _$VideoFeedStateImpl;

  /// List of videos in the feed
  @override
  List<VideoEvent> get videos;

  /// Whether more content can be loaded
  @override
  bool get hasMoreContent;

  /// Loading state for pagination
  @override
  bool get isLoadingMore;

  /// Refreshing state for pull-to-refresh
  @override
  bool get isRefreshing;

  /// Error message if any
  @override
  String? get error;

  /// Timestamp of last update
  @override
  DateTime? get lastUpdated;

  /// Create a copy of VideoFeedState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VideoFeedStateImplCopyWith<_$VideoFeedStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
