// ABOUTME: Utility for converting npub (bech32) to hex pubkey
// ABOUTME: Returns null on invalid input instead of throwing

import 'package:openvine/utils/nostr_encoding.dart';

/// Convert npub to hex pubkey, returning null if invalid
String? npubToHexOrNull(String? npub) {
  if (npub == null || npub.isEmpty) return null;

  try {
    return NostrEncoding.decodePublicKey(npub);
  } catch (e) {
    // Invalid npub format
    return null;
  }
}
