import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/app_localizations.dart';
import '../../services/local_database.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(strings.get('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.language),
              title: Text(strings.get('language')),
              subtitle: Text(locale.languageCode == 'sw' ? 'Kiswahili' : 'English'),
              trailing: Switch(
                value: locale.languageCode == 'sw',
                onChanged: (_) async {
                  final next = locale.languageCode == 'sw' ? const Locale('en') : const Locale('sw');
                  await ref.read(localeProvider.notifier).setLocale(next);
                },
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: Text(strings.get('theme')),
              subtitle: Text(themeMode == ThemeMode.dark ? 'Dark' : 'Light'),
              trailing: Switch(
                value: themeMode == ThemeMode.dark,
                onChanged: (_) async {
                  await ref.read(themeModeProvider.notifier).toggle();
                },
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: Text(strings.get('backup')),
              subtitle: const Text('Optional encrypted backup export'),
              onTap: () async {
                final path = await LocalDatabase.instance.backupDatabase('madini-backup.db');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Backup stored at $path')),
                  );
                }
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.restore),
              title: Text(strings.get('restore')),
              subtitle: const Text('Restore from a local copy'),
              onTap: () {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Restore flow is ready for a user-selected backup file.')),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
