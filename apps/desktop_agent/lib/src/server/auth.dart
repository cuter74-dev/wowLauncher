import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Token + code generation and hashing helpers.
///
/// SECURITY: the PC only ever stores the SHA-256 hash of an access token. The
/// plaintext token is returned to the mobile device once (on approval) and
/// never persisted on the PC.
class AuthTokens {
  AuthTokens._();

  static final Random _random = Random.secure();

  /// Generates a URL-safe random token with [bytes] of entropy.
  static String generateToken({int bytes = 32}) {
    final data = List<int>.generate(bytes, (_) => _random.nextInt(256));
    return base64Url.encode(data).replaceAll('=', '');
  }

  /// Generates a short, human-displayable single-use pairing code.
  static String generatePairingCode() {
    // 6 hex chars is enough for an ephemeral, single-use code.
    final data = List<int>.generate(3, (_) => _random.nextInt(256));
    return data.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  }

  /// SHA-256 hash (hex) of a token, used for storage and lookup.
  static String hashToken(String token) {
    return sha256.convert(utf8.encode(token)).toString();
  }
}
