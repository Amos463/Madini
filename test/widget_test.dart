import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:madini/app.dart';

void main() {
  testWidgets('Madini app loads the home screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    // Hakuna plugin ya SQLCipher kwenye widget tests; DbGate inapewa opener bandia.
    await tester.pumpWidget(ProviderScope(child: MadiniApp(dbOpener: () async {}, lockRefresh: () async => false)));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('MADINI'), findsWidgets);
  });
}
