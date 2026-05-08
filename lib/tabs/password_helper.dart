import 'dart:convert';
import 'package:crypto/crypto.dart';

/// A utility class for basic password hashing and verification.
/// 
/// This implementation uses SHA-256. For production apps requiring higher security 
/// against brute-force attacks, consider using Argon2 or BCrypt.
class PasswordHelper {
  /// Hashes a [password] using the SHA-256 algorithm.
  /// 
  /// Call this before saving a password to your database (e.g., Firestore).
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  /// Verifies if a [plainPassword] matches a [storedHash].
  static bool verifyPassword(String plainPassword, String storedHash) {
    return hashPassword(plainPassword) == storedHash;
  }
}