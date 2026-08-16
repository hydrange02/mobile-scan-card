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
                  Text(localeProvider.getText('nfc_step_1')),
                  const SizedBox(height: 6),
                  Text(localeProvider.getText('nfc_step_2')),
                  const SizedBox(height: 6),
                  Text(localeProvider.getText('nfc_step_3')),
                  const SizedBox(height: 6),
                  Text(localeProvider.getText('nfc_step_4')),
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
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localeProvider.getText('faq_q1'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(localeProvider.getText('faq_a1')),
                      const SizedBox(height: 12),
                      Text(
                        localeProvider.getText('faq_q2'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(localeProvider.getText('faq_a2')),
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
                  SnackBar(content: Text(localeProvider.getText('contact_calling'))),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
