// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$profileWebSocketServiceHash() =>
    r'e0e7349f66a64e12fe0912be4f2b0d98ee8a066c';

/// ProfileWebSocketService provider - persistent WebSocket for profiles
///
/// Copied from [profileWebSocketService].
@ProviderFor(profileWebSocketService)
final profileWebSocketServiceProvider =
    Provider<ProfileWebSocketService>.internal(
  profileWebSocketService,
  name: r'profileWebSocketServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$profileWebSocketServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ProfileWebSocketServiceRef = ProviderRef<ProfileWebSocketService>;
String _$userProfileHash() => r'9c6dc5f716ae56ceaefd2ee4323ece2704f313ca';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Async provider for loading a single user profile
///
/// Copied from [userProfile].
@ProviderFor(userProfile)
const userProfileProvider = UserProfileFamily();

/// Async provider for loading a single user profile
///
/// Copied from [userProfile].
class UserProfileFamily extends Family<AsyncValue<UserProfile?>> {
  /// Async provider for loading a single user profile
  ///
  /// Copied from [userProfile].
  const UserProfileFamily();

  /// Async provider for loading a single user profile
  ///
  /// Copied from [userProfile].
  UserProfileProvider call(
    String pubkey,
  ) {
    return UserProfileProvider(
      pubkey,
    );
  }

  @override
  UserProfileProvider getProviderOverride(
    covariant UserProfileProvider provider,
  ) {
    return call(
      provider.pubkey,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'userProfileProvider';
}

/// Async provider for loading a single user profile
///
/// Copied from [userProfile].
class UserProfileProvider extends AutoDisposeFutureProvider<UserProfile?> {
  /// Async provider for loading a single user profile
  ///
  /// Copied from [userProfile].
  UserProfileProvider(
    String pubkey,
  ) : this._internal(
          (ref) => userProfile(
            ref as UserProfileRef,
            pubkey,
          ),
          from: userProfileProvider,
          name: r'userProfileProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$userProfileHash,
          dependencies: UserProfileFamily._dependencies,
          allTransitiveDependencies:
              UserProfileFamily._allTransitiveDependencies,
          pubkey: pubkey,
        );

  UserProfileProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.pubkey,
  }) : super.internal();

  final String pubkey;

  @override
  Override overrideWith(
    FutureOr<UserProfile?> Function(UserProfileRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: UserProfileProvider._internal(
        (ref) => create(ref as UserProfileRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        pubkey: pubkey,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<UserProfile?> createElement() {
    return _UserProfileProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UserProfileProvider && other.pubkey == pubkey;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, pubkey.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin UserProfileRef on AutoDisposeFutureProviderRef<UserProfile?> {
  /// The parameter `pubkey` of this provider.
  String get pubkey;
}

class _UserProfileProviderElement
    extends AutoDisposeFutureProviderElement<UserProfile?> with UserProfileRef {
  _UserProfileProviderElement(super.provider);

  @override
  String get pubkey => (origin as UserProfileProvider).pubkey;
}

String _$userProfileNotifierHash() =>
    r'2a770cd076da119a5deee5de48941a536bedb9b1';

/// See also [UserProfileNotifier].
@ProviderFor(UserProfileNotifier)
final userProfileNotifierProvider =
    AutoDisposeNotifierProvider<UserProfileNotifier, UserProfileState>.internal(
  UserProfileNotifier.new,
  name: r'userProfileNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userProfileNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$UserProfileNotifier = AutoDisposeNotifier<UserProfileState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
