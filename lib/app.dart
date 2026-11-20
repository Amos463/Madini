import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_localizations.dart';
import 'core/app_theme.dart';
import 'core/format.dart';
import 'features/history/history_screen.dart';
import 'features/home/home_screen.dart';
import 'features/lock/lock_screen.dart';
import 'features/search/search_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/valuation/valuation_screen.dart';
import 'services/local_database.dart';

final localeProvider = StateNotifierProvider<LocaleController, Locale>((ref) => LocaleController());
final themeModeProvider = StateNotifierProvider<ThemeController, ThemeMode>((ref) => ThemeController());

class LocaleController extends StateNotifier<Locale> {
  // Kiswahili ni lugha ya msingi kwa soko lengwa; mtumiaji anaweza kubadilisha.
  LocaleController() : super(const Locale('sw')) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('language_code');
    if (code != null && code.isNotEmpty) state = Locale(code);
  }

  Future<void> setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', locale.languageCode);
    state = locale;
  }
}

class ThemeController extends StateNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.dark) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_theme') ?? true;
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggle() async {
    final prefs = await SharedPreferences.getInstance();
    final nextMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await prefs.setBool('is_dark_theme', nextMode == ThemeMode.dark);
    state = nextMode;
  }
}

class MadiniApp extends ConsumerWidget {
  /// [dbOpener] inaweza kubadilishwa kwenye tests (hakuna plugin ya SQLCipher).
  const MadiniApp({super.key, this.dbOpener, this.lockRefresh});
  final Future<void> Function()? dbOpener;
  final Future<bool> Function()? lockRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'MADINI',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: LockGate(
        refresh: lockRefresh,
        child: DbGate(opener: dbOpener, child: const MainShell()),
      ),
    );
  }
}

/// Hufungua database kabla ya skrini zozote. Ufunguo ukipotea (mf. simu mpya)
/// huonyesha maelezo na chaguo la kuanza upya BAADA ya uthibitisho; data
/// haifutwi kimya kimya.
class DbGate extends StatefulWidget {
  const DbGate({super.key, required this.child, this.opener});
  final Widget child;
  final Future<void> Function()? opener;

  @override
  State<DbGate> createState() => _DbGateState();
}

class _DbGateState extends State<DbGate> {
  late Future<void> _future;

  @override
  void initState() {
    super.initState();
    _open();
  }

  void _open() {
    _future = (widget.opener ??
        () async {
          await LocalDatabase.instance.database;
          // Futa faili za vyeti zilizobaki (yatima) baada ya kukatizwa; si lazima.
          LocalDatabase.instance.sweepOrphanCertificateFiles().catchError((_) => 0);
        })();
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr(c, 'Futa data ya ndani?', 'Erase local data?')),
        content: Text(tr(c,
            'Hii itafuta database na vyeti vyote vilivyomo kwenye kifaa hiki kabisa. Kama una backup (.mdbak), utaweza kuirejesha baadaye. Endelea?',
            'This permanently erases the database and all certificates on this device. If you have a backup (.mdbak) you can restore it afterwards. Continue?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr(c, 'Ghairi', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr(c, 'Futa na uanze upya', 'Erase and restart'))),
        ],
      ),
    );
    if (ok != true) return;
    await LocalDatabase.instance.resetAll();
    if (mounted) setState(_open);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          final keyLost = snapshot.error is DatabaseKeyLostException;
          final corrupted = snapshot.error is DatabaseCorruptedException;
          return Scaffold(
            appBar: AppBar(title: const Text('MADINI')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    keyLost
                        ? tr(context, 'Data haiwezi kufunguliwa kwenye kifaa hiki',
                            'Data cannot be opened on this device')
                        : corrupted
                            ? tr(context, 'Database imeharibika', 'Database is corrupted')
                            : tr(context, 'Database imeshindwa kufunguka', 'Database failed to open'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text('${snapshot.error}'),
                  const SizedBox(height: 12),
                  if (corrupted)
                    Text(tr(context,
                        'Usifute chochote bado. Funga app, anzisha upya simu na ujaribu tena. Ikiendelea, chagua \"Futa na uanze upya\" kisha Mipangilio > Rejesha backup (data ya sasa itapotea; backup ndiyo njia pekee ya kurudisha).',
                        'Do not erase anything yet. Close the app, restart the phone and retry. If it persists, choose \"Erase and restart\" then Settings > Restore backup (current data is lost; a backup is the only way back).')),
                  if (keyLost)
                    Text(tr(context,
                        'Hii hutokea simu ikibadilishwa au data ya usalama ikifutwa. Rejesha kutoka kwenye backup yako: chagua "Futa na uanze upya", kisha Mipangilio > Rejesha backup.',
                        'This happens after a phone change or when secure data was cleared. Restore from your backup: choose "Erase and restart", then Settings > Restore backup.')),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => setState(_open),
                    child: Text(tr(context, 'Jaribu tena', 'Retry')),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _reset,
                    child: Text(tr(context, 'Futa na uanze upya', 'Erase and restart')),
                  ),
                ],
              ),
            ),
          );
        }
        return widget.child;
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = [
    HomeScreen(),
    SearchScreen(),
    ValuationScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: strings.get('home')),
          NavigationDestination(icon: const Icon(Icons.search_outlined), selectedIcon: const Icon(Icons.search), label: strings.get('search')),
          NavigationDestination(icon: const Icon(Icons.calculate_outlined), selectedIcon: const Icon(Icons.calculate), label: strings.get('valuation')),
          NavigationDestination(icon: const Icon(Icons.history_outlined), selectedIcon: const Icon(Icons.history), label: strings.get('history')),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: strings.get('settings')),
        ],
      ),
    );
  }
}
