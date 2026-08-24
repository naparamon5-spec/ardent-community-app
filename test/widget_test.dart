// Smoke test for the Ardent Community app shell.

import 'package:flutter_test/flutter_test.dart';

import 'package:ardent_community/main.dart';

void main() {
  testWidgets('Unauthenticated launch shows the login screen',
      (WidgetTester tester) async {
    // No token is loaded in the test harness, so the AuthGate renders login.
    await tester.pumpWidget(const ArdentCommunityApp());
    await tester.pump();

    expect(find.text('Ardent Community'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Work email'), findsOneWidget);
  });
}
