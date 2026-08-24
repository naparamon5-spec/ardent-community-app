// Smoke test for the Ardent Community app shell.

import 'package:flutter_test/flutter_test.dart';

import 'package:ardent_community/main.dart';

void main() {
  testWidgets('App renders the Ardent Community home shell',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ArdentCommunityApp());
    await tester.pump();

    expect(find.text('Ardent Community'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });
}
