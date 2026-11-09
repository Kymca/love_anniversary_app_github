import '../models/daily_mood.dart';

enum DuckPartnerSide { first, second }

enum DuckEmotion { neutral, joyful, calm, thoughtful, tired, blue, angry }

DailyMood? duckPartnerMoodForSide(
  Map<String, DailyMood> moods,
  DuckPartnerSide side,
) => switch (side) {
  DuckPartnerSide.first => moods['second'] ?? moods['Партнёр'],
  DuckPartnerSide.second => moods['first'] ?? moods['Алина'],
};

DuckEmotion duckEmotionForMood(DailyMood? mood) => switch (mood) {
  null => DuckEmotion.neutral,
  DailyMood.joyful => DuckEmotion.joyful,
  DailyMood.calm => DuckEmotion.calm,
  DailyMood.thoughtful => DuckEmotion.thoughtful,
  DailyMood.tired => DuckEmotion.tired,
  DailyMood.blue => DuckEmotion.blue,
  DailyMood.angry => DuckEmotion.angry,
};

double duckTransitionHorizontalDirection(DuckPartnerSide side) =>
    switch (side) {
      DuckPartnerSide.first => 1,
      DuckPartnerSide.second => -1,
    };
