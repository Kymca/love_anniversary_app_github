import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/grocery_wallet.dart';
import '../../services/warehouse_work_repository.dart';
import '../../theme/app_theme.dart';
import 'warehouse_game_engine.dart';

class WarehouseWorkScreen extends StatefulWidget {
  const WarehouseWorkScreen({
    super.key,
    this.repository,
    this.wallet,
    this.clock,
    this.embedded = false,
    this.onReturnToStore,
  }) : assert(!embedded || onReturnToStore != null);

  final WarehouseWorkRepository? repository;
  final GroceryWallet? wallet;
  final DateTime Function()? clock;
  final bool embedded;
  final VoidCallback? onReturnToStore;

  @override
  State<WarehouseWorkScreen> createState() => _WarehouseWorkScreenState();
}

class _WarehouseWorkScreenState extends State<WarehouseWorkScreen>
    with SingleTickerProviderStateMixin {
  late final WarehouseWorkRepository _repository =
      widget.repository ?? WarehouseWorkRepository();
  GroceryWallet? _wallet;
  WarehouseWorkState? _workState;
  WarehouseGameEngine? _engine;
  Ticker? _ticker;
  Duration? _lastElapsed;
  bool _loading = true;
  bool _savingProgress = false;
  bool _saveAgain = false;
  bool _finishing = false;
  String? _error;
  late DateTime _now;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _now = widget.clock?.call() ?? DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = widget.clock?.call() ?? DateTime.now());
      }
    });
    _load();
  }

  Future<void> _load() async {
    GroceryWallet? wallet;
    WarehouseWorkState? loadedState;
    try {
      wallet = widget.wallet ?? await GroceryWallet.open();
      var state = await _repository.load();
      loadedState = state;
      if (mounted) {
        setState(() {
          _wallet = wallet;
          _workState = state;
          _loading = false;
        });
      }
      await _repository.recoverPendingReward(state, wallet);
      state = await _repository.load();
      loadedState = state;
      if (!mounted) return;
      setState(() {
        _wallet = wallet;
        _workState = state;
        _loading = false;
      });
      if (state.activeRunId != null) {
        _resumeRun(state);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _wallet = wallet;
        _workState = loadedState;
        _error = AppLocalizations.of(context)!
            .warehouseWorkSaveError(error.toString());
      });
      if (loadedState?.activeRunId != null) {
        _resumeRun(loadedState!);
      }
    }
  }

  void _resumeRun(WarehouseWorkState state) {
    final runId = state.activeRunId;
    if (runId == null) return;
    _engine = WarehouseGameEngine(
      caught: state.caught,
      missed: state.missed,
      seed: runId.hashCode,
    );
    _lastElapsed = null;
    _ticker ??= createTicker(_onTick);
    _ticker!.start();
  }

  Future<void> _startWork() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final state = await _repository.beginWork();
      if (!mounted) return;
      setState(() {
        _workState = state;
        _loading = false;
      });
      _resumeRun(state);
    } on WarehouseCooldownException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _now = widget.clock?.call() ?? DateTime.now();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(context)!
            .warehouseWorkSaveError(error.toString());
      });
    }
  }

  void _onTick(Duration elapsed) {
    final previous = _lastElapsed;
    _lastElapsed = elapsed;
    if (previous == null) return;
    final engine = _engine;
    if (engine == null) return;
    final events = engine.advance(
      (elapsed - previous).inMicroseconds / Duration.microsecondsPerSecond,
    );
    if (mounted) setState(() {});
    if (events.isNotEmpty) _persistProgress();
  }

  Future<void> _persistProgress() async {
    if (_savingProgress) {
      _saveAgain = true;
      return;
    }
    final engine = _engine;
    final state = _workState;
    final wallet = _wallet;
    final runId = state?.activeRunId;
    if (engine == null || wallet == null || runId == null) return;

    _savingProgress = true;
    try {
      do {
        _saveAgain = false;
        if (engine.isComplete) break;
        await _repository.saveProgress(
          runId,
          caught: engine.caught,
          missed: engine.missed,
        );
      } while (_saveAgain && !engine.isComplete);
      if (engine.isComplete) await _finishWork();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = AppLocalizations.of(context)!
              .warehouseWorkSaveError(error.toString());
        });
      }
    } finally {
      _savingProgress = false;
    }
  }

  Future<void> _finishWork() async {
    if (_finishing) return;
    final engine = _engine;
    final state = _workState;
    final wallet = _wallet;
    final runId = state?.activeRunId;
    if (engine == null || wallet == null || runId == null) return;
    _finishing = true;
    try {
      final completed = await _repository.completeWork(
        runId,
        caught: engine.caught,
        missed: engine.missed,
        wallet: wallet,
      );
      if (!mounted) return;
      _ticker?.stop();
      setState(() {
        _engine = null;
        _workState = completed;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = AppLocalizations.of(context)!
              .warehouseWorkSaveError(error.toString());
        });
      }
    } finally {
      _finishing = false;
    }
  }

  void _movePlayer(double delta) {
    final engine = _engine;
    if (engine == null) return;
    setState(() => engine.movePlayerBy(delta));
  }

  void _movePlayerTo(double x) {
    final engine = _engine;
    if (engine == null) return;
    setState(() => engine.movePlayerTo(x));
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(strings.warehouseTitle),
              backgroundColor: Colors.transparent,
              foregroundColor: const Color(0xFF315D58),
            ),
      body: AppGradientBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _workState == null
              ? _buildLoadError(strings)
              : _engine != null
              ? _buildGame(strings)
              : _workState?.hasCompletion == true
              ? _buildResult(strings, _workState!)
              : _buildReady(strings, _workState ?? const WarehouseWorkState()),
        ),
      ),
    );
  }

  Widget _buildLoadError(AppLocalizations strings) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('warehouse-retry-load'),
            onPressed: _load,
            child: Text(strings.warehouseRetrySave),
          ),
        ],
      ),
    ),
  );

  Widget _buildReady(AppLocalizations strings, WarehouseWorkState state) {
    final availableAt = _repository.nextAvailableAt(state);
    final remaining = availableAt == null
        ? Duration.zero
        : availableAt.difference(_now);
    final coolingDown = remaining > Duration.zero;
    final remainingMinutes = (remaining.inSeconds + 59) ~/ 60;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _WarehousePreview(),
              const SizedBox(height: 18),
              Text(
                strings.warehouseSubtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              if (coolingDown)
                Text(
                  strings.warehouseTired,
                  key: const ValueKey('warehouse-tired-duck'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF805C50),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (coolingDown) ...[
                const SizedBox(height: 6),
                Text(
                  strings.warehouseCooldownRemaining(
                    remainingMinutes ~/ 60,
                    remainingMinutes % 60,
                  ),
                  key: const ValueKey('warehouse-cooldown'),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const ValueKey('warehouse-start-work'),
                onPressed: coolingDown ? null : _startWork,
                icon: const Icon(Icons.work_rounded),
                label: Text(strings.warehouseStart),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGame(AppLocalizations strings) {
    final engine = _engine!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.center,
                child: _WarehouseScoreBadge(
                  key: const ValueKey('warehouse-progress'),
                  icon: Icons.inventory_2_rounded,
                  color: const Color(0xFF566D54),
                  label: strings.warehouseProgress(
                    engine.boxesSettled,
                    WarehouseWorkRepository.totalBoxes,
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  _WarehouseScoreBadge(
                    key: const ValueKey('warehouse-caught'),
                    icon: Icons.check_circle_rounded,
                    color: const Color(0xFF447A52),
                    label: strings.warehouseCaught(engine.caught),
                  ),
                  _WarehouseScoreBadge(
                    key: const ValueKey('warehouse-missed'),
                    icon: Icons.cancel_rounded,
                    color: const Color(0xFF9B654B),
                    label: strings.warehouseMissed(engine.missed),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _WarehouseGameScene(engine: engine, onMoveTo: _movePlayerTo),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 4, 28, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Semantics(
                button: true,
                label: strings.warehouseMoveLeft,
                child: IconButton.filledTonal(
                  key: const ValueKey('warehouse-move-left'),
                  tooltip: strings.warehouseMoveLeft,
                  onPressed: () => _movePlayer(-0.12),
                  icon: const Icon(Icons.arrow_left_rounded, size: 32),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    strings.warehouseControlsHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: strings.warehouseMoveRight,
                child: IconButton.filledTonal(
                  key: const ValueKey('warehouse-move-right'),
                  tooltip: strings.warehouseMoveRight,
                  onPressed: () => _movePlayer(0.12),
                  icon: const Icon(Icons.arrow_right_rounded, size: 32),
                ),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                Text(_error!, textAlign: TextAlign.center),
                if (engine.isComplete)
                  TextButton(
                    key: const ValueKey('warehouse-retry-completion'),
                    onPressed: _persistProgress,
                    child: Text(strings.warehouseRetrySave),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildResult(AppLocalizations strings, WarehouseWorkState state) {
    final caught = state.completedCaught!;
    final reward = state.completedReward!;
    final title = caught == WarehouseWorkRepository.totalBoxes
        ? strings.warehouseResultPerfectTitle
        : caught > WarehouseWorkRepository.totalBoxes ~/ 2
        ? strings.warehouseResultPartialTitle
        : strings.warehouseResultFailureTitle;
    final message = caught == WarehouseWorkRepository.totalBoxes
        ? strings.warehouseResultPerfectMessage
        : caught > WarehouseWorkRepository.totalBoxes ~/ 2
        ? strings.warehouseResultPartialMessage
        : strings.warehouseResultFailureMessage;
    final remaining = _repository.nextAvailableAt(state)?.difference(_now);
    final canStartAgain = remaining == null || remaining <= Duration.zero;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _WarehousePreview(),
              const SizedBox(height: 20),
              Text(
                title,
                key: const ValueKey('warehouse-result-title'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF315D58),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              Text(
                strings.warehouseProgress(
                  caught,
                  WarehouseWorkRepository.totalBoxes,
                ),
                key: const ValueKey('warehouse-result-score'),
              ),
              const SizedBox(height: 8),
              Text(
                strings.warehouseReward(reward),
                key: const ValueKey('warehouse-result-reward'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF8A6730),
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                TextButton(
                  key: const ValueKey('warehouse-retry-reward'),
                  onPressed: _retryReward,
                  child: Text(strings.warehouseRetrySave),
                ),
              ],
              const SizedBox(height: 20),
              if (canStartAgain)
                FilledButton(
                  key: const ValueKey('warehouse-next-shift'),
                  onPressed: _startWork,
                  child: Text(strings.warehouseStart),
                )
              else
                Text(
                  strings.warehouseTired,
                  key: const ValueKey('warehouse-tired-duck'),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 8),
              TextButton(
                key: const ValueKey('warehouse-return-home'),
                onPressed: widget.embedded
                    ? widget.onReturnToStore
                    : () => Navigator.of(context).pop(),
                child: Text(
                  widget.embedded
                      ? strings.groceryStoreTab
                      : strings.warehouseReturnHome,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _retryReward() async {
    final state = _workState;
    final wallet = _wallet;
    if (state == null || wallet == null) {
      return;
    }
    try {
      await _repository.recoverPendingReward(state, wallet);
      final updated = await _repository.load();
      if (mounted) {
        setState(() {
          _workState = updated;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = AppLocalizations.of(context)!
              .warehouseWorkSaveError(error.toString());
        });
      }
    }
  }
}

class _WarehouseGameScene extends StatelessWidget {
  const _WarehouseGameScene({required this.engine, required this.onMoveTo});

  final WarehouseGameEngine engine;
  final ValueChanged<double> onMoveTo;

  static const _background = 'assets/images/warehouse/warehouse_background.png';
  static const _palletJack =
      'assets/images/warehouse/warehouse_pallet_jack.png';
  static const _platform =
      'assets/images/warehouse/warehouse_catch_platform.png';
  static const _boxSheet = 'assets/images/warehouse/warehouse_box_variants.png';

  @override
  Widget build(BuildContext context) => Center(
    child: AspectRatio(
      key: const ValueKey('warehouse-stage-aspect'),
      aspectRatio: 4 / 3,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          color: const Color(0xFF342F2A),
          border: Border.all(color: const Color(0xFF4A3A2D), width: 4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x6642382E),
              offset: Offset(4, 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final scale = math.min(size.width / 320, size.height / 240);
            final jackWidth = 96 * scale;
            final jackHeight = 64 * scale;
            final platformWidth = 160 * scale;
            final platformHeight = 32 * scale;
            final playerCenter = engine.playerX * size.width;
            return Semantics(
              key: const ValueKey('warehouse-game-scene'),
              label: AppLocalizations.of(context)!.warehouseSceneSemantics,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) =>
                    onMoveTo(details.localPosition.dx / size.width),
                onHorizontalDragUpdate: (details) =>
                    onMoveTo(details.localPosition.dx / size.width),
                child: ClipRect(
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          _background,
                          key: const ValueKey('warehouse-background-image'),
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.none,
                          errorBuilder: (_, _, _) => const CustomPaint(
                            painter: _WarehouseBackdropPainter(),
                          ),
                        ),
                      ),
                      for (final box in engine.boxes)
                        _buildFallingBox(box, size, scale),
                      Positioned(
                        key: const ValueKey('warehouse-player'),
                        left: (playerCenter - jackWidth / 2)
                            .clamp(0, size.width - jackWidth)
                            .toDouble(),
                        bottom: platformHeight * 0.5,
                        width: jackWidth,
                        height: jackHeight,
                        child: Image.asset(
                          _palletJack,
                          filterQuality: FilterQuality.none,
                          errorBuilder: (_, _, _) => const CustomPaint(
                            painter: _WarehouseSpritePainter(kind: 'jack'),
                          ),
                        ),
                      ),
                      Positioned(
                        left: (playerCenter - platformWidth / 2)
                            .clamp(0, size.width - platformWidth)
                            .toDouble(),
                        bottom: 4,
                        width: platformWidth,
                        height: platformHeight,
                        child: Image.asset(
                          _platform,
                          filterQuality: FilterQuality.none,
                          errorBuilder: (_, _, _) => const CustomPaint(
                            painter: _WarehouseSpritePainter(kind: 'platform'),
                          ),
                        ),
                      ),
                      if (engine.isComplete)
                        const Positioned.fill(
                          child: IgnorePointer(
                            child: ColoredBox(color: Color(0x160D201C)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );

  Widget _buildFallingBox(WarehouseBox box, Size sceneSize, double scale) {
    final perspectiveScale = 0.7 + box.y * 0.42;
    final boxSize = 32 * scale * perspectiveScale;
    return Positioned(
      key: ValueKey('warehouse-box-${box.id}'),
      left: box.x * sceneSize.width - boxSize / 2,
      top: box.y * sceneSize.height - boxSize / 2,
      width: boxSize + 3 * scale,
      height: boxSize + 3 * scale,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 3 * scale,
            top: 3 * scale,
            width: boxSize,
            height: boxSize,
            child: const ColoredBox(color: Color(0x55271B13)),
          ),
          Positioned(
            width: boxSize,
            height: boxSize,
            child: _BoxSprite(
              frame: box.variant,
              sheetAsset: _boxSheet,
              scale: scale * perspectiveScale,
            ),
          ),
        ],
      ),
    );
  }
}

class _BoxSprite extends StatelessWidget {
  const _BoxSprite({
    required this.frame,
    required this.sheetAsset,
    required this.scale,
  });

  final int frame;
  final String sheetAsset;
  final double scale;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Align(
      alignment: Alignment(-1 + 2 * frame / 3, 0),
      widthFactor: 0.25,
      child: Image.asset(
        sheetAsset,
        width: 128 * scale,
        height: 32 * scale,
        key: ValueKey('warehouse-box-sprite-$frame'),
        filterQuality: FilterQuality.none,
        errorBuilder: (_, _, _) =>
            CustomPaint(painter: _WarehouseSpritePainter(kind: 'box$frame')),
      ),
    ),
  );
}

class _WarehouseScoreBadge extends StatelessWidget {
  const _WarehouseScoreBadge({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFFF4E8CE),
      border: Border.all(color: color.withValues(alpha: 0.75), width: 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x332D251E),
          offset: Offset(2, 2),
          blurRadius: 0,
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _WarehousePreview extends StatelessWidget {
  const _WarehousePreview();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 160,
    width: double.infinity,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.asset(
        'assets/images/warehouse/warehouse_background.png',
        fit: BoxFit.cover,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, _, _) =>
            const CustomPaint(painter: _WarehouseBackdropPainter()),
      ),
    ),
  );
}

class _WarehouseBackdropPainter extends CustomPainter {
  const _WarehouseBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 320, size.height / 240);
    final paint = Paint()..isAntiAlias = false;
    paint.color = const Color(0xFF90A78D);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 320, 240), paint);
    paint.color = const Color(0xFF596C5D);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 320, 118), paint);
    paint.color = const Color(0xFF778574);
    for (var x = 0; x < 320; x += 32) {
      canvas.drawRect(Rect.fromLTWH(x.toDouble(), 4, 3, 110), paint);
    }
    paint.color = const Color(0xFF9A8B68);
    canvas.drawRect(const Rect.fromLTWH(18, 30, 70, 7), paint);
    canvas.drawRect(const Rect.fromLTWH(116, 22, 86, 7), paint);
    canvas.drawRect(const Rect.fromLTWH(222, 38, 78, 7), paint);
    paint.color = const Color(0xFFC19B64);
    for (var row = 0; row < 3; row++) {
      for (var column = 0; column < 4; column++) {
        canvas.drawRect(
          Rect.fromLTWH(27 + column * 16.0, 40 + row * 18.0, 13, 15),
          paint,
        );
      }
    }
    paint.color = const Color(0xFFBCB58C);
    canvas.drawRect(const Rect.fromLTWH(0, 118, 320, 5), paint);
    paint.color = const Color(0xFF786D58);
    canvas.drawRect(const Rect.fromLTWH(0, 123, 320, 117), paint);
    paint.color = const Color(0xFF9D8F70);
    canvas.drawRect(const Rect.fromLTWH(0, 124, 320, 3), paint);
    paint.color = const Color(0xFF92866E);
    for (var y = 142; y < 240; y += 24) {
      canvas.drawRect(Rect.fromLTWH(0, y.toDouble(), 320, 1), paint);
    }
    for (var x = 30; x < 320; x += 64) {
      canvas.drawRect(Rect.fromLTWH(x.toDouble(), 128, 1, 112), paint);
    }
    paint.color = const Color(0xFF4F594B);
    for (var x = 0; x < 320; x += 40) {
      canvas.drawRect(Rect.fromLTWH(x.toDouble(), 112, 16, 5), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WarehouseBackdropPainter oldDelegate) => false;
}

class _WarehouseSpritePainter extends CustomPainter {
  const _WarehouseSpritePainter({required this.kind});

  final String kind;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(
      size.width / (kind.startsWith('box') ? 32 : 96),
      size.height / (kind.startsWith('box') ? 32 : 64),
    );
    final paint = Paint()..isAntiAlias = false;
    if (kind.startsWith('box')) {
      paint.color = const Color(0xFFB87C40);
      canvas.drawRect(const Rect.fromLTWH(3, 3, 26, 26), paint);
      paint.color = const Color(0xFF704B31);
      canvas.drawRect(const Rect.fromLTWH(3, 3, 26, 3), paint);
      canvas.drawRect(const Rect.fromLTWH(3, 3, 3, 26), paint);
      paint.color = const Color(0xFFD5A15E);
      canvas.drawRect(const Rect.fromLTWH(15, 5, 3, 22), paint);
      canvas.drawRect(const Rect.fromLTWH(5, 14, 22, 3), paint);
    } else if (kind == 'platform') {
      paint.color = const Color(0xFF7C582E);
      canvas.drawRect(const Rect.fromLTWH(2, 8, 92, 12), paint);
      paint.color = const Color(0xFFD7A443);
      canvas.drawRect(const Rect.fromLTWH(5, 6, 86, 5), paint);
      paint.color = const Color(0xFF423F34);
      canvas.drawRect(const Rect.fromLTWH(8, 20, 7, 5), paint);
      canvas.drawRect(const Rect.fromLTWH(80, 20, 7, 5), paint);
    } else {
      paint.color = const Color(0xFF374339);
      canvas.drawRect(const Rect.fromLTWH(6, 34, 84, 18), paint);
      paint.color = const Color(0xFFB27B39);
      canvas.drawRect(const Rect.fromLTWH(14, 23, 45, 25), paint);
      paint.color = const Color(0xFFE0B873);
      canvas.drawRect(const Rect.fromLTWH(20, 15, 24, 20), paint);
      paint.color = const Color(0xFF3D3027);
      canvas.drawRect(const Rect.fromLTWH(27, 21, 4, 4), paint);
      paint.color = const Color(0xFF26312C);
      canvas.drawRect(const Rect.fromLTWH(18, 47, 13, 11), paint);
      canvas.drawRect(const Rect.fromLTWH(65, 47, 13, 11), paint);
      paint.color = const Color(0xFFB9C1A1);
      canvas.drawRect(const Rect.fromLTWH(16, 55, 66, 4), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WarehouseSpritePainter oldDelegate) =>
      oldDelegate.kind != kind;
}
