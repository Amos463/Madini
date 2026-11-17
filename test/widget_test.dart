import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:madini/app.dart';

void main() {
  testWidgets('Madini app loads the home screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MadiniApp()));
    await tester.pumpAndSettle();

    expect(find.text('MADINI'), findsWidgets);
  });
}
