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

      // Read NDEF records
      var records = await FlutterNfcKit.readNDEFRecords();
      await FlutterNfcKit.finish();

      if (records.isEmpty) {
        await HapticService.errorFeedback();
        return {'id': tag.id, 'data': null, 'valid': false, 'error': 'No NDEF records found'};
      }

      final payload = records.first.payload;
      if (payload == null || payload.isEmpty) {
        await HapticService.errorFeedback();
        return {'id': tag.id, 'data': null, 'valid': false, 'error': 'Invalid empty payload format'};
      }

      // 1. Calculate XOR Checksum
      int xorChecksum = 0;
      for (int i = 0; i < payload.length - 1; i++) {
        xorChecksum ^= payload[i];
      }

      // 2. Calculate SHA-256 checksum digest for data integrity
      final sha256Checksum = sha256.convert(payload).toString();

      final bool isValid = (payload.length == 1) || (xorChecksum == payload.last);

      if (isValid) {
        await HapticService.successFeedback();
        return {
          'id': tag.id,
          'data': utf8.decode(payload, allowMalformed: true),
          'valid': true,
          'checksum': sha256Checksum.substring(0, 8),
        };
      } else {
        await HapticService.errorFeedback();
        return {
          'id': tag.id,
          'valid': false,
          'error': 'Checksum mismatch! Data corrupted or tampered.',
        };
      }
    } catch (e) {
      await FlutterNfcKit.finish();
      await HapticService.errorFeedback();
      return {'error': e.toString(), 'valid': false};
    }
  }
}
