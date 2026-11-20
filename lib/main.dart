import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/temp_files.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // PBKDF2/AES-GCM za asili (native) badala ya Dart safi: PIN, backup na
  // vyeti havigandishi skrini kwenye simu za bei nafuu.
  FlutterCryptography.enable();
  await TempFiles.cleanup();
  runApp(const ProviderScope(child: MadiniApp()));
}
