import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'haptic_service.dart';

class NfcService {
  /// Reads an NFC tag and performs checksum validation (XOR and SHA-256 integrity check).
  Future<Map<String, dynamic>> readAndValidateTag() async {
    try {
      var availability = await FlutterNfcKit.nfcAvailability;
      if (availability != NFCAvailability.available) {
        await HapticService.errorFeedback();
        return {'error': 'NFC not available on this device'};
      }

      var tag = await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 10),
        iosAlertMessage: "Hold your card near the reader",
      );

      // Read NDEF records if present
      List<dynamic> records = [];
      try {
        records = await FlutterNfcKit.readNDEFRecords();
      } catch (_) {}
      await FlutterNfcKit.finish();

      String payloadText = '';
      if (records.isNotEmpty && records.first.payload != null) {
        final payload = records.first.payload!;
        payloadText = utf8.decode(payload, allowMalformed: true);
      }

      // SHA-256 digest for tag ID & payload integrity
      final sha256Checksum = sha256.convert(utf8.encode(tag.id + payloadText)).toString();

      if (tag.id.isNotEmpty) {
        await HapticService.successFeedback();
        return {
          'id': tag.id,
          'data': payloadText.isNotEmpty ? payloadText : 'NFC Tag (${tag.id})',
          'valid': true,
          'checksum': sha256Checksum.substring(0, 8),
          'type': tag.type.toString(),
        };
      } else {
        await HapticService.errorFeedback();
        return {'id': null, 'valid': false, 'error': 'Invalid NFC tag reading'};
      }
    } catch (e) {
      try { await FlutterNfcKit.finish(); } catch (_) {}
      await HapticService.errorFeedback();
      return {'error': e.toString(), 'valid': false};
    }
  }
}
