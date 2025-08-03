// ABOUTME: Unit tests for relay migration configuration without network dependencies
// ABOUTME: Tests relay selection logic and configuration changes

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Relay Migration Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('should have migrated from relay3.openvine.co to relay2.openvine.co', () {
      // Test configuration migration
      final defaultRelays = NostrService.defaultRelays;
      
      // Should only have relay2
      expect(defaultRelays.length, equals(1));
      expect(defaultRelays.first, equals('wss://relay2.openvine.co'));
      
      // Should NOT have old relays
      expect(defaultRelays, isNot(contains('wss://relay3.openvine.co')));
      expect(defaultRelays, isNot(contains('wss://relay1.openvine.co')));
    });

    test('should have correct primary relay configuration', () {
      expect(NostrService.primaryRelayUrl, equals('wss://relay2.openvine.co'));
    });

    test('should expose primary relay through interface', () {
      final keyManager = NostrKeyManager();
      final service = NostrService(keyManager);
      
      expect(service.primaryRelay, equals('wss://relay2.openvine.co'));
    });

    test('should use simplified single-relay architecture', () {
      // Verify we moved away from dual-relay complexity
      final defaultRelays = NostrService.defaultRelays;
      
      // Only one relay for client operations
      expect(defaultRelays.length, equals(1));
      
      // That relay should be strfry (no auth needed)
      expect(defaultRelays.first, equals('wss://relay2.openvine.co'));
      
      // relay1 is backend-only for search indexing
      expect(defaultRelays, isNot(contains('wss://relay1.openvine.co')));
    });

    test('should maintain backward compatibility with isVineRelayAuthenticated', () {
      final keyManager = NostrKeyManager();
      final service = NostrService(keyManager);
      
      // Should not throw - kept for compatibility even though strfry doesn't need auth
      expect(() => service.isVineRelayAuthenticated, returnsNormally);
    });
  });
}