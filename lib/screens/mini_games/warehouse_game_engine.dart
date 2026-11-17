import 'dart:math' as math;

class WarehouseBox {
  const WarehouseBox({
    required this.id,
    required this.x,
    required this.y,
    required this.variant,
  });

  final int id;
  final double x;
  final double y;
  final int variant;

  WarehouseBox moveTo(double nextY) =>
      WarehouseBox(id: id, x: x, y: nextY, variant: variant);
}

class WarehouseGameEvent {
  const WarehouseGameEvent({required this.caught});

  final bool caught;
}

class WarehouseGameEngine {
  static const boxVariantCount = 5;

  WarehouseGameEngine({
    required int caught,
    required int missed,
    int? seed,
    this.dropSpeed = 0.30,
    this.spawnInterval = 1.65,
    this.catchY = 0.92,
    this.catchHalfWidth = 0.22,
  }) : _random = math.Random(seed ?? DateTime.now().microsecondsSinceEpoch),
       _caught = caught,
       _missed = missed,
       _nextBoxId = caught + missed {
    if (caught < 0 || missed < 0 || caught + missed > 15) {
      throw ArgumentError('Invalid warehouse game score');
    }
    _spawnBox();
  }

  final math.Random _random;
  final double dropSpeed;
  final double spawnInterval;
  final double catchY;
  final double catchHalfWidth;
  final List<WarehouseBox> _boxes = [];
  int _caught;
  int _missed;
  int _nextBoxId;
  double _spawnElapsed = 0;
  double playerX = 0.5;

  int get caught => _caught;
  int get missed => _missed;
  int get boxesSettled => _caught + _missed;
  List<WarehouseBox> get boxes => List.unmodifiable(_boxes);
  bool get isComplete => boxesSettled == 15 && _boxes.isEmpty;

  void movePlayerTo(double value) =>
      playerX = value.clamp(0.08, 0.92).toDouble();

  void movePlayerBy(double delta) => movePlayerTo(playerX + delta);

  List<WarehouseGameEvent> advance(double elapsedSeconds) {
    if (isComplete || elapsedSeconds <= 0) return const [];
    var remaining = elapsedSeconds.clamp(0.0, 0.1).toDouble();
    final events = <WarehouseGameEvent>[];
    while (remaining > 0) {
      final step = math.min(remaining, 1 / 60).toDouble();
      _spawnElapsed += step;
      if (_nextBoxId < 15 && _spawnElapsed >= spawnInterval) {
        _spawnElapsed -= spawnInterval;
        _spawnBox();
      }

      for (var index = _boxes.length - 1; index >= 0; index--) {
        final box = _boxes[index];
        final nextY = box.y + dropSpeed * step;
        if (nextY >= catchY) {
          final caught = (box.x - playerX).abs() <= catchHalfWidth;
          if (caught) {
            _caught++;
          } else {
            _missed++;
          }
          _boxes.removeAt(index);
          events.add(WarehouseGameEvent(caught: caught));
        } else {
          _boxes[index] = box.moveTo(nextY);
        }
      }
      remaining -= step;
    }
    return events;
  }

  void _spawnBox() {
    if (_nextBoxId >= 15) return;
    final x = 0.12 + _random.nextDouble() * 0.76;
    _boxes.add(
      WarehouseBox(
        id: _nextBoxId,
        x: x,
        y: 0.02,
        variant: _random.nextInt(boxVariantCount),
      ),
    );
    _nextBoxId++;
  }
}
