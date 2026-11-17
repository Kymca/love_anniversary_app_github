import 'package:flutter_test/flutter_test.dart';
import 'package:love_anniversary_app/models/daily_mood.dart';
import 'package:love_anniversary_app/widgets/duck_mood.dart';

void main() {
  test('each duck displays the opposite participant mood for either side', () {
    final moods = {'first': DailyMood.angry, 'second': DailyMood.joyful};

    expect(
      duckEmotionForMood(duckPartnerMoodForSide(moods, DuckPartnerSide.first)),
      DuckEmotion.joyful,
    );
    expect(
      duckEmotionForMood(duckPartnerMoodForSide(moods, DuckPartnerSide.second)),
      DuckEmotion.angry,
    );

    final switchedMoods = {'first': DailyMood.calm, 'second': DailyMood.blue};
    expect(
      duckPartnerMoodForSide(switchedMoods, DuckPartnerSide.first),
      DailyMood.blue,
    );
    expect(
      duckPartnerMoodForSide(switchedMoods, DuckPartnerSide.second),
      DailyMood.calm,
    );
  });
}
