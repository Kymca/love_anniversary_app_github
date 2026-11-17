import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:love_anniversary_app/models/daily_mood.dart';
import 'package:love_anniversary_app/widgets/mood_envelope.dart';

import 'test_app.dart';

void main() {
  test('mood envelope animation is sampled at 30 frames per second', () {
    expect(moodEnvelopeAnimationFramesPerSecond, 30);
    expect(moodEnvelopeFrameInterval.inMicroseconds, 33333);
    expect(moodEnvelopeFaceFrameCount, 60);
    expect(moodEnvelopeFaceFrameIndex(Duration.zero), 0);
    expect(moodEnvelopeFaceFrameIndex(const Duration(microseconds: 33334)), 1);
    expect(moodEnvelopeFaceFrameIndex(const Duration(seconds: 1)), 30);
    expect(moodEnvelopeFaceFrameIndex(const Duration(seconds: 2)), 0);
    expect(
      moodEnvelopeFaceFrameIndex(
        const Duration(seconds: 2, microseconds: 33334),
      ),
      1,
    );
  });

  testWidgets('envelope reveals mood and closes when the mood changes', (
    tester,
  ) async {
    Widget app(DailyMood mood) => localizedTestApp(
      home: Scaffold(
        body: MoodIncomingEnvelope(key: const ValueKey('envelope'), mood: mood),
      ),
    );

    await tester.pumpWidget(app(DailyMood.blue));
    expect(
      find.byTooltip('Настроение партнёра. Нажмите, чтобы открыть.'),
      findsOneWidget,
    );
    expect(
      find.image(const AssetImage('assets/images/mood_envelopes/blue.png')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('incoming-mood-envelope')));
    for (var frame = 0; frame < 23; frame++) {
      await tester.pump(const Duration(milliseconds: 34));
    }
    expect(find.byTooltip('Настроение партнёра: Грустно'), findsOneWidget);
    expect(find.byKey(const ValueKey('mood-envelope-face')), findsOneWidget);
    expect(
      find.image(
        const AssetImage('assets/images/mood_envelopes/blue_loop.png'),
      ),
      findsOneWidget,
    );
    final faceTransformFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Transform &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'mood-envelope-face-frame-',
          ),
    );
    String faceFrameKey() =>
        (tester.widget<Transform>(faceTransformFinder).key! as ValueKey<String>)
            .value;
    final firstFaceFrame = faceFrameKey();
    await tester.pump(const Duration(milliseconds: 34));
    final nextFaceFrame = faceFrameKey();
    expect(nextFaceFrame, isNot(firstFaceFrame));
    await tester.pump(const Duration(seconds: 2));
    expect(faceFrameKey(), nextFaceFrame);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(app(DailyMood.angry));
    expect(
      find.byTooltip('Настроение партнёра. Нажмите, чтобы открыть.'),
      findsOneWidget,
    );
    expect(
      find.image(
        const AssetImage('assets/images/mood_envelopes/angry_loop.png'),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('incoming-mood-envelope')));
    for (var frame = 0; frame < 23; frame++) {
      await tester.pump(const Duration(milliseconds: 34));
    }
    expect(find.byTooltip('Настроение партнёра: Злюсь'), findsOneWidget);
    expect(find.byKey(const ValueKey('mood-envelope-face')), findsOneWidget);
    expect(
      find.image(
        const AssetImage('assets/images/mood_envelopes/angry_loop.png'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('incoming-mood-envelope')));
    for (var frame = 0; frame < 23; frame++) {
      await tester.pump(const Duration(milliseconds: 34));
    }
    expect(find.byKey(const ValueKey('mood-envelope-face')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
