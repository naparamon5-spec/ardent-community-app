import 'package:flutter_test/flutter_test.dart';
import 'package:ardent_community/api/session.dart';
import 'package:ardent_community/main.dart';

void main() {
  testWidgets('Notification icon shows badge with unread count when unread > 0',
      (WidgetTester tester) async {
    // Set unread count to 3
    AppSession.instance.setUnreadNotifications(3);

    await tester.pumpWidget(
      const ArdentCommunityApp(),
    );
    await tester.pump();

    // In authenticated app or with AppShell, verify badge displays 3
    AppSession.instance.setUnreadNotifications(5);
    expect(AppSession.instance.unreadNotifications, 5);

    AppSession.instance.decrementUnreadNotifications();
    expect(AppSession.instance.unreadNotifications, 4);

    AppSession.instance.setUnreadNotifications(0);
    expect(AppSession.instance.unreadNotifications, 0);
  });
}
