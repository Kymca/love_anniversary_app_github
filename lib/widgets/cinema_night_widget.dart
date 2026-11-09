import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/daily_cinema.dart';
import '../services/daily_cinema_repository.dart';
import '../theme/app_theme.dart';

class CinemaNightWidget extends StatefulWidget {
  const CinemaNightWidget({
    super.key,
    DateTime Function()? clock,
    this.repository,
    this.random = math.Random.new,
  }) : clock = clock ?? DateTime.now;

  final DateTime Function() clock;
  final DailyCinemaRepository? repository;
  final math.Random Function() random;

  @override
  State<CinemaNightWidget> createState() => _CinemaNightWidgetState();
}

class _CinemaNightWidgetState extends State<CinemaNightWidget>
    with SingleTickerProviderStateMixin {
  late final DailyCinemaRepository _repository =
      widget.repository ?? SharedPreferencesDailyCinemaRepository();
  late final math.Random _random = widget.random();
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4000),
  );
  late DailyCinemaLineup _lineup = DailyCinemaLineup(
    localDate: '',
    movies: const [],
    winnerIndex: -1,
  );
  List<DailyCinemaFilm> _availableFilms = const [];
  final _filmController = TextEditingController();
  Timer? _midnightTimer;
  DailyCinemaFilm? _result;
  bool _hasSpun = false;
  bool _decisionMade = false;
  bool _wasSkipped = false;
  bool _isLoading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _refreshLineup();
    _scheduleMidnightRefresh();
  }

  @override
  void didUpdateWidget(covariant CinemaNightWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshLineup();
    _scheduleMidnightRefresh();
  }

  Future<void> _refreshLineup({bool clearResult = true}) async {
    try {
      final now = widget.clock();
      final films = await _repository.loadAvailableFilms(now);
      if (!mounted) return;
      setState(() {
        _availableFilms = films;
        _lineup = dailyCinemaLineup(now, candidates: films, random: _random);
        _isLoading = false;
        _loadFailed = false;
        if (clearResult) {
          _result = null;
          _hasSpun = false;
          _decisionMade = false;
          _wasSkipped = false;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadFailed = true;
        });
      }
    }
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = widget.clock().toLocal();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now), () {
      if (!mounted) return;
      _refreshLineup();
      _scheduleMidnightRefresh();
    });
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    _spin.dispose();
    _filmController.dispose();
    super.dispose();
  }

  Future<void> _spinWheel() async {
    if (_spin.isAnimating || _isLoading || _loadFailed) return;
    final now = widget.clock();
    try {
      final films = await _repository.loadAvailableFilms(now);
      if (!mounted) return;
      if (films.isEmpty) {
        setState(() {
          _availableFilms = const [];
          _lineup = DailyCinemaLineup(
            localDate: _lineup.localDate,
            movies: const [],
            winnerIndex: -1,
          );
          _result = null;
          _hasSpun = false;
        });
        return;
      }

      final lineup = dailyCinemaLineup(now, candidates: films, random: _random);
      setState(() {
        _availableFilms = films;
        _lineup = lineup;
        _result = null;
        _hasSpun = false;
        _decisionMade = false;
        _wasSkipped = false;
      });
      await _spin.forward(from: 0);
      if (mounted) {
        setState(() {
          _result = lineup.winner;
          _hasSpun = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadFailed = true);
      }
    }
  }

  Future<void> _markWatched() async {
    setState(() => _decisionMade = true);
  }

  Future<void> _skipForAWeek() async {
    final film = _result;
    if (film == null) return;
    try {
      await _repository.snoozeFilmForWeek(film.id, widget.clock());
      if (!mounted) return;
      setState(() {
        _decisionMade = true;
        _wasSkipped = true;
      });
      await _refreshLineup(clearResult: false);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.cinemaActionError),
          ),
        );
      }
    }
  }

  Future<void> _addFilm() async {
    final title = _filmController.text.trim();
    if (title.isEmpty) return;
    try {
      await _repository.addCustomFilm(title);
      if (!mounted) return;
      _filmController.clear();
      await _refreshLineup();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.cinemaActionError),
          ),
        );
      }
    }
  }

  Future<void> _removeForToday(DailyCinemaFilm film) async {
    try {
      await _repository.removeFilmForToday(film.id, widget.clock());
      if (!mounted) return;
      await _refreshLineup(clearResult: _result?.id == film.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.cinemaActionError),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final language = Localizations.localeOf(context).languageCode;
    final titles = _lineup.movies
        .map((movie) => movie.titleFor(language))
        .toList();
    final spinAngle = _lineup.winnerIndex < 0
        ? 0.0
        : dailyCinemaRotationForWinner(
            _lineup.winnerIndex,
            filmCount: _lineup.movies.length,
          );
    return GlassCard(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.cinemaTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 5),
          Text(strings.cinemaDailyNotice),
          const SizedBox(height: 12),
          Center(
            child: SizedBox.square(
              dimension: 264,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  AnimatedBuilder(
                    animation: _spin,
                    builder: (context, _) {
                      final progress = Curves.easeOutCubic.transform(
                        _spin.value,
                      );
                      return Transform.rotate(
                        angle: spinAngle * progress,
                        child: CustomPaint(
                          key: const ValueKey('daily-cinema-wheel'),
                          size: const Size.square(264),
                          painter: _CinemaWheelPainter(titles),
                        ),
                      );
                    },
                  ),
                  AnimatedBuilder(
                    animation: _spin,
                    builder: (context, _) => IgnorePointer(
                      child: CustomPaint(
                        size: const Size.square(264),
                        painter: _HeartBurstPainter(
                          Curves.easeOutCubic.transform(_spin.value),
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    top: -4,
                    child: Icon(
                      key: ValueKey('daily-cinema-pointer'),
                      Icons.arrow_drop_down_rounded,
                      size: 38,
                      color: Color(0xFFB55271),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_loadFailed)
            Text(
              strings.cinemaActionError,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else if (_availableFilms.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(strings.cinemaNoFilms, textAlign: TextAlign.center),
            ),
          if (_hasSpun && _result != null) ...[
            const SizedBox(height: 12),
            Container(
              key: const ValueKey('daily-cinema-result'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.rose.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                strings.cinemaTodayMovie(_result!.titleFor(language)),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (!_decisionMade) ...[
              const SizedBox(height: 10),
              Text(strings.cinemaWatchPrompt, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('daily-cinema-watched'),
                      onPressed: _markWatched,
                      child: Text(strings.cinemaWatched),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      key: const ValueKey('daily-cinema-skip-week'),
                      onPressed: _skipForAWeek,
                      child: Text(strings.cinemaSkipWeek),
                    ),
                  ),
                ],
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _wasSkipped
                      ? strings.cinemaSkippedSaved
                      : strings.cinemaWatchedSaved,
                  textAlign: TextAlign.center,
                ),
              ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('daily-cinema-spin'),
            onPressed:
                _spin.isAnimating ||
                    _isLoading ||
                    _loadFailed ||
                    _availableFilms.isEmpty
                ? null
                : _spinWheel,
            icon: const Icon(Icons.casino_rounded),
            label: Text(strings.cinemaSpin),
          ),
          const SizedBox(height: 16),
          Text(
            strings.cinemaManageFilms,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('daily-cinema-film-input'),
                  controller: _filmController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addFilm(),
                  decoration: InputDecoration(hintText: strings.cinemaFilmHint),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                key: const ValueKey('daily-cinema-add-film'),
                tooltip: strings.cinemaAddFilm,
                onPressed: _addFilm,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          if (_availableFilms.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final film in _availableFilms)
                  InputChip(
                    key: ValueKey('daily-cinema-remove-${film.id}'),
                    label: Text(film.titleFor(language)),
                    onDeleted: () => _removeForToday(film),
                    deleteButtonTooltipMessage: strings.cinemaRemoveToday(
                      film.titleFor(language),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CinemaWheelPainter extends CustomPainter {
  const _CinemaWheelPainter(this.titles);

  final List<String> titles;

  static const _colors = [
    Color(0xFFF6C5D2),
    Color(0xFFE7D9F5),
    Color(0xFFF9E5B9),
    Color(0xFFD8EFE2),
    Color(0xFFFFD8C2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.47;
    if (titles.isEmpty) {
      canvas.drawCircle(center, radius, Paint()..color = AppColors.lavender);
      return;
    }
    final slice = math.pi * 2 / titles.length;
    for (var index = 0; index < titles.length; index++) {
      final start = -math.pi / 2 + index * slice;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          start,
          slice,
          false,
        )
        ..close();
      canvas.drawPath(path, Paint()..color = _colors[index % _colors.length]);
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
      final angle = start + slice / 2;
      final label = TextPainter(
        text: TextSpan(
          text: _shorten(titles[index]),
          style: const TextStyle(
            color: Color(0xFF542B3A),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        textAlign: TextAlign.center,
      )..layout(maxWidth: radius * math.min(0.82, slice * 0.8));
      canvas.save();
      canvas.translate(
        center.dx + math.cos(angle) * radius * 0.58,
        center.dy + math.sin(angle) * radius * 0.58,
      );
      canvas.rotate(angle + math.pi / 2);
      label.paint(canvas, Offset(-label.width / 2, -label.height / 2));
      canvas.restore();
    }
    canvas.drawCircle(center, radius * 0.13, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      radius * 0.13,
      Paint()
        ..color = const Color(0xFFE68DA6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  String _shorten(String value) =>
      value.length > 18 ? '${value.substring(0, 16)}…' : value;

  @override
  bool shouldRepaint(covariant _CinemaWheelPainter oldDelegate) =>
      !listEquals(oldDelegate.titles, titles);
}

class _HeartBurstPainter extends CustomPainter {
  const _HeartBurstPainter(this.progress);

  final double progress;

  static const _colors = [
    Color(0xFFE68DA6),
    Color(0xFFB55271),
    Color(0xFFF2B8C8),
    Color(0xFFD982A0),
    Color(0xFFFFC5D8),
    Color(0xFFCA6F8C),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = size.center(Offset.zero);
    final fade = (1 - progress).clamp(0.0, 1.0);
    for (var index = 0; index < _colors.length; index++) {
      final angle = math.pi * 2 * index / _colors.length - math.pi / 2;
      final distance = 25 + progress * 76;
      final heartSize = 8 + (1 - progress) * 5;
      canvas.save();
      canvas.translate(
        center.dx + math.cos(angle) * distance,
        center.dy + math.sin(angle) * distance,
      );
      canvas.rotate(angle + math.pi / 4);
      canvas.scale(heartSize / 16);
      final heart = Path()
        ..moveTo(0, 7)
        ..cubicTo(-9, 1, -7, -7, 0, -3)
        ..cubicTo(7, -7, 9, 1, 0, 7)
        ..close();
      canvas.drawPath(
        heart,
        Paint()..color = _colors[index].withValues(alpha: fade),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _HeartBurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
