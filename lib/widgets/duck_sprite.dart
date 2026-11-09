import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'duck_painter.dart';
import 'duck_mood.dart';

const int duckFrontFrameCount = 6;
const int duckRearFrameCount = 4;
const int duckSpriteFrameSize = 64;
const int duckAnimationFramesPerSecond = 30;
const int _microsecondsPerSecond = Duration.microsecondsPerSecond;
const Duration duckAnimationFrameInterval = Duration(microseconds: 33333);
const Duration duckIdleAnimationDuration = Duration(milliseconds: 1800);
const Duration duckJumpAnimationDuration = Duration(microseconds: 533333);
const Duration duckPartnerTransitionDuration = Duration(microseconds: 466666);
const Duration duckJoyHalfDuration = Duration(microseconds: 866666);
const Duration duckStoreJoyDuration = Duration(microseconds: 666666);
const Duration duckStoreWalkDuration = Duration(microseconds: 766666);
const Duration duckStoreGaitDuration = Duration(microseconds: 1266666);
const Duration duckBlinkHoldDuration = Duration(microseconds: 166666);

int duckAnimationFrameIndex(Duration elapsed) =>
    (math.max(0, elapsed.inMicroseconds) * duckAnimationFramesPerSecond) ~/
    _microsecondsPerSecond;

Duration duckAnimationElapsedAtFrame(int frameIndex) => Duration(
  microseconds:
      math.max(0, frameIndex) *
      _microsecondsPerSecond ~/
      duckAnimationFramesPerSecond,
);

int duckAnimationFrameCount(Duration duration) =>
    (duration.inMicroseconds * duckAnimationFramesPerSecond +
        _microsecondsPerSecond -
        1) ~/
    _microsecondsPerSecond;

double duckAnimationProgressAtFrame(
  int frameIndex,
  Duration duration, {
  bool loop = false,
}) {
  if (duration <= Duration.zero) return 1;
  final elapsed = duckAnimationElapsedAtFrame(frameIndex).inMicroseconds;
  final progress = elapsed / duration.inMicroseconds;
  return loop ? progress % 1 : progress.clamp(0, 1);
}

class DuckFrameTicker {
  DuckFrameTicker({required this.vsync, required this.onFrame});

  final ValueChanged<int> onFrame;
  final TickerProvider vsync;
  late final Ticker _ticker = vsync.createTicker(_tick);
  int frameIndex = 0;

  void _tick(Duration elapsed) {
    final nextFrame = duckAnimationFrameIndex(elapsed);
    if (nextFrame == frameIndex) return;
    frameIndex = nextFrame;
    onFrame(frameIndex);
  }

  void start() {
    frameIndex = 0;
    _ticker
      ..stop()
      ..start();
  }

  void stop() => _ticker.stop();

  void dispose() => _ticker.dispose();
}

class DuckBlinkTicker {
  DuckBlinkTicker({
    required TickerProvider vsync,
    required this.onBlink,
    math.Random? random,
  }) : _random = random ?? math.Random() {
    _clock = DuckFrameTicker(vsync: vsync, onFrame: _tick);
  }

  final ValueChanged<bool> onBlink;
  final math.Random _random;
  late final DuckFrameTicker _clock;
  int _nextBlinkFrame = 0;
  int? _blinkEndFrame;

  void _scheduleNextBlink(int frame) {
    final delay = Duration(milliseconds: 1800 + _random.nextInt(3600));
    _nextBlinkFrame = frame + duckAnimationFrameCount(delay);
  }

  void _tick(int frame) {
    final blinkEndFrame = _blinkEndFrame;
    if (blinkEndFrame != null) {
      if (frame < blinkEndFrame) return;
      _blinkEndFrame = null;
      onBlink(false);
      _scheduleNextBlink(frame);
      return;
    }

    if (frame < _nextBlinkFrame) return;
    _blinkEndFrame = frame + duckAnimationFrameCount(duckBlinkHoldDuration);
    onBlink(true);
  }

  void start() {
    _blinkEndFrame = null;
    _scheduleNextBlink(0);
    _clock.start();
  }

  void stop() => _clock.stop();

  void dispose() => _clock.dispose();
}

double duckJoyProgressAtFrame(int frameIndex) {
  final halfFrames = duckAnimationFrameCount(duckJoyHalfDuration);
  final totalFrames = halfFrames * 2;
  if (frameIndex >= totalFrames) return 0;
  if (frameIndex < halfFrames) {
    return Curves.elasticOut.transform(
      duckAnimationProgressAtFrame(frameIndex, duckJoyHalfDuration),
    );
  }
  return Curves.elasticOut.transform(
    1 -
        duckAnimationProgressAtFrame(
          frameIndex - halfFrames,
          duckJoyHalfDuration,
        ),
  );
}

class DuckJoyReaction extends StatefulWidget {
  const DuckJoyReaction({
    super.key,
    required this.trigger,
    required this.builder,
  });

  final int trigger;
  final Widget Function(BuildContext context, double joy) builder;

  @override
  State<DuckJoyReaction> createState() => _DuckJoyReactionState();
}

class _DuckJoyReactionState extends State<DuckJoyReaction>
    with SingleTickerProviderStateMixin {
  late final DuckFrameTicker _clock = DuckFrameTicker(
    vsync: this,
    onFrame: (frame) {
      if (!mounted) return;
      if (frame >= duckAnimationFrameCount(duckJoyHalfDuration) * 2) {
        _clock.stop();
        setState(() => _active = false);
      } else {
        setState(() {});
      }
    },
  );
  bool _active = false;

  @override
  void didUpdateWidget(covariant DuckJoyReaction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger == widget.trigger) return;
    _active = true;
    _clock.start();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    _active ? duckJoyProgressAtFrame(_clock.frameIndex) : 0,
  );
}

int duckSpriteFrameForProgress(
  double progress, {
  DuckView view = DuckView.front,
}) {
  final frameCount = view == DuckView.front
      ? duckFrontFrameCount
      : duckRearFrameCount;
  final normalized = progress.isFinite ? progress % 1 : 0;
  return (normalized * frameCount).floor().clamp(0, frameCount - 1);
}

class DuckPartnerTransition extends StatefulWidget {
  const DuckPartnerTransition({
    super.key,
    required this.side,
    required this.child,
  });

  final DuckPartnerSide side;
  final Widget child;

  @override
  State<DuckPartnerTransition> createState() => _DuckPartnerTransitionState();
}

class _DuckPartnerTransitionState extends State<DuckPartnerTransition>
    with SingleTickerProviderStateMixin {
  late final DuckFrameTicker _clock = DuckFrameTicker(
    vsync: this,
    onFrame: (_) {
      if (_outgoingSide == null || !mounted) return;
      if (_transitionProgress >= 1) {
        _clock.stop();
        setState(() => _outgoingSide = null);
      } else {
        setState(() {});
      }
    },
  );
  DuckPartnerSide? _outgoingSide;
  Widget? _outgoingChild;
  int _transitionStartFrame = 0;

  int get _transitionElapsedFrames => _clock.frameIndex - _transitionStartFrame;

  double get _transitionProgress => duckAnimationProgressAtFrame(
    _transitionElapsedFrames,
    duckPartnerTransitionDuration,
  );

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant DuckPartnerTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.side == widget.side) return;
    _outgoingSide = oldWidget.side;
    _outgoingChild = oldWidget.child;
    _clock.start();
    _transitionStartFrame = 0;
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outgoingSide = _outgoingSide;
    final outgoingChild = _outgoingChild;
    if (outgoingSide == null || outgoingChild == null) {
      return KeyedSubtree(key: ValueKey(widget.side), child: widget.child);
    }

    final progress = Curves.easeInOut.transform(_transitionProgress);
    final incomingDirection = duckTransitionHorizontalDirection(widget.side);
    final outgoingDirection = duckTransitionHorizontalDirection(outgoingSide);
    return Stack(
      alignment: Alignment.center,
      children: [
        IgnorePointer(
          child: Opacity(
            opacity: 1 - progress,
            child: Transform.translate(
              offset: Offset(outgoingDirection * 240 * progress, 0),
              child: KeyedSubtree(
                key: ValueKey(outgoingSide),
                child: outgoingChild,
              ),
            ),
          ),
        ),
        Opacity(
          opacity: progress,
          child: Transform.translate(
            key: const ValueKey('duck-transition-transform'),
            offset: Offset(incomingDirection * 240 * (1 - progress), 0),
            child: KeyedSubtree(
              key: ValueKey(widget.side),
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }
}

class DuckSpriteWidget extends StatefulWidget {
  const DuckSpriteWidget({
    super.key,
    required this.size,
    this.view = DuckView.front,
    this.appearance = const DuckAppearance(),
    this.frameProgress,
    this.blink = false,
    this.emotion = DuckEmotion.neutral,
  });

  final Size size;
  final DuckView view;
  final DuckAppearance appearance;
  final double? frameProgress;
  final bool blink;
  final DuckEmotion emotion;

  @override
  State<DuckSpriteWidget> createState() => _DuckSpriteWidgetState();
}

class _DuckSpriteWidgetState extends State<DuckSpriteWidget>
    with SingleTickerProviderStateMixin {
  static final Map<String, Future<ui.Image>> _imageLoads = {};
  static final Map<String, ui.Image> _loadedImages = {};

  late final DuckFrameTicker _clock = DuckFrameTicker(
    vsync: this,
    onFrame: (_) {
      if (mounted) setState(() {});
    },
  );
  ui.Image? _image;
  Object? _imageError;
  StackTrace? _imageStackTrace;

  String get _outfit {
    if (widget.appearance.equippedItems.contains('heart_pajamas')) {
      return 'heart_pajamas';
    }
    if (widget.appearance.equippedItems.contains('leather_jacket')) {
      return 'jacket';
    }
    return 'base';
  }

  static String _imageKey(DuckView view, String outfit) =>
      '${view == DuckView.front ? 'front' : 'rear'}'
      '${outfit == 'base' ? '' : '_$outfit'}';

  static Future<ui.Image> _loadSheet(DuckView view, String outfit) async {
    final path = 'assets/images/duck_${_imageKey(view, outfit)}_sheet.png';
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  @override
  void initState() {
    super.initState();
    if (widget.frameProgress == null) _clock.start();
    _loadImage(widget.view, _outfit);
  }

  @override
  void didUpdateWidget(covariant DuckSpriteWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldOutfit =
        oldWidget.appearance.equippedItems.contains('heart_pajamas')
        ? 'heart_pajamas'
        : oldWidget.appearance.equippedItems.contains('leather_jacket')
        ? 'jacket'
        : 'base';
    if (oldWidget.view != widget.view || oldOutfit != _outfit) {
      _image = _loadedImages[_imageKey(widget.view, _outfit)];
      _imageError = null;
      _imageStackTrace = null;
      _loadImage(widget.view, _outfit);
    }
    if (oldWidget.frameProgress == null && widget.frameProgress != null) {
      _clock.stop();
    } else if (oldWidget.frameProgress != null &&
        widget.frameProgress == null) {
      _clock.start();
    }
  }

  void _loadImage(DuckView view, String outfit) {
    final imageKey = _imageKey(view, outfit);
    final cachedImage = _loadedImages[imageKey];
    if (cachedImage != null) {
      _image = cachedImage;
      return;
    }
    final load = _imageLoads.putIfAbsent(
      imageKey,
      () => _loadSheet(view, outfit),
    );
    load.then(
      (image) {
        _loadedImages[imageKey] = image;
        if (!mounted || widget.view != view || _outfit != outfit) {
          return;
        }
        setState(() => _image = image);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted || widget.view != view || _outfit != outfit) {
          return;
        }
        setState(() {
          _imageError = error;
          _imageStackTrace = stackTrace;
        });
      },
    );
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_imageError != null) {
      Error.throwWithStackTrace(_imageError!, _imageStackTrace!);
    }
    final progress =
        widget.frameProgress ??
        duckAnimationProgressAtFrame(
          _clock.frameIndex,
          duckIdleAnimationDuration,
          loop: true,
        );
    final frame = widget.blink && widget.view == DuckView.front
        ? 3
        : duckSpriteFrameForProgress(progress, view: widget.view);
    final phase = progress * math.pi * 2;
    final sway = math.sin(phase);
    final offset = switch (widget.emotion) {
      DuckEmotion.neutral => Offset.zero,
      DuckEmotion.joyful => Offset(0, sway * 2.2),
      DuckEmotion.calm => Offset(0, sway * 0.8),
      DuckEmotion.thoughtful => Offset(sway * 0.8, 0),
      DuckEmotion.tired => Offset(0, 1 + sway * 0.4),
      DuckEmotion.blue => Offset(sway * 1.4, 0),
      DuckEmotion.angry => Offset(sway * 1.2, 0),
    };
    final tilt = switch (widget.emotion) {
      DuckEmotion.thoughtful => sway * 0.018,
      DuckEmotion.blue => sway * 0.012,
      DuckEmotion.angry => sway * 0.008,
      _ => 0.0,
    };
    return KeyedSubtree(
      key: const ValueKey('pixel-duck-sprite'),
      child: Transform.translate(
        key: const ValueKey('duck-mood-motion'),
        offset: offset,
        child: Transform.rotate(
          angle: tilt,
          alignment: Alignment.bottomCenter,
          child: CustomPaint(
            key: const ValueKey('pixel-duck-animation'),
            size: widget.size,
            painter: DuckSpriteSheetPainter(
              image: _image,
              view: widget.view,
              frame: frame,
              appearance: widget.appearance,
              jacket: _outfit == 'jacket',
              heartPajamas: _outfit == 'heart_pajamas',
              emotion: widget.emotion,
            ),
          ),
        ),
      ),
    );
  }
}

class DuckSpriteSheetPainter extends CustomPainter {
  const DuckSpriteSheetPainter({
    required this.image,
    required this.view,
    required this.frame,
    this.appearance = const DuckAppearance(),
    this.jacket = false,
    this.heartPajamas = false,
    this.emotion = DuckEmotion.neutral,
  });

  final ui.Image? image;
  final DuckView view;
  final int frame;
  final DuckAppearance appearance;
  final bool jacket;
  final bool heartPajamas;
  final DuckEmotion emotion;

  @override
  void paint(Canvas canvas, Size size) {
    final image = this.image;
    if (image == null) return;
    final source = Rect.fromLTWH(
      (frame * duckSpriteFrameSize).toDouble(),
      0,
      duckSpriteFrameSize.toDouble(),
      duckSpriteFrameSize.toDouble(),
    );
    final scale = math.min(
      size.width / duckSpriteFrameSize,
      size.height / duckSpriteFrameSize,
    );
    final destination = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: duckSpriteFrameSize * scale,
      height: duckSpriteFrameSize * scale,
    );
    canvas.drawImageRect(
      image,
      source,
      destination,
      Paint()..filterQuality = FilterQuality.none,
    );
    _drawPixelAccessories(canvas, destination);
    if (view == DuckView.front && emotion != DuckEmotion.neutral) {
      _drawEmotion(canvas, destination, frame);
    }
  }

  void _drawPixelAccessories(Canvas canvas, Rect destination) {
    final scale = destination.width / duckSpriteFrameSize;
    final outline = Paint()
      ..color = const Color(0xff382f2c)
      ..isAntiAlias = false;
    final accessory = Paint()
      ..color = const Color(0xffb65a76)
      ..isAntiAlias = false;
    final accessoryLight = Paint()
      ..color = const Color(0xffe98ca1)
      ..isAntiAlias = false;
    final white = Paint()
      ..color = const Color(0xfffffcf1)
      ..isAntiAlias = false;
    void pixels(Paint paint, int x, int y, int width, int height) {
      canvas.drawRect(
        Rect.fromLTWH(
          destination.left + x * scale,
          destination.top + y * scale,
          width * scale,
          height * scale,
        ),
        paint,
      );
    }

    switch (appearance.hat) {
      case DuckHat.none:
        break;
      case DuckHat.partyHat:
        for (var row = 0; row < 7; row++) {
          pixels(outline, 31 - row, 12 - row, row * 2 + 2, 1);
          pixels(accessory, 31 - row, 13 - row, row * 2 + 2, 1);
        }
        pixels(white, 30, 5, 3, 2);
      case DuckHat.crown:
        pixels(outline, 24, 13, 16, 5);
        pixels(accessory, 25, 14, 14, 3);
        pixels(outline, 25, 9, 3, 5);
        pixels(outline, 30, 7, 3, 7);
        pixels(outline, 36, 9, 3, 5);
        pixels(accessoryLight, 26, 10, 1, 2);
        pixels(accessoryLight, 31, 8, 1, 3);
        pixels(accessoryLight, 37, 10, 1, 2);
      case DuckHat.glasses:
        pixels(outline, 19, 19, 11, 8);
        pixels(outline, 34, 19, 11, 8);
        pixels(accessoryLight, 20, 20, 9, 6);
        pixels(accessoryLight, 35, 20, 9, 6);
        pixels(outline, 30, 21, 4, 2);
    }

    if (appearance.equippedItems.contains('bow')) {
      pixels(outline, 26, 35, 6, 5);
      pixels(outline, 32, 35, 6, 5);
      pixels(accessory, 27, 36, 4, 3);
      pixels(accessory, 33, 36, 4, 3);
      pixels(accessoryLight, 28, 36, 2, 1);
      pixels(accessoryLight, 34, 36, 2, 1);
      pixels(outline, 30, 36, 4, 3);
      pixels(accessory, 31, 37, 2, 1);
    }
  }

  void _drawEmotion(Canvas canvas, Rect destination, int frame) {
    final scale = destination.width / duckSpriteFrameSize;
    final bob = const [0, -1, 0, 0, 1, 0][frame];
    final patch = Paint()
      ..color = const Color(0xfffffcf1)
      ..isAntiAlias = false;
    final ink = Paint()
      ..color = const Color(0xff392f2c)
      ..isAntiAlias = false;
    void pixels(Paint paint, int x, int y, int width, int height) {
      canvas.drawRect(
        Rect.fromLTWH(
          destination.left + x * scale,
          destination.top + (y + bob) * scale,
          width * scale,
          height * scale,
        ),
        paint,
      );
    }

    for (final eyeX in [22, 36]) {
      pixels(patch, eyeX, 18, 7, 7);
    }
    switch (emotion) {
      case DuckEmotion.neutral:
        return;
      case DuckEmotion.joyful:
      case DuckEmotion.calm:
        for (final eyeX in [23, 37]) {
          pixels(ink, eyeX, 21, 5, 1);
        }
      case DuckEmotion.thoughtful:
        pixels(ink, 24, 20, 3, 3);
        pixels(ink, 38, 21, 2, 2);
        pixels(ink, 37, 18, 4, 1);
      case DuckEmotion.tired:
        pixels(ink, 23, 21, 5, 2);
        pixels(ink, 37, 21, 5, 2);
        pixels(ink, 23, 23, 5, 1);
        pixels(ink, 37, 23, 5, 1);
      case DuckEmotion.blue:
        pixels(ink, 24, 20, 3, 4);
        pixels(ink, 38, 20, 3, 4);
        pixels(ink, 37, 18, 4, 1);
        pixels(Paint()..color = const Color(0xff91cde0), 40, 25, 2, 3);
      case DuckEmotion.angry:
        pixels(ink, 22, 18, 2, 1);
        pixels(ink, 23, 19, 3, 1);
        pixels(ink, 25, 20, 3, 1);
        pixels(ink, 42, 18, 2, 1);
        pixels(ink, 40, 19, 3, 1);
        pixels(ink, 37, 20, 3, 1);
        pixels(ink, 24, 22, 3, 2);
        pixels(ink, 38, 22, 3, 2);
        final huff = Paint()
          ..color = const Color(0xffff9da7)
          ..isAntiAlias = false;
        pixels(huff, 46, 19, 2, 2);
        pixels(huff, 48, 17, 1, 1);
    }
  }

  @override
  bool shouldRepaint(covariant DuckSpriteSheetPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.view != view ||
      oldDelegate.frame != frame ||
      oldDelegate.jacket != jacket ||
      oldDelegate.heartPajamas != heartPajamas ||
      oldDelegate.appearance.bodyColor != appearance.bodyColor ||
      oldDelegate.appearance.hat != appearance.hat ||
      !listEquals(
        oldDelegate.appearance.equippedItems,
        appearance.equippedItems,
      ) ||
      oldDelegate.emotion != emotion;
}
