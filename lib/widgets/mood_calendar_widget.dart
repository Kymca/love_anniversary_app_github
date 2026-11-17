import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/daily_mood.dart';
import '../services/mood_pair_repository.dart';
import '../services/pair_repository.dart';
import '../services/participant_profile_repository.dart';
import '../theme/app_theme.dart';

class MoodCalendarWidget extends StatefulWidget {
  const MoodCalendarWidget({
    super.key,
    this.repository,
    this.pairRepository,
    this.profileRepository,
    this.isActive = true,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  final MoodPairRepository? repository;
  final PairRepository? pairRepository;
  final ParticipantProfileRepository? profileRepository;
  final bool isActive;
  final DateTime Function() clock;

  @override
  State<MoodCalendarWidget> createState() => _MoodCalendarWidgetState();
}

class _MoodCalendarWidgetState extends State<MoodCalendarWidget> {
  late final ParticipantProfileRepository _profileRepository =
      widget.profileRepository ?? ParticipantProfileRepository();
  late final MoodPairRepository _repository =
      widget.repository ??
      SharedPreferencesMoodPairRepository(
        profileRepository: _profileRepository,
      );
  late final PairRepository _pairRepository =
      widget.pairRepository ?? SharedPreferencesPairRepository();
  String _participantSide = 'first';
  Map<String, String> _participantNames = const {};
  late DateTime _today = widget.clock();
  late DateTime _displayMonth = DateTime(_today.year, _today.month);
  late DateTime _selectedDate = _today;
  Future<Map<String, List<DailyMoodEntry>>> _entriesFuture = Future.value(
    const {'first': <DailyMoodEntry>[], 'second': <DailyMoodEntry>[]},
  );
  DailyMoodEntry? _todayEntry;
  DailyMoodEntry? _partnerTodayEntry;
  Timer? _timer;
  StreamSubscription<void>? _moodSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _loadParticipant();
      _loadToday();
      _watchMoodUpdates();
      _startClock();
    }
  }

  @override
  void didUpdateWidget(covariant MoodCalendarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive == oldWidget.isActive) return;
    if (widget.isActive) {
      _today = widget.clock();
      _entriesFuture = _loadHistory();
      _loadParticipant();
      _loadToday();
      _watchMoodUpdates();
      _startClock();
    } else {
      _timer?.cancel();
      _moodSubscription?.cancel();
      _moodSubscription = null;
    }
  }

  void _startClock() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      final now = widget.clock();
      if (moodDateKey(now) != moodDateKey(_today) && mounted) {
        setState(() {
          _today = now;
          _displayMonth = DateTime(now.year, now.month);
          _selectedDate = now;
          _entriesFuture = _loadHistory();
          _todayEntry = null;
        });
        _moodSubscription?.cancel();
        _watchMoodUpdates();
        _loadToday();
      }
    });
  }

  Future<void> _loadParticipant() async {
    final side = await _profileRepository.loadCurrentSide();
    if (!mounted) return;
    setState(() {
      _participantSide = side;
      _entriesFuture = _loadHistory();
    });
    final pair = await _pairRepository.loadActivePair();
    final names = await _profileRepository.loadNames(pair: pair);
    if (mounted) setState(() => _participantNames = names);
    await _loadToday();
  }

  Future<Map<String, List<DailyMoodEntry>>> _loadHistory() async {
    final pair = await _pairRepository.loadActivePair();
    final names = await _profileRepository.loadNames(pair: pair);
    if (mounted && names != _participantNames) {
      _participantNames = names;
    }
    return {
      for (final side in const ['first', 'second'])
        side: await _repository.historyForParticipant(side),
    };
  }

  void _watchMoodUpdates() {
    if (!widget.isActive) return;
    _moodSubscription = _repository.watchChanges().listen(
      (_) {
        if (!mounted) return;
        setState(() {
          _entriesFuture = _loadHistory();
        });
        _loadToday();
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) return;
        setState(() {
          _entriesFuture = Future.error(error, stackTrace);
        });
      },
    );
  }

  Future<void> _loadToday() async {
    final history = await _repository.historyFor(_participantSide, _today);
    final entry = history.isEmpty ? null : history.last;
    final partnerSide = _participantSide == 'first' ? 'second' : 'first';
    final partnerHistory = await _repository.historyFor(partnerSide, _today);
    if (mounted) {
      setState(() {
        _todayEntry = entry;
        _partnerTodayEntry = partnerHistory.isEmpty
            ? null
            : partnerHistory.last;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _moodSubscription?.cancel();
    super.dispose();
  }

  Future<void> _selectMood(DailyMood mood) async {
    await _recordMood(_today, mood);
  }

  Future<void> _recordMood(DateTime date, DailyMood mood) async {
    final pair = await _repository.record(_participantSide, mood, date: date);
    if (!mounted) return;
    final history = await _repository.historyFor(_participantSide, date);
    final entry = history.isEmpty ? null : history.last;
    if (pair.moods[_participantSide] != mood) {
      throw StateError('Saved mood does not match the selected mood.');
    }
    setState(() {
      if (moodDateKey(date) == moodDateKey(_today)) _todayEntry = entry;
      _entriesFuture = _loadHistory();
    });
    if (moodDateKey(date) == moodDateKey(_today)) await _loadToday();
  }

  Future<void> _changeMood(DateTime date) async {
    final strings = AppLocalizations.of(context)!;
    final mood = await showDialog<DailyMood>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.moodChangeTitle),
        content: Wrap(
          children: [
            for (final mood in DailyMood.values)
              IconButton(
                key: ValueKey('mood-dialog-choice-${mood.name}'),
                tooltip: _moodLabel(strings, mood),
                onPressed: () => Navigator.pop(context, mood),
                icon: Text(mood.emoji, style: const TextStyle(fontSize: 28)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.cancel),
          ),
        ],
      ),
    );
    if (mood != null) await _recordMood(date, mood);
  }

  void _selectDate(DateTime date) {
    setState(() => _selectedDate = date);
    _moodSubscription?.cancel();
    _watchMoodUpdates();
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
          child: SingleChildScrollView(
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
                              key: ValueKey(
                                'mood-calendar-choice-${mood.name}',
                              ),
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
                  _TodayMoodCard(
                    entry: _todayEntry!,
                    partnerEntry: _partnerTodayEntry,
                    partnerName:
                        _participantNames[_participantSide == 'first'
                            ? 'second'
                            : 'first'] ??
                        strings.moodParticipantTwo,
                    onChange: () => _changeMood(_today),
                  ),
                if (_todayEntry == null && _partnerTodayEntry != null)
                  Text(
                    '${_participantNames[_participantSide == 'first' ? 'second' : 'first'] ?? strings.moodParticipantTwo}: '
                    '${_partnerTodayEntry!.mood.emoji} '
                    '${_moodLabel(strings, _partnerTodayEntry!.mood)}',
                    key: const ValueKey('partner-today-mood'),
                  ),
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
                FutureBuilder<Map<String, List<DailyMoodEntry>>>(
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
                      selectedDate: _selectedDate,
                      names: _participantNames,
                      onSelectDate: _selectDate,
                    );
                  },
                ),
                FutureBuilder<Map<String, List<DailyMoodEntry>>>(
                  future: _entriesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasError || !snapshot.hasData) {
                      return const SizedBox.shrink();
                    }
                    final history = {
                      for (final side in const ['first', 'second'])
                        side: (snapshot.data![side] ?? const <DailyMoodEntry>[])
                            .where(
                              (entry) =>
                                  entry.dateKey == moodDateKey(_selectedDate),
                            )
                            .toList(),
                    };
                    return _SelectedDateHistory(
                      date: _selectedDate,
                      entries: history,
                      names: _participantNames,
                      onChange: () => _changeMood(_selectedDate),
                    );
                  },
                ),
              ],
            ),
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
  const _TodayMoodCard({
    required this.entry,
    required this.partnerEntry,
    required this.partnerName,
    required this.onChange,
  });

  final DailyMoodEntry entry;
  final DailyMoodEntry? partnerEntry;
  final String partnerName;
  final VoidCallback onChange;

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
                  if (partnerEntry != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$partnerName: ${partnerEntry!.mood.emoji} '
                      '${_moodLabel(strings, partnerEntry!.mood)}',
                      key: const ValueKey('partner-today-mood'),
                    ),
                  ],
                  const SizedBox(height: 6),
                  TextButton.icon(
                    key: const ValueKey('change-today-mood'),
                    onPressed: onChange,
                    icon: const Icon(Icons.edit_rounded, size: 17),
                    label: Text(strings.moodChange),
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

class _SelectedDateHistory extends StatelessWidget {
  const _SelectedDateHistory({
    required this.date,
    required this.entries,
    required this.names,
    required this.onChange,
  });

  final DateTime date;
  final Map<String, List<DailyMoodEntry>> entries;
  final Map<String, String> names;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final materialStrings = MaterialLocalizations.of(context);
    final allEntries = [
      for (final side in const ['first', 'second'])
        for (final entry in entries[side] ?? const <DailyMoodEntry>[])
          (side: side, entry: entry),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.lavender.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.moodHistoryForDate(
                  materialStrings.formatMediumDate(date),
                ),
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (allEntries.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(strings.moodNoHistory),
                )
              else
                for (var index = 0; index < allEntries.length; index++)
                  _HistoryEntry(
                    entry: allEntries[index].entry,
                    participant:
                        names[allEntries[index].side] ??
                        (allEntries[index].side == 'first'
                            ? strings.moodParticipantOne
                            : strings.moodParticipantTwo),
                    isLatest: index == allEntries.length - 1,
                  ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('change-selected-date-mood'),
                  onPressed: onChange,
                  icon: const Icon(Icons.edit_rounded, size: 17),
                  label: Text(strings.moodChange),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryEntry extends StatelessWidget {
  const _HistoryEntry({
    required this.entry,
    required this.participant,
    required this.isLatest,
  });

  final DailyMoodEntry entry;
  final String participant;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final time = entry.recordedAt == null
        ? strings.moodHistoryTimeUnknown
        : MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(entry.recordedAt!.toLocal()),
          );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Text(entry.mood.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$participant · $time · ${_moodLabel(strings, entry.mood)}'
              '${isLatest ? ' · ${strings.moodHistoryLatest}' : ''}',
              style: const TextStyle(color: AppColors.ink),
            ),
          ),
        ],
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
  const _MonthGrid({
    required this.month,
    required this.entries,
    required this.selectedDate,
    required this.names,
    required this.onSelectDate,
  });

  final DateTime month;
  final Map<String, List<DailyMoodEntry>> entries;
  final DateTime selectedDate;
  final Map<String, String> names;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final first = DateTime(month.year, month.month);
    final offset = first.weekday - 1;
    final dayCount = DateTime(month.year, month.month + 1, 0).day;
    final entriesByDate = <String, Map<String, DailyMoodEntry>>{};
    for (final side in const ['first', 'second']) {
      for (final entry in entries[side] ?? const <DailyMoodEntry>[]) {
        entriesByDate.putIfAbsent(entry.dateKey, () => {})[side] = entry;
      }
    }
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
        final dateKey = moodDateKey(date);
        final dayEntries = entriesByDate[dateKey] ?? const {};
        final moodSummary = [
          for (final side in const ['first', 'second'])
            if (dayEntries[side] case final entry?)
              '${names[side] ?? (side == 'first' ? strings.moodParticipantOne : strings.moodParticipantTwo)} '
                  '${_moodLabel(strings, entry.mood)}',
        ].join(', ');
        return Semantics(
          button: true,
          label: moodSummary.isEmpty ? '$day' : '$day, $moodSummary',
          child: InkWell(
            key: ValueKey('mood-calendar-date-$dateKey'),
            borderRadius: BorderRadius.circular(18),
            onTap: () => onSelectDate(date),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: dateKey == moodDateKey(selectedDate)
                    ? AppColors.lavender.withValues(alpha: 0.8)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: dayEntries.isEmpty
                    ? Text(
                        '$day',
                        style: const TextStyle(
                          color: AppColors.mutedInk,
                          fontSize: 12,
                        ),
                      )
                    : Tooltip(
                        message: moodSummary,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final side in const ['first', 'second'])
                              if (dayEntries[side] case final entry?)
                                Flexible(
                                  child: Text(
                                    entry.mood.emoji,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
