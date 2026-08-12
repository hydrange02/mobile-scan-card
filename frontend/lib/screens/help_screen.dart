import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localeProvider.getText('help')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section 1: NFC Scanning Guide
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.nfc, color: Colors.purpleAccent, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        localeProvider.getText('nfc_guide'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('1. Turn on NFC in your phone settings.'),
                  const Text('2. Hold your physical card or tag near the back sensor of the phone.'),
                  const Text('3. Keep steady for 1-2 seconds until you feel haptic vibration.'),
                  const Text('4. Check data checksum validation result on screen.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Section 2: FAQ
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.help_outline, color: Colors.blue),
              title: Text(localeProvider.getText('nfc_faq')),
              children: const [
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Q: What if the card is not detected?', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('A: Remove thick phone cases or ensure the NFC chip is enabled in system settings.'),
                      SizedBox(height: 8),
                      Text('Q: How secure is the AES Backup?', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('A: Data is encrypted with 256-bit AES cipher, requiring secret key to restore.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Section 3: Contact Support
          Card(
            child: ListTile(
              leading: const Icon(Icons.support_agent, color: Colors.green),
              title: Text(localeProvider.getText('contact_support')),
              subtitle: const Text('Email: support@hydrange.io | Tel: 1900-1234'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Calling customer support...')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
