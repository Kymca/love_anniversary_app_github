import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/daily_mood.dart';
import '../services/mood_repository.dart';
import '../theme/app_theme.dart';

class MoodCalendarWidget extends StatefulWidget {
  const MoodCalendarWidget({
    super.key,
    this.repository,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  final MoodRepository? repository;
  final DateTime Function() clock;

  @override
  State<MoodCalendarWidget> createState() => _MoodCalendarWidgetState();
}

class _MoodCalendarWidgetState extends State<MoodCalendarWidget> {
  late final MoodRepository _repository = widget.repository ?? MoodRepository();
  late DateTime _today = widget.clock();
  late DateTime _displayMonth = DateTime(_today.year, _today.month);
  late Future<List<DailyMoodEntry>> _entriesFuture = _repository.load();
  DailyMoodEntry? _todayEntry;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadToday();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      final now = widget.clock();
      if (moodDateKey(now) != moodDateKey(_today) && mounted) {
        setState(() {
          _today = now;
          _displayMonth = DateTime(now.year, now.month);
          _entriesFuture = _repository.load();
          _todayEntry = null;
        });
        _loadToday();
      }
    });
  }

  Future<void> _loadToday() async {
    final entry = await _repository.entryFor(_today);
    if (mounted) setState(() => _todayEntry = entry);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _selectMood(DailyMood mood) async {
    final entry = await _repository.recordToday(mood, now: widget.clock());
    if (!mounted) return;
    if (entry == null) {
      setState(() => _todayEntry ??= null);
      return;
    }
    setState(() {
      _todayEntry = entry;
      _entriesFuture = _repository.load();
    });
  }

  void _changeMonth(int amount) {
    setState(() {
      _displayMonth = DateTime(
        _displayMonth.year,
        _displayMonth.month + amount,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final monthLabel = MaterialLocalizations.of(context)
        .formatMonthYear(_displayMonth);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: GlassCard(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.moodCalendarTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                strings.moodTodayPrompt,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (_todayEntry == null)
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    for (final mood in DailyMood.values)
                      Tooltip(
                        message: _moodLabel(strings, mood),
                        child: Semantics(
                          button: true,
                          label: _moodLabel(strings, mood),
                          child: IconButton(
                            onPressed: () => _selectMood(mood),
                            icon: Text(
                              mood.emoji,
                              style: const TextStyle(fontSize: 27),
                            ),
                          ),
                        ),
                      ),
                  ],
                )
              else
                _TodayMoodCard(entry: _todayEntry!),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    tooltip: strings.previousMonth,
                    onPressed: () => _changeMonth(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      monthLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: strings.nextMonth,
                    onPressed: () => _changeMonth(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              _WeekdayHeader(
                labels: [
                  strings.weekdayMon,
                  strings.weekdayTue,
                  strings.weekdayWed,
                  strings.weekdayThu,
                  strings.weekdayFri,
                  strings.weekdaySat,
                  strings.weekdaySun,
                ],
              ),
              const SizedBox(height: 5),
              FutureBuilder<List<DailyMoodEntry>>(
                future: _entriesFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(strings.moodHistoryError);
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return _MonthGrid(
                    month: _displayMonth,
                    entries: snapshot.data!,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _moodCompliment(AppLocalizations strings, DailyMoodEntry entry) {
  final dayNumber = int.parse(
    entry.dateKey.substring(entry.dateKey.length - 2),
  );
  final variant = dayNumber % 3;
  final responses = switch (entry.mood) {
    DailyMood.joyful => [
      strings.moodJoyfulResponseOne,
      strings.moodJoyfulResponseTwo,
      strings.moodJoyfulResponseThree,
    ],
    DailyMood.calm => [
      strings.moodCalmResponseOne,
      strings.moodCalmResponseTwo,
      strings.moodCalmResponseThree,
    ],
    DailyMood.thoughtful => [
      strings.moodThoughtfulResponseOne,
      strings.moodThoughtfulResponseTwo,
      strings.moodThoughtfulResponseThree,
    ],
    DailyMood.tired => [
      strings.moodTiredResponseOne,
      strings.moodTiredResponseTwo,
      strings.moodTiredResponseThree,
    ],
    DailyMood.blue => [
      strings.moodBlueResponseOne,
      strings.moodBlueResponseTwo,
      strings.moodBlueResponseThree,
    ],
    DailyMood.angry => [
      strings.moodAngryResponseOne,
      strings.moodAngryResponseTwo,
      strings.moodAngryResponseThree,
    ],
  };
  return responses[variant];
}

String _moodLabel(AppLocalizations strings, DailyMood mood) => switch (mood) {
  DailyMood.joyful => strings.moodJoyful,
  DailyMood.calm => strings.moodCalm,
  DailyMood.thoughtful => strings.moodThoughtful,
  DailyMood.tired => strings.moodTired,
  DailyMood.blue => strings.moodBlue,
  DailyMood.angry => strings.moodAngry,
};

class _TodayMoodCard extends StatelessWidget {
  const _TodayMoodCard({required this.entry});

  final DailyMoodEntry entry;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.lavender.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.mood.emoji, style: const TextStyle(fontSize: 25)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.moodToday(_moodLabel(strings, entry.mood)),
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _moodCompliment(strings, entry),
                    style: const TextStyle(color: AppColors.mutedInk),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader({required this.labels});
  final List<String> labels;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final label in labels)
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.mutedInk,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
    ],
  );
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.entries});

  final DateTime month;
  final List<DailyMoodEntry> entries;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final first = DateTime(month.year, month.month);
    final offset = first.weekday - 1;
    final dayCount = DateTime(month.year, month.month + 1, 0).day;
    final entryByDate = {for (final entry in entries) entry.dateKey: entry};
    final count = ((offset + dayCount + 6) ~/ 7) * 7;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 2,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) {
        final day = index - offset + 1;
        if (day < 1 || day > dayCount) return const SizedBox.shrink();
        final date = DateTime(month.year, month.month, day);
        final entry = entryByDate[moodDateKey(date)];
        return Semantics(
          label: entry == null
              ? '$day'
              : '$day, ${_moodLabel(strings, entry.mood)}',
          child: Center(
            child: entry == null
                ? Text(
                    '$day',
                    style: const TextStyle(
                      color: AppColors.mutedInk,
                      fontSize: 12,
                    ),
                  )
                : Tooltip(
                    message: _moodLabel(strings, entry.mood),
                    child: Text(
                      entry.mood.emoji,
                      style: const TextStyle(fontSize: 19),
                    ),
                  ),
          ),
        );
      },
    );
  }
}
