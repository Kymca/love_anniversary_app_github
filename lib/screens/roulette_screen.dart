import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/app_sound_service.dart';
import '../services/roulette_repository.dart';
import '../theme/app_theme.dart';

class RouletteScreen extends StatefulWidget {
  const RouletteScreen({
    super.key,
    this.repository,
    this.pairRevision = 0,
    this.isActive = true,
    this.random = math.Random.new,
  });

  final RouletteRepository? repository;
  final int pairRevision;
  final bool isActive;
  final math.Random Function() random;

  @override
  State<RouletteScreen> createState() => _RouletteScreenState();
}

class _RouletteScreenState extends State<RouletteScreen>
    with SingleTickerProviderStateMixin {
  late final RouletteRepository _repository =
      widget.repository ?? SharedPreferencesRouletteRepository();
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..addListener(_onSpinFrame);
  late final math.Random _random = widget.random();
  final RouletteSpinSound _spinSound = RouletteSpinSound();
  late RouletteCategory _category = RouletteCategory.food;
  final _choiceController = TextEditingController();
  List<String> _choices = const [];
  List<String> _sharedChoices = const [];
  Set<String> _excludedKeys = {};
  StreamSubscription<void>? _changesSubscription;
  double _rotation = 0;
  double _spinStart = 0;
  double _spinTarget = 0;
  String? _result;
  bool _isSpinning = false;
  bool _isApplying = false;
  bool _choiceApplied = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _refreshChoices();
      _watchChanges();
    }
  }

  @override
  void didUpdateWidget(covariant RouletteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive && oldWidget.isActive) {
      _changesSubscription?.cancel();
      _changesSubscription = null;
    } else if (widget.isActive &&
        (!oldWidget.isActive ||
            widget.pairRevision != oldWidget.pairRevision)) {
      _refreshChoices();
      _watchChanges();
    }
  }

  void _onSpinFrame() {
    if (!_isSpinning) return;
    final progress = Curves.easeOutCubic.transform(_controller.value);
    _rotation = _spinStart + (_spinTarget - _spinStart) * progress;
    setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onSpinFrame)
      ..dispose();
    _spinSound.cancel();
    _changesSubscription?.cancel();
    _choiceController.dispose();
    super.dispose();
  }

  List<String> _defaults(AppLocalizations strings) => switch (_category) {
    RouletteCategory.food => [
      strings.rouletteFoodOptionCook,
      strings.rouletteFoodOptionOrder,
      strings.rouletteFoodOptionCafe,
      strings.rouletteFoodOptionPicnic,
      strings.rouletteFoodOptionDessert,
    ],
    RouletteCategory.movie => [
      strings.rouletteMovieOptionRomcom,
      strings.rouletteMovieOptionCartoon,
      strings.rouletteMovieOptionFavorite,
      strings.rouletteMovieOptionNew,
      strings.rouletteMovieOptionNight,
    ],
    RouletteCategory.activity => [
      strings.rouletteActivityOptionWalk,
      strings.rouletteActivityOptionBoardGame,
      strings.rouletteActivityOptionPhoto,
      strings.rouletteActivityOptionHomeDate,
      strings.rouletteActivityOptionMusic,
    ],
  };

  String _categoryLabel(AppLocalizations strings, RouletteCategory category) =>
      switch (category) {
        RouletteCategory.food => strings.rouletteFood,
        RouletteCategory.movie => strings.rouletteMovie,
        RouletteCategory.activity => strings.rouletteActivity,
      };

  Future<void> _selectCategory(RouletteCategory category) async {
    if (_isSpinning || category == _category) return;
    setState(() {
      _category = category;
      _result = null;
      _choiceApplied = false;
      _choices = const [];
      _loadFailed = false;
    });
    await _refreshChoices();
    _watchChanges();
  }

  Future<void> _addChoice() async {
    final value = _choiceController.text.trim();
    if (value.isEmpty || _isSpinning) return;
    try {
      await _repository.addChoice(_category, value);
      if (!mounted) return;
      _choiceController.clear();
      setState(() {
        _result = null;
      });
      await _refreshChoices();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.rouletteSavedChoice),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.rouletteError)),
        );
      }
    }
  }

  Future<void> _removeChoice(String choice) async {
    try {
      await _repository.removeChoice(_category, choice);
      if (!mounted) return;
      setState(() {
        _result = null;
      });
      await _refreshChoices();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.rouletteError)),
        );
      }
    }
  }

  Future<void> _setChoiceActive(String choice, bool active) async {
    try {
      if (active) {
        await _repository.addChoice(_category, choice);
      } else {
        await _repository.removeChoice(_category, choice);
      }
      if (mounted) await _refreshChoices();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.rouletteError)),
        );
      }
    }
  }

  void _watchChanges() {
    _changesSubscription?.cancel();
    if (!widget.isActive) return;
    _changesSubscription = _repository
        .watchChanges(_category)
        .listen(
          (_) => _refreshChoices(),
          onError: (Object _) {
            if (mounted) setState(() => _loadFailed = true);
          },
        );
  }

  Future<void> _refreshChoices() async {
    try {
      final values = await Future.wait([
        _repository.loadCustomChoices(_category),
        _repository.loadSharedChoices(_category),
        _repository.loadExcludedChoiceKeys(_category),
      ]);
      if (!mounted) return;
      setState(() {
        final defaults = _defaults(AppLocalizations.of(context)!);
        _excludedKeys = values[2].toSet();
        _choices = [
          for (var index = 0; index < defaults.length; index++)
            if (!_excludedKeys.contains(_defaultChoiceKey(index)))
              defaults[index],
          ...values[0],
        ];
        _sharedChoices = values[1];
        _loadFailed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _choices = const [];
          _sharedChoices = const [];
          _loadFailed = true;
        });
      }
    }
  }

  String _defaultChoiceKey(int index) => 'builtin:${_category.name}:$index';

  String _keyForChoice(String choice) {
    final defaults = _defaults(AppLocalizations.of(context)!);
    final index = defaults.indexOf(choice);
    return index >= 0
        ? _defaultChoiceKey(index)
        : SharedPreferencesRouletteRepository.customChoiceKey(choice);
  }

  Future<void> _applyChoice() async {
    final result = _result;
    if (result == null || _isApplying) return;
    setState(() => _isApplying = true);
    try {
      await _repository.applyChoice(_category, result, _keyForChoice(result));
      if (!mounted) return;
      setState(() {
        _isApplying = false;
        _choiceApplied = true;
      });
      await _refreshChoices();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isApplying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.rouletteError)),
      );
    }
  }

  Future<void> _spin() async {
    if (_isSpinning) return;
    await _refreshChoices();
    if (!mounted || _choices.isEmpty) return;
    final chosenIndex = _random.nextInt(_choices.length);
    final slice = math.pi * 2 / _choices.length;
    final center = -math.pi / 2 + (chosenIndex + 0.5) * slice;
    final delta = (-math.pi / 2 - center - _rotation) % (math.pi * 2);
    final target =
        _rotation + math.pi * 2 * 5 + (delta < 0 ? delta + math.pi * 2 : delta);
    setState(() {
      _result = null;
      _choiceApplied = false;
      _isSpinning = true;
      _spinStart = _rotation;
      _spinTarget = target;
    });
    _spinSound.start();
    try {
      await _controller.forward();
    } finally {
      _spinSound.cancel();
    }
    if (!mounted) return;
    setState(() {
      _rotation = target;
      _isSpinning = false;
      _result = _choices[chosenIndex];
    });
    _controller.reset();
    unawaited(AppSoundService.play(AppSoundEvent.rouletteStopped));
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final defaultChoices = _defaults(strings);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          key: const ValueKey('roulette-scroll-view'),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
          children: [
            Text(
              strings.rouletteTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(strings.rouletteSubtitle),
            const SizedBox(height: 18),
            SegmentedButton<RouletteCategory>(
              segments: [
                for (final category in RouletteCategory.values)
                  ButtonSegment(
                    value: category,
                    label: Text(_categoryLabel(strings, category)),
                  ),
              ],
              selected: {_category},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) _selectCategory(selection.first);
              },
            ),
            const SizedBox(height: 20),
            Center(
              child: SizedBox(
                width: 280,
                height: 280,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Positioned.fill(
                      top: 16,
                      child: Transform.rotate(
                        angle: _rotation,
                        child: CustomPaint(
                          key: const ValueKey('roulette-wheel'),
                          painter: _RouletteWheelPainter(_choices),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      top: 16,
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _HeartBurstPainter(_controller.value),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_drop_down_rounded,
                      key: ValueKey('roulette-pointer'),
                      size: 42,
                      color: AppColors.roseDeep,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loadFailed)
              Text(
                strings.rouletteError,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (_choices.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (_result != null)
              Text(
                '${strings.rouletteResult} $_result',
                key: const ValueKey('roulette-result'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.roseDeep,
                  fontWeight: FontWeight.w800,
                ),
              ),
            if (_result != null) ...[
              const SizedBox(height: 8),
              FilledButton.tonal(
                key: const ValueKey('roulette-do-this'),
                onPressed: _isApplying || _choiceApplied ? null : _applyChoice,
                child: Text(
                  _choiceApplied
                      ? strings.rouletteChoiceApplied
                      : strings.rouletteDoThis,
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('roulette-spin'),
              onPressed: _isSpinning ? null : _spin,
              icon: const Icon(Icons.casino_rounded),
              label: Text(
                _result == null
                    ? strings.rouletteSpin
                    : strings.rouletteSpinAgain,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              strings.rouletteAddChoice,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('roulette-choice-input'),
                    controller: _choiceController,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addChoice(),
                    decoration: InputDecoration(
                      hintText: strings.rouletteChoiceHint,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  key: const ValueKey('roulette-add-choice'),
                  tooltip: strings.rouletteAddChoice,
                  onPressed: _addChoice,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 190,
              child: PageView(
                key: const ValueKey('roulette-lists-pages'),
                children: [
                  _ChoiceListPage(
                    key: const ValueKey('roulette-active-list'),
                    title: strings.rouletteSpin,
                    choices: _choices,
                    removable: _choices.skip(defaultChoices.length).toSet(),
                    onRemove: _removeChoice,
                    emptyMessage: strings.rouletteEmpty,
                  ),
                  _ChoiceListPage(
                    key: const ValueKey('roulette-shared-list'),
                    title: strings.rouletteAddChoice,
                    choices: _sharedChoices,
                    removable: const {},
                    activeChoices: _choices.toSet(),
                    onToggle: (choice, active) =>
                        _setChoiceActive(choice, active),
                    emptyMessage: strings.rouletteEmpty,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                strings.rouletteListSwipeHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 26),
          ],
        ),
      ),
    );
  }
}

class _ChoiceListPage extends StatelessWidget {
  const _ChoiceListPage({
    super.key,
    required this.title,
    required this.choices,
    required this.removable,
    required this.emptyMessage,
    this.activeChoices = const {},
    this.onRemove,
    this.onToggle,
  });

  final String title;
  final List<String> choices;
  final Set<String> removable;
  final Set<String> activeChoices;
  final String emptyMessage;
  final ValueChanged<String>? onRemove;
  final void Function(String choice, bool active)? onToggle;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white.withValues(alpha: 0.62),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        Expanded(
          child: choices.isEmpty
              ? Center(child: Text(emptyMessage))
              : ListView.builder(
                  key: ValueKey('choice-list-$title'),
                  itemCount: choices.length,
                  itemBuilder: (context, index) {
                    final choice = choices[index];
                    final isActive = activeChoices.contains(choice);
                    return ListTile(
                      dense: true,
                      title: Text(choice),
                      trailing: onToggle != null
                          ? IconButton(
                              tooltip: MaterialLocalizations.of(context)
                                  .deleteButtonTooltip,
                              onPressed: () => onToggle!(choice, !isActive),
                              icon: Icon(
                                isActive
                                    ? Icons.check_circle_rounded
                                    : Icons.add_circle_outline_rounded,
                              ),
                            )
                          : removable.contains(choice)
                          ? IconButton(
                              tooltip: AppLocalizations.of(context)!
                                  .rouletteRemoveChoice(choice),
                              onPressed: () => onRemove?.call(choice),
                              icon: const Icon(Icons.remove_circle_outline),
                            )
                          : null,
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

class _RouletteWheelPainter extends CustomPainter {
  const _RouletteWheelPainter(this.choices);

  final List<String> choices;

  static const _colors = [
    Color(0xFFFFD6E4),
    Color(0xFFFFE6C7),
    Color(0xFFD8F1E7),
    Color(0xFFE7DFFC),
    Color(0xFFFFEBCF),
    Color(0xFFD8E9FC),
    Color(0xFFFFDDE0),
    Color(0xFFE0F0D8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    if (choices.isEmpty) {
      canvas.drawCircle(center, radius, Paint()..color = AppColors.lavender);
      return;
    }

    final sweep = math.pi * 2 / choices.length;
    for (var index = 0; index < choices.length; index++) {
      final start = -math.pi / 2 + index * sweep;
      final paint = Paint()..color = _colors[index % _colors.length];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 2),
        start,
        sweep,
        true,
        paint,
      );
      final labelAngle = start + sweep / 2;
      final labelRadius = radius * 0.62;
      final labelCenter =
          center +
          Offset(math.cos(labelAngle), math.sin(labelAngle)) * labelRadius;
      final painter = TextPainter(
        text: TextSpan(
          text: _shorten(choices[index]),
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        textAlign: TextAlign.center,
      )..layout(maxWidth: math.max(30.0, radius * sweep * 1.1));
      canvas.save();
      canvas.translate(labelCenter.dx, labelCenter.dy);
      canvas.rotate(labelAngle + math.pi / 2);
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
      canvas.drawCircle(
        center,
        radius - 2,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    canvas.drawCircle(center, radius * 0.13, Paint()..color = AppColors.rose);
    canvas.drawCircle(
      center,
      radius * 0.13,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  String _shorten(String value) =>
      value.length > 22 ? '${value.substring(0, 20)}…' : value;

  @override
  bool shouldRepaint(covariant _RouletteWheelPainter oldDelegate) =>
      !listEquals(choices, oldDelegate.choices);
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
