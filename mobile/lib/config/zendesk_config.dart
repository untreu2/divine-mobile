// ABOUTME: Configuration for Zendesk Support SDK credentials
// ABOUTME: Loads from build-time environment variables to keep secrets out of source

/// Zendesk Support SDK configuration
class ZendeskConfig {
  /// Zendesk application ID
  /// Set via: --dart-define=ZENDESK_APP_ID=xxx
  static const String appId = String.fromEnvironment(
    'ZENDESK_APP_ID',
    defaultValue: '',
  );

  /// Zendesk client ID (OAuth)
  /// Set via: --dart-define=ZENDESK_CLIENT_ID=xxx
  static const String clientId = String.fromEnvironment(
    'ZENDESK_CLIENT_ID',
    defaultValue: '',
  );

  /// Zendesk instance URL
  /// Set via: --dart-define=ZENDESK_URL=xxx
  static const String zendeskUrl = String.fromEnvironment(
    'ZENDESK_URL',
    defaultValue: 'https://rabblelabs.zendesk.com',
  );
}
