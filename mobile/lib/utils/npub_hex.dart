// ABOUTME: Utility for converting any public identifier format to hex pubkey
// ABOUTME: Returns null on invalid input instead of throwing (handles npub/nprofile/hex)

import 'package:openvine/utils/public_identifier_normalizer.dart';

/// Convert any public identifier (npub/nprofile/hex) to hex pubkey
/// Returns null if invalid
String? npubToHexOrNull(String? identifier) {
  if (identifier == null || identifier.isEmpty) return null;
  return normalizeToHex(identifier);
}
