import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/daily_mood.dart';
import '../services/mood_pair_repository.dart';
import '../services/participant_profile_repository.dart';
import '../theme/app_theme.dart';

class MoodPairWidget extends StatefulWidget {
  const MoodPairWidget({
    super.key,
    this.repository,
    this.profileRepository,
    this.participantNames = const {},
    this.onNameChanged,
    this.onChanged,
    this.participantSide = 'first',
    this.isActive = true,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  final MoodPairRepository? repository;
  final ParticipantProfileRepository? profileRepository;
  final Map<String, String> participantNames;
  final ValueChanged<Map<String, String>>? onNameChanged;
  final VoidCallback? onChanged;
  final String participantSide;
  final bool isActive;
  final DateTime Function() clock;

  @override
  State<MoodPairWidget> createState() => _MoodPairWidgetState();
}

class _MoodPairWidgetState extends State<MoodPairWidget> {
  late final MoodPairRepository _repository =
      widget.repository ?? SharedPreferencesMoodPairRepository();
  late final ParticipantProfileRepository _profileRepository =
      widget.profileRepository ?? ParticipantProfileRepository();
  late Future<DailyPairMood> _today = _repository.loadFor(widget.clock());
  StreamSubscription<DailyPairMood>? _subscription;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _watchForUpdates();
  }

  @override
  void didUpdateWidget(covariant MoodPairWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _today = _repository.loadFor(widget.clock());
        _watchForUpdates();
      } else {
        _subscription?.cancel();
        _subscription = null;
      }
    }
    if (moodDateKey(oldWidget.clock()) != moodDateKey(widget.clock())) {
      _subscription?.cancel();
      _today = _repository.loadFor(widget.clock());
      if (widget.isActive) _watchForUpdates();
    }
  }

  void _watchForUpdates() {
    _subscription = _repository
        .watchFor(widget.clock())
        .listen(
          (mood) {
            if (mounted) {
              setState(() {
                _today = Future.value(mood);
              });
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (mounted) {
              setState(() {
                _today = Future.error(error, stackTrace);
              });
            }
          },
        );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _record(String side, DailyMood mood) async {
    final pairMood = await _repository.record(side, mood, date: widget.clock());
    if (!mounted) return;
    setState(() {
      _today = Future.value(pairMood);
    });
    widget.onChanged?.call();
  }

  Future<void> _rename(String side) async {
    final strings = AppLocalizations.of(context)!;
    final controller = TextEditingController(
      text: widget.participantNames[side] ?? '',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.participantNameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: strings.participantNameLabel(side == 'first' ? 1 : 2),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(strings.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    await _profileRepository.saveName(side, name);
    if (!mounted) return;
    widget.onNameChanged?.call({...widget.participantNames, side: name.trim()});
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return GlassCard(
      padding: const EdgeInsets.all(17),
      child: FutureBuilder<DailyPairMood>(
        future: _today,
        builder: (context, snapshot) {
          final pairMood = snapshot.data;
          if (snapshot.hasError) {
            return Text(strings.moodPairLoadError);
          }
          if (pairMood == null) return const LinearProgressIndicator();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.moodPairTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 5),
              Text(
                _repository.isSynchronized
                    ? strings.sharedPairSyncNotice
                    : strings.localPairDemo,
              ),
              const SizedBox(height: 12),
              for (final side in ['first', 'second'])
                _ParticipantMood(
                  key: ValueKey('mood-participant-$side'),
                  side: side,
                  participant:
                      widget.participantNames[side] ??
                      (side == 'first'
                          ? strings.moodParticipantOne
                          : strings.moodParticipantTwo),
                  selected: pairMood.moods[side],
                  editable: side == widget.participantSide,
                  onRename: () => _rename(side),
                  showRename: !_repository.isSynchronized,
                  onSelect: side == widget.participantSide
                      ? (mood) => _record(side, mood)
                      : null,
                  moodLabel: (mood) => _moodLabel(strings, mood),
                ),
              if (pairMood.moods.length == 2) ...[
                const SizedBox(height: 8),
                Text(
                  _localizedReaction(strings, pairMood),
                  key: const ValueKey('mood-pair-reaction'),
                ),
              ] else
                Text(strings.moodPairWaiting),
            ],
          );
        },
      ),
    );
  }
}

String _moodLabel(AppLocalizations strings, DailyMood mood) => switch (mood) {
  DailyMood.joyful => strings.moodJoyful,
  DailyMood.calm => strings.moodCalm,
  DailyMood.thoughtful => strings.moodThoughtful,
  DailyMood.tired => strings.moodTired,
  DailyMood.blue => strings.moodBlue,
  DailyMood.angry => strings.moodAngry,
};

String _localizedReaction(AppLocalizations strings, DailyPairMood pairMood) {
  final first = pairMood.moods['first'];
  final second = pairMood.moods['second'];
  if (first == DailyMood.blue && second == DailyMood.blue) {
    return strings.moodBlueReaction;
  }
  if (first == DailyMood.joyful && second == DailyMood.joyful) {
    return strings.moodJoyfulReaction;
  }
  return strings.moodOtherReaction;
}

class _ParticipantMood extends StatelessWidget {
  const _ParticipantMood({
    super.key,
    required this.side,
    required this.participant,
    required this.selected,
    required this.editable,
    required this.onRename,
    required this.showRename,
    required this.onSelect,
    required this.moodLabel,
  });

  final String side;
  final String participant;
  final DailyMood? selected;
  final bool editable;
  final VoidCallback onRename;
  final bool showRename;
  final ValueChanged<DailyMood>? onSelect;
  final String Function(DailyMood mood) moodLabel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              participant,
              key: ValueKey('mood-participant-name-$side'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (showRename)
            IconButton(
              key: ValueKey('mood-participant-rename-$side'),
              tooltip: AppLocalizations.of(context)!.editParticipantName,
              onPressed: onRename,
              icon: const Icon(Icons.edit_rounded, size: 18),
            ),
        ],
      ),
      Wrap(
        children: [
          for (final mood in DailyMood.values)
            IconButton(
              key: ValueKey('mood-choice-$side-${mood.name}'),
              tooltip: '$participant: ${moodLabel(mood)}',
              onPressed: editable ? () => onSelect?.call(mood) : null,
              icon: Container(
                decoration: selected == mood
                    ? BoxDecoration(
                        border: Border.all(color: Colors.black, width: 1),
                      )
                    : null,
                padding: const EdgeInsets.all(2),
                child: Text(mood.emoji, style: const TextStyle(fontSize: 24)),
              ),
            ),
        ],
      ),
    ],
  );
}
