import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/countdown_event.dart';
import '../services/countdown_repository.dart';
import '../theme/app_theme.dart';

class CountdownWidget extends StatefulWidget {
  const CountdownWidget({
    super.key,
    this.repository,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  final CountdownRepository? repository;
  final DateTime Function() clock;

  @override
  State<CountdownWidget> createState() => _CountdownWidgetState();
}

class _CountdownWidgetState extends State<CountdownWidget> {
  late final CountdownRepository _repository =
      widget.repository ?? CountdownRepository();
  List<CountdownEvent>? _events;
  Object? _loadError;
  bool _isLoading = true;
  late DateTime _now = widget.clock();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _reload();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = widget.clock());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final events = await _repository.load();
      if (!mounted) return;
      setState(() {
        _events = events;
        _loadError = null;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _edit([CountdownEvent? event]) async {
    final result = await showDialog<_CountdownFormResult>(
      context: context,
      builder: (context) =>
          _CountdownFormDialog(event: event, now: widget.clock()),
    );
    if (result == null || !mounted) return;
    try {
      if (event == null) {
        await _repository.add(title: result.title, eventDate: result.date);
      } else {
        await _repository.update(
          id: event.id,
          title: result.title,
          eventDate: result.date,
        );
      }
      await _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.saveEventError(error.toString()),
            ),
          ),
        );
      }
    }
  }

  Future<void> _delete(CountdownEvent event) async {
    try {
      await _repository.delete(event.id);
      await _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.deleteEventError(error.toString()),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.event_available_rounded, color: AppColors.rose),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                strings.countdownTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: strings.addEvent,
              onPressed: () => _edit(),
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
          ],
        ),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_loadError != null)
          _CountdownMessage(strings.countdownLoadError)
        else if (_events!.isEmpty)
          _CountdownMessage(strings.countdownEmpty)
        else
          Column(
            children: [
              for (final event in _events!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CountdownEventCard(
                    event: event,
                    now: _now,
                    onEdit: () => _edit(event),
                    onDelete: () => _delete(event),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _CountdownMessage extends StatelessWidget {
  const _CountdownMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(15),
    child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
  );
}

class _CountdownEventCard extends StatelessWidget {
  const _CountdownEventCard({
    required this.event,
    required this.now,
    required this.onEdit,
    required this.onDelete,
  });

  final CountdownEvent event;
  final DateTime now;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final eventDay = DateTime(
      event.eventDate.year,
      event.eventDate.month,
      event.eventDate.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    final passed = eventDay.isBefore(today);
    final daysLeft = eventDay.difference(today).inDays.clamp(0, 100000);
    final date = MaterialLocalizations.of(context).formatMediumDate(
      DateTime(
        event.eventDate.year,
        event.eventDate.month,
        event.eventDate.day,
      ),
    );
    final progress = event.progressAt(now);
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 13, 8, 14),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                tooltip: strings.editEventNamed(event.title),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 19),
              ),
              IconButton(
                tooltip: strings.deleteEventNamed(event.title),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 19),
              ),
            ],
          ),
          Text(
            passed ? strings.eventPassed(date) : strings.untilEvent(date),
            style: const TextStyle(color: AppColors.mutedInk, fontSize: 13),
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 750),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: AppColors.lavender,
                color: passed ? AppColors.teal : AppColors.rose,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            passed
                ? strings.rememberThisDay
                : daysLeft == 0
                ? strings.eventToday
                : strings.daysRemaining(daysLeft),
            style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CountdownFormResult {
  const _CountdownFormResult(this.title, this.date);

  final String title;
  final DateTime date;
}

class _CountdownFormDialog extends StatefulWidget {
  const _CountdownFormDialog({required this.event, required this.now});

  final CountdownEvent? event;
  final DateTime now;

  @override
  State<_CountdownFormDialog> createState() => _CountdownFormDialogState();
}

class _CountdownFormDialogState extends State<_CountdownFormDialog> {
  late final TextEditingController _titleController = TextEditingController(
    text: widget.event?.title ?? '',
  );
  late DateTime _date =
      widget.event?.eventDate ??
      DateTime(widget.now.year, widget.now.month, widget.now.day + 1);

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTitleChanged);
  }

  void _onTitleChanged() => setState(() {});

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(widget.now.year + 100),
    );
    if (date != null) setState(() => _date = date);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final date = MaterialLocalizations.of(context).formatMediumDate(_date);
    return AlertDialog(
      title: Text(
        widget.event == null ? strings.newEvent : strings.editEvent,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            autofocus: true,
            maxLength: 60,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: strings.eventTitleHint),
          ),
          TextButton.icon(
            onPressed: _chooseDate,
            icon: const Icon(Icons.calendar_today_rounded),
            label: Text(date),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: _titleController.text.trim().isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  _CountdownFormResult(_titleController.text.trim(), _date),
                ),
          child: Text(strings.save),
        ),
      ],
    );
  }
}
