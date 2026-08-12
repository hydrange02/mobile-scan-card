import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../services/autolock_service.dart';
import '../services/backup_service.dart';
import '../services/haptic_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _importController = TextEditingController();

  void _showBackupDialog(BuildContext context, String encryptedData) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AES Encrypted Backup Data'),
        content: SingleChildScrollView(
          child: SelectableText(encryptedData, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              HapticService.selectionFeedback();
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import AES Backup'),
        content: TextField(
          controller: _importController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Paste AES encrypted string here...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final cards = BackupService.importEncryptedCards(_importController.text.trim());
              Navigator.pop(ctx);
              if (cards != null) {
                HapticService.successFeedback();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Successfully restored ${cards.length} cards!')),
                );
              } else {
                HapticService.errorFeedback();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid or corrupted AES backup data.')),
                );
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final autoLockService = Provider.of<AutoLockService>(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Section 1: Appearance & Theme
        Card(
          child: ListTile(
            leading: const Icon(Icons.dark_mode, color: Colors.purpleAccent),
            title: Text(localeProvider.getText('dark_mode')),
            trailing: Switch(
              value: themeProvider.isDarkMode,
              onChanged: (val) {
                HapticService.selectionFeedback();
                themeProvider.toggleTheme(val);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Section 2: Language Switching
        Card(
          child: ListTile(
            leading: const Icon(Icons.language, color: Colors.blueAccent),
            title: Text(localeProvider.getText('language')),
            subtitle: Text(localeProvider.isVietnamese ? 'Tiếng Việt' : 'English'),
            trailing: DropdownButton<String>(
              value: localeProvider.locale.languageCode,
              items: const [
                DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (val) {
                if (val != null) {
                  HapticService.selectionFeedback();
                  localeProvider.setLocale(val);
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Section 3: Auto-Lock Security
        Card(
          child: ListTile(
            leading: const Icon(Icons.timer_outlined, color: Colors.orangeAccent),
            title: Text(localeProvider.getText('auto_lock')),
            subtitle: Text('${autoLockService.autoLockSeconds} seconds'),
            trailing: DropdownButton<int>(
              value: autoLockService.autoLockSeconds,
              items: const [
                DropdownMenuItem(value: 30, child: Text('30s')),
                DropdownMenuItem(value: 60, child: Text('60s')),
                DropdownMenuItem(value: 300, child: Text('5 min')),
              ],
              onChanged: (val) {
                if (val != null) {
                  HapticService.selectionFeedback();
                  autoLockService.setAutoLockSeconds(val);
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Section 4: Secure AES Backup
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.security, color: Colors.green),
                title: Text(localeProvider.getText('export_backup')),
                subtitle: const Text('AES-256 encrypted migration data'),
                onTap: () {
                  HapticService.successFeedback();
                  // Demo sample card export
                  final sampleCards = [
                    {'id': 1, 'cardName': 'Visa Gold', 'cardNumber': '4111222233334444'},
                    {'id': 2, 'cardName': 'Mastercard Platinum', 'cardNumber': '5500000000000004'}
                  ];
                  final encrypted = BackupService.exportEncryptedCards(sampleCards);
                  _showBackupDialog(context, encrypted);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.restore, color: Colors.teal),
                title: Text(localeProvider.getText('import_backup')),
                onTap: () {
                  HapticService.selectionFeedback();
                  _showImportDialog(context);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
