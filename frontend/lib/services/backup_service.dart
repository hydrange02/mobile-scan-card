import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;

/// Secure Local Backup Service using AES Encryption (AES-256-CBC) with Secure Random IV
class BackupService {
  // Secret key 32 bytes (256-bit)
  static final _key = encrypt.Key.fromUtf8('hydrange_nfc_wallet_secret_key_!'); // 32 chars

  /// Encrypts card list JSON string using AES with a secure random IV per export
  static String exportEncryptedCards(List<dynamic> cards) {
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(_key, mode: encrypt.AESMode.cbc));
    final plainText = json.encode({
      'timestamp': DateTime.now().toIso8601String(),
      'version': '1.0',
      'cards': cards,
    });
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    // Combine IV base64 and Ciphertext base64 separated by a colon
    return '${iv.base64}:${encrypted.base64}';
  }

  /// Decrypts AES encrypted backup payload string back to card list
  static List<dynamic>? importEncryptedCards(String encryptedPayload) {
    try {
      final parts = encryptedPayload.split(':');
      encrypt.IV iv;
      encrypt.Encrypted encrypted;

      if (parts.length == 2) {
        iv = encrypt.IV.fromBase64(parts[0]);
        encrypted = encrypt.Encrypted.fromBase64(parts[1]);
      } else {
        // Fallback for legacy format with static IV
        iv = encrypt.IV.fromUtf8('1234567890123456');
        encrypted = encrypt.Encrypted.fromBase64(encryptedPayload);
      }

      final encrypter = encrypt.Encrypter(encrypt.AES(_key, mode: encrypt.AESMode.cbc));
      final decryptedText = encrypter.decrypt(encrypted, iv: iv);
      final data = json.decode(decryptedText);
      if (data is Map && data.containsKey('cards')) {
        return data['cards'] as List<dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
