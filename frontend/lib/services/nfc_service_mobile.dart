import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'dart:convert';

class NfcService {
  Future<Map<String, dynamic>?> scanCard() async {
    try {
      var availability = await FlutterNfcKit.nfcAvailability;
      if (availability != NFCAvailability.available) {
        throw Exception('NFC not available on this device');
      }

      var tag = await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 10),
        iosAlertMessage: "Hold your card near the device",
      );

      if (tag.id.isNotEmpty) {
        String checksum = _calculateChecksum(tag.id);
        await FlutterNfcKit.finish();
        
        return {
          'cardNumber': tag.id,
          'checksum': checksum,
          'type': tag.type.toString(),
        };
      }
    } catch (e) {
      try { await FlutterNfcKit.finish(); } catch (_) {}
      rethrow;
    }
    return null;
  }

  String _calculateChecksum(String data) {
    List<int> bytes = utf8.encode(data);
    int sum = bytes.fold(0, (prev, element) => prev + element);
    return (sum % 256).toRadixString(16).toUpperCase();
  }
}
