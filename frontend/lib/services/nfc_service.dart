import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';


class NfcService {
  /// Reads an NFC tag and performs a basic checksum validation.
  /// Expects the tag to contain data where the last byte is a simple XOR checksum of preceding bytes.
  Future<Map<String, dynamic>?> readAndValidateTag() async {
    try {
      var availability = await FlutterNfcKit.nfcAvailability;
      if (availability != NFCAvailability.available) return null;

      var tag = await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 10),
        iosAlertMessage: "Hold your card near the reader",
      );

      // Read NDEF records if available
      var records = await FlutterNfcKit.readNDEFRecords();
      await FlutterNfcKit.finish();

      if (records.isEmpty) return {'id': tag.id, 'data': null};

      final payload = records.first.payload;
      if (payload == null || payload.length < 2) return {'id': tag.id, 'data': null};

      // Checksum validation: XOR all bytes except the last one
      int checksum = 0;
      for (int i = 0; i < payload.length - 1; i++) {
        checksum ^= payload[i];
      }

      if (checksum == payload.last) {
        return {
          'id': tag.id,
          'data': payload.sublist(0, payload.length - 1),
          'valid': true
        };
      } else {
        return {'id': tag.id, 'valid': false, 'error': 'Checksum mismatch'};
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
