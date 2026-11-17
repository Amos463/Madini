// ignore_for_file: prefer_const_constructors

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('sw')];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static final LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const Map<String, Map<String, String>> _values = {
    'en': {
      'appTitle': 'MADINI',
      'home': 'Home',
      'search': 'Search',
      'valuation': 'Gold Valuation',
      'history': 'History',
      'settings': 'Settings',
      'theme': 'Theme',
      'language': 'Language',
      'labAssessment': 'Laboratory Assessment',
      'fieldAssessment': 'Field Assessment',
      'recentAssessments': 'Recent Assessments',
      'newAssessment': 'Start valuation',
      'subscription': 'Subscription',
      'trial': 'Seven-day free trial',
      'offlineLabel': 'Offline ready',
      'searchHint': 'Search ore lots, grades, notes...',
      'save': 'Save',
      'calculate': 'Calculate',
      'results': 'Results',
      'warning': 'Warning',
      'marketPrice': 'Gold price',
      'report': 'Report',
      'export': 'Export',
      'restore': 'Restore',
      'backup': 'Backup',
      'sampleIntegrity': 'Sample integrity',
    },
    'sw': {
      'appTitle': 'MADINI',
      'home': 'Nyumbani',
      'search': 'Tafuta',
      'valuation': 'Thamini ya Dhahabu',
      'history': 'Historia',
      'settings': 'Mipangilio',
      'theme': 'Mandhari',
      'language': 'Lugha',
      'labAssessment': 'Tathmini ya Maabara',
      'fieldAssessment': 'Tathmini ya Uga',
      'recentAssessments': 'Tathmini za Hivi Punde',
      'newAssessment': 'Anza tathmini',
      'subscription': 'Kusajili',
      'trial': 'Majaribio ya siku saba bila malipo',
      'offlineLabel': 'Kazi bila mtandao',
      'searchHint': 'Tafuta loti, thamani, maelezo...',
      'save': 'Hifadhi',
      'calculate': 'Kokotoa',
      'results': 'Matokeo',
      'warning': 'Onyo',
      'marketPrice': 'Bei ya dhahabu',
      'report': 'Ripoti',
      'export': 'Hamisha',
      'restore': 'Rejesha',
      'backup': 'Backup',
      'sampleIntegrity': 'Uadilifu wa sampuli',
    },
  };

  String get(String key) {
    return _values[locale.languageCode]?[key] ??
        _values['en']?[key] ??
        key;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any((supported) => supported.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture(AppLocalizations(locale));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}
