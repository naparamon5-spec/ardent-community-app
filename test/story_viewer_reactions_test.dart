import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ardent_community/data/seed.dart';
import 'package:ardent_community/screens/story_viewer_screen.dart';

void main() {
  testWidgets('StoryViewerScreen displays minimized reaction emojis and selects on tap',
      (WidgetTester tester) async {
    final testStory = Story(
      'Jane Doe',
      'JD',
      Colors.blue,
      id: '',
      authorId: 'user-2',
      isMine: false,
      caption: 'Having fun today!',
      media: [
        MediaItem(
          id: '',
          url: '',
          type: 'image',
          caption: 'My caption',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StoryViewerScreen(
          stories: [testStory],
          initialIndex: 0,
        ),
      ),
    );
    await tester.pump();

    // Verify quick reaction emojis are present
    expect(find.text('👍'), findsOneWidget);
    expect(find.text('❤️'), findsOneWidget);
    expect(find.text('😆'), findsOneWidget);
    expect(find.text('😮'), findsOneWidget);
    expect(find.text('😢'), findsOneWidget);
    expect(find.text('🙏'), findsOneWidget);

    // Tap ❤️ reaction
    await tester.tap(find.text('❤️'));
    await tester.pump();

    // Should indicate "You reacted " with ❤️
    expect(find.text('You reacted '), findsOneWidget);

    // Pump animation frames to ensure floating particles animate and complete cleanly
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pumpAndSettle();
  });

  testWidgets('StoryViewerScreen automatically floats reaction when viewing a story with already selected reaction',
      (WidgetTester tester) async {
    final reactedStory = Story(
      'Jane Doe',
      'JD',
      Colors.blue,
      id: '',
      authorId: 'user-2',
      isMine: false,
      caption: 'Having fun today!',
      media: [
        MediaItem(
          id: '',
          url: '',
          type: 'image',
          caption: 'My caption',
          myReaction: '😆',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StoryViewerScreen(
          stories: [reactedStory],
          initialIndex: 0,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // "You reacted " with 😆 is visible
    expect(find.text('You reacted '), findsOneWidget);
    expect(find.text('😆'), findsWidgets); // appears in button and floating overlay

    // Pump animation frames to ensure floating particles complete cleanly
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pumpAndSettle();
  });
}
