import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;

/// Secure Local Backup Service using AES Encryption (AES-256-CBC)
class BackupService {
  // Secret key 32 bytes (256-bit) and IV 16 bytes (128-bit)
  static final _key = encrypt.Key.fromUtf8('hydrange_nfc_wallet_secret_key_!'); // 32 chars
  static final _iv = encrypt.IV.fromUtf8('1234567890123456'); // 16 chars

  /// Encrypts card list JSON string using AES
  static String exportEncryptedCards(List<dynamic> cards) {
    final encrypter = encrypt.Encrypter(encrypt.AES(_key, mode: encrypt.AESMode.cbc));
    final plainText = json.encode({
      'timestamp': DateTime.now().toIso8601String(),
      'version': '1.0',
      'cards': cards,
    });
    final encrypted = encrypter.encrypt(plainText, iv: _iv);
    return encrypted.base64;
  }

  /// Decrypts AES encrypted backup string back to card list
  static List<dynamic>? importEncryptedCards(String encryptedBase64) {
    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(_key, mode: encrypt.AESMode.cbc));
      final encrypted = encrypt.Encrypted.fromBase64(encryptedBase64);
      final decryptedText = encrypter.decrypt(encrypted, iv: _iv);
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
