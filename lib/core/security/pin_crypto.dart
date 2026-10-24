import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Salted hashing, so the PIN and the recovery answer are never stored as typed.
class PinCrypto {
  PinCrypto._();

  static String newSalt() {
    final random = Random.secure();
    return base64UrlEncode(List<int>.generate(16, (_) => random.nextInt(256)));
  }

  static String hash(String value, String salt) =>
      sha256.convert(utf8.encode('$salt:$value')).toString();
}
