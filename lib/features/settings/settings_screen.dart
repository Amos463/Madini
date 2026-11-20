import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/app_localizations.dart';
import '../../core/format.dart';
import '../../services/app_lock.dart';
import '../../services/backup_reminder.dart';
import '../../services/temp_files.dart';
import '../../services/secure_backup.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _snack(BuildContext context, String text) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<String?> _ask(BuildContext context, String title, String label,
      {int? digits, String? note}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (note != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(note)),
          TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          keyboardType: digits != null ? TextInputType.number : TextInputType.text,
          maxLength: digits,
          inputFormatters: digits != null ? [FilteringTextInputFormatter.digitsOnly] : null,
          decoration: InputDecoration(labelText: label),
        )]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(tr(dialogContext, 'Ghairi', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: Text(tr(dialogContext, 'Endelea', 'Continue'))),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<String?> _askPassphrase(BuildContext context, String title, {String? note}) => _ask(
      context, title, tr(context, 'Nenosiri la backup (angalau herufi 12)', 'Backup passphrase (at least 12 characters)'),
      note: note);

  /// Kiashiria cha maendeleo wakati wa kazi nzito (PBKDF2/AES) ili app
  /// isionekane imeganda.
  Future<T> _withProgress<T>(BuildContext context, Future<T> Function() task) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(tr(context, 'Inasimba/inahakiki… subiri.', 'Working… please wait.'))),
          ]),
        ),
      ),
    );
    try {
      return await task();
    } finally {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _exportBackup(BuildContext context) async {
    try {
      final passphrase = await _askPassphrase(
        context,
        tr(context, 'Tengeneza backup iliyosimbwa', 'Create encrypted backup'),
        note: tr(context,
            'Nenosiri LIKIPOTEA, backup haiwezi kufunguliwa na hakuna njia ya kulirudisha. Liandike mahali salama.',
            'If this passphrase is LOST the backup cannot be opened and it cannot be recovered. Store it safely.'),
      );
      if (passphrase == null || !context.mounted) return;
      final problem = SecureBackup.passphraseProblem(passphrase);
      if (problem != null) {
        _snack(context, problem);
        return;
      }
      final again = await _askPassphrase(context, tr(context, 'Rudia nenosiri la backup', 'Repeat backup passphrase'));
      if (again == null || !context.mounted) return;
      if (again != passphrase) {
        _snack(context, tr(context, 'Manenosiri hayalingani.', 'Passphrases do not match.'));
        return;
      }
      final full = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(tr(c, 'Aina ya backup', 'Backup type')),
          content: Text(tr(c,
              'Kamili: rekodi na vyeti (inatumia kumbukumbu zaidi; kwa simu zenye RAM ndogo inaweza kuchukua muda). Nyepesi: rekodi, assay na bei bila faili za vyeti (haraka na salama kwa simu ndogo; vyeti utaviambatisha upya).',
              'Full: records and certificates (uses more memory; may be slow on low-RAM phones). Light: records, assays and prices without certificate files (fast and safe on small phones; you must re-attach certificates).')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text(tr(c, 'Ghairi', 'Cancel'))),
            OutlinedButton(onPressed: () => Navigator.pop(c, false), child: Text(tr(c, 'Nyepesi', 'Light'))),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr(c, 'Kamili', 'Full'))),
          ],
        ),
      );
      if (full == null || !context.mounted) return;
      final created = await _withProgress(
          context, () => SecureBackup.create(passphrase, includeCertificates: full));
      if (!context.mounted) return;
      // Hakiki mara moja kuwa backup itafunguka na nenosiri hili.
      await _withProgress(context, () => SecureBackup.verify(created.bytes, passphrase));
      await TempFiles.shareBytes(
          created.bytes, 'madini-backup-${DateTime.now().millisecondsSinceEpoch}.mdbak',
          text: 'MADINI encrypted backup. Hifadhi nenosiri kwa usalama.');
      await BackupReminder.markDone();
      if (!context.mounted) return;
      final extra = !full
          ? tr(context, ' Backup nyepesi: vyeti havikujumuishwa.', ' Light backup: certificates are not included.')
          : created.excludedCertificates > 0
          ? tr(context, ' Vyeti ${created.excludedCertificates} havikujumuishwa (vimezidi MB 30 kwa jumla au vimeshindwa kusomwa).',
              ' ${created.excludedCertificates} certificate(s) were NOT included (over 30 MB total or unreadable).')
          : '';
      _snack(context, tr(context, 'Backup imetengenezwa na kuhakikiwa: vyeti ${created.includedCertificates} vimejumuishwa.$extra',
          'Backup created and verified: ${created.includedCertificates} certificate(s) included.$extra'));
    } catch (e) {
      _snack(context, tr(context, 'Backup imeshindikana: $e', 'Backup failed: $e'));
    }
  }

  Future<void> _verifyBackup(BuildContext context) async {
    try {
      final selected = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
      if (selected == null || selected.files.single.bytes == null) return;
      if (!context.mounted) return;
      final passphrase = await _askPassphrase(context, tr(context, 'Hakiki backup', 'Verify backup'));
      if (passphrase == null || !context.mounted) return;
      final r = await _withProgress(context,
          () => SecureBackup.verify(selected.files.single.bytes!, passphrase));
      _snack(context, tr(context,
          'Backup ni salama: rekodi ${r.assessments}, vyeti ${r.certificates}${r.createdAt == null ? '' : ' (${r.createdAt})'}. Hakuna kilichobadilishwa.',
          'Backup is valid: ${r.assessments} record(s), ${r.certificates} certificate(s)${r.createdAt == null ? '' : ' (${r.createdAt})'}. Nothing was changed.'));
    } catch (e) {
      _snack(context, tr(context, 'Uhakiki umeshindikana: $e', 'Verification failed: $e'));
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    try {
      final selected = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (selected == null || selected.files.single.bytes == null) return;
      if (!selected.files.single.name.toLowerCase().endsWith('.mdbak')) {
        _snack(context, tr(context, 'Chagua faili la .mdbak.', 'Choose a .mdbak file.'));
        return;
      }
      if (!context.mounted) return;
      final passphrase = await _askPassphrase(context, tr(context, 'Rejesha backup', 'Restore backup'));
      if (passphrase == null) return;
      final result = await _withProgress(context,
          () => SecureBackup.restore(selected.files.single.bytes!, passphrase));
      _snack(context, tr(context, 'Rekodi ${result.assessments} na vyeti ${result.certificates} vimerejeshwa.',
          '${result.assessments} record(s) and ${result.certificates} certificate(s) restored.'));
    } catch (e) {
      _snack(context, tr(context, 'Restore imeshindikana: $e', 'Restore failed: $e'));
    }
  }

  Future<bool> _confirmCurrentPin(BuildContext context) async {
    final pin = await _ask(context, tr(context, 'PIN ya sasa', 'Current PIN'), 'PIN', digits: 6);
    if (pin == null) return false;
    final result = await AppLock.verify(pin);
    if (!result.ok) {
      _snack(context, result.lockedSeconds > 0
          ? tr(context, 'Umefungiwa kwa sekunde ${result.lockedSeconds}.', 'Locked for ${result.lockedSeconds} seconds.')
          : tr(context, 'PIN si sahihi.', 'Incorrect PIN.'));
    }
    return result.ok;
  }

  Future<void> _setPin(BuildContext context, {required bool change}) async {
    try {
      if (change && !await _confirmCurrentPin(context)) return;
      if (!context.mounted) return;
      final first = await _ask(context, tr(context, 'PIN mpya (tarakimu 6)', 'New PIN (6 digits)'), 'PIN', digits: 6);
      if (first == null) return;
      if (!AppLock.validPinFormat(first)) {
        _snack(context, tr(context, 'PIN lazima iwe tarakimu 6.', 'PIN must be 6 digits.'));
        return;
      }
      if (!context.mounted) return;
      final second = await _ask(context, tr(context, 'Rudia PIN', 'Repeat PIN'), 'PIN', digits: 6);
      if (second != first) {
        _snack(context, tr(context, 'PIN hazilingani.', 'PINs do not match.'));
        return;
      }
      await AppLock.setPin(first);
      _snack(context, tr(context, 'PIN imewekwa.', 'PIN set.'));
    } catch (e) {
      _snack(context, '$e');
    }
  }

  Future<void> _disablePin(BuildContext context) async {
    if (!await _confirmCurrentPin(context)) return;
    await AppLock.disable();
    _snack(context, tr(context, 'PIN imezimwa.', 'PIN disabled.'));
  }

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
              subtitle: Text(themeMode == ThemeMode.dark ? tr(context, 'Giza', 'Dark') : tr(context, 'Mwanga', 'Light')),
              trailing: Switch(
                value: themeMode == ThemeMode.dark,
                onChanged: (_) async => ref.read(themeModeProvider.notifier).toggle(),
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: AppLock.enabled,
            builder: (context, enabled, _) => Card(
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.pin_outlined),
                  title: Text(tr(context, 'PIN ya app', 'App PIN')),
                  subtitle: Text(enabled
                      ? tr(context, 'Imewashwa. App hujifunga ukiiacha zaidi ya sekunde 45. Hii inalinda skrini; haibadilishi encryption ya database.',
                          'Enabled. The app locks after 45 s in the background. This protects the screen; it does not change database encryption.')
                      : tr(context, 'Haijawashwa. Weka PIN ya tarakimu 6 ili kuzuia mtu mwingine kufungua rekodi kwenye simu iliyofunguliwa.',
                          'Not enabled. Set a 6-digit PIN to stop others opening records on an unlocked phone.')),
                  onTap: enabled ? null : () => _setPin(context, change: false),
                ),
                if (enabled) ...[
                  ListTile(
                    title: Text(tr(context, 'Badilisha PIN', 'Change PIN')),
                    onTap: () => _setPin(context, change: true),
                  ),
                  ListTile(
                    title: Text(tr(context, 'Zima PIN', 'Disable PIN')),
                    onTap: () => _disablePin(context),
                  ),
                ],
              ]),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(tr(context, 'Ulinzi wa taarifa za simu', 'On-device data protection')),
              subtitle: Text(tr(context,
                  'Database inatumia SQLCipher; ufunguo uko kwenye secure storage ya Android na haurudi kwa auto-backup. Ukibadilisha simu, tumia backup ya .mdbak. Linda simu yako kwa PIN/biometric.',
                  'The database uses SQLCipher; the key lives in Android secure storage and is excluded from auto-backup. When changing phones, use a .mdbak backup. Protect your phone with a PIN/biometric.')),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.enhanced_encryption_outlined),
              title: Text(tr(context, 'Tengeneza backup salama', 'Create secure backup')),
              subtitle: Text(tr(context,
                  'AES-256-GCM kwa nenosiri lako: tathmini, assay samples, historia ya bei na vyeti (hadi MB 30 kwa jumla). Historia ya audit imejumuishwa. Backup inahakikiwa mara moja baada ya kutengenezwa.',
                  'AES-256-GCM with your passphrase: assessments, assay samples, price history and certificates (up to 30 MB total). Audit history is included. The backup is verified right after it is created.')),
              onTap: () => _exportBackup(context),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: Text(tr(context, 'Hakiki backup (bila kurejesha)', 'Verify backup (without restoring)')),
              subtitle: Text(tr(context,
                  'Hufungua faili la .mdbak na nenosiri lako kuhakikisha linafanya kazi; hakuna data inayobadilishwa.',
                  'Opens a .mdbak file with your passphrase to confirm it works; no data is changed.')),
              onTap: () => _verifyBackup(context),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.restore),
              title: Text(tr(context, 'Rejesha backup', 'Restore backup')),
              subtitle: Text(tr(context,
                  'Rekodi zenye ID sawa zinasasishwa; assay samples na vyeti vilivyopo havifutwi.',
                  'Records with the same ID are updated; existing assay samples and certificates are not deleted.')),
              onTap: () => _restoreBackup(context),
            ),
          ),
        ],
      ),
    );
  }
}
