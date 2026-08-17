import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AppBar(
        title: Text(
          localeProvider.getText('help'),
          style: TextStyle(color: themeProvider.textColor, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: themeProvider.textColor),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section 1: NFC Scanning Guide
          Card(
            color: themeProvider.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: themeProvider.cardBorderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.nfc, color: themeProvider.primaryColor, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        localeProvider.getText('nfc_guide'),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeProvider.textColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(localeProvider.getText('nfc_step_1'), style: TextStyle(color: themeProvider.subtitleColor)),
                  const SizedBox(height: 6),
                  Text(localeProvider.getText('nfc_step_2'), style: TextStyle(color: themeProvider.subtitleColor)),
                  const SizedBox(height: 6),
                  Text(localeProvider.getText('nfc_step_3'), style: TextStyle(color: themeProvider.subtitleColor)),
                  const SizedBox(height: 6),
                  Text(localeProvider.getText('nfc_step_4'), style: TextStyle(color: themeProvider.subtitleColor)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Section 2: FAQ
          Card(
            color: themeProvider.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: themeProvider.cardBorderColor),
            ),
            child: ExpansionTile(
              leading: Icon(Icons.help_outline, color: themeProvider.accentColor),
              title: Text(localeProvider.getText('nfc_faq'), style: TextStyle(color: themeProvider.textColor, fontWeight: FontWeight.bold)),
              iconColor: themeProvider.textColor,
              collapsedIconColor: themeProvider.subtitleColor,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localeProvider.getText('faq_q1'),
                        style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.textColor),
                      ),
                      const SizedBox(height: 4),
                      Text(localeProvider.getText('faq_a1'), style: TextStyle(color: themeProvider.subtitleColor)),
                      const SizedBox(height: 12),
                      Text(
                        localeProvider.getText('faq_q2'),
                        style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.textColor),
                      ),
                      const SizedBox(height: 4),
                      Text(localeProvider.getText('faq_a2'), style: TextStyle(color: themeProvider.subtitleColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Section 3: Contact Support
          Card(
            color: themeProvider.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: themeProvider.cardBorderColor),
            ),
            child: ListTile(
              leading: const Icon(Icons.support_agent, color: Colors.green),
              title: Text(localeProvider.getText('contact_support'), style: TextStyle(color: themeProvider.textColor, fontWeight: FontWeight.bold)),
              subtitle: Text('Email: support@hydrange.io | Tel: 1900-1234', style: TextStyle(color: themeProvider.subtitleColor, fontSize: 12)),
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
