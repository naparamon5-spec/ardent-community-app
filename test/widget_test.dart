// Smoke test for the Ardent Hub app shell and login flow.

import 'package:flutter_test/flutter_test.dart';

import 'package:ardent_community/main.dart';

void main() {
  testWidgets('Unauthenticated launch shows Ardent Hub welcome and sign-in flow',
      (WidgetTester tester) async {
    // No token is loaded in the test harness, so the AuthGate renders LoginScreen.
    await tester.pumpWidget(const ArdentCommunityApp());
    await tester.pumpAndSettle();

    // Verify Welcome Hero UI elements
    expect(find.text('Your Community, In One Place'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Grow'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);

    // Tap "Sign In" to switch to sign-in form
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    // Verify Sign In form is shown
    expect(find.text('Work email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
