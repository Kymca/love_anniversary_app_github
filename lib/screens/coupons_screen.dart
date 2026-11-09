import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../models/coupon.dart';
import '../services/coupon_repository.dart';
import '../services/telegram_coupon_notifier.dart';
import '../theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';

typedef CouponActivatedCallback = FutureOr<void> Function(Coupon coupon);

class CouponsScreen extends StatefulWidget {
  const CouponsScreen({
    super.key,
    this.repository,
    this.repositoryFactory,
    this.notifier,
    this.onActivated,
  });

  final CouponRepository? repository;
  final Future<CouponRepository> Function()? repositoryFactory;
  final CouponActivationNotifier? notifier;
  final CouponActivatedCallback? onActivated;

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen>
    with SingleTickerProviderStateMixin {
  late final ConfettiController _confettiController = ConfettiController(
    duration: const Duration(seconds: 2),
  );
  late final CouponRepository _repository =
      widget.repository ?? InMemoryCouponRepository(defaultCoupons);
  late Future<CouponRepository> _repositoryFuture;
  late Future<List<Coupon>> _couponsFuture;
  List<Coupon> _coupons = const [];
  final Set<String> _activatingIds = {};
  late DateTime _observedMonth;
  Timer? _calendarTimer;

  @override
  void initState() {
    super.initState();
    _observedMonth = DateTime.now();
    _repositoryFuture = widget.repositoryFactory == null
        ? Future.value(_repository)
        : widget.repositoryFactory!();
    _couponsFuture = _loadCoupons();
    _calendarTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkCalendarMonth(),
    );
  }

  Future<List<Coupon>> _loadCoupons() async {
    final coupons = await (await _repositoryFuture).load();
    _coupons = coupons;
    return coupons;
  }

  void _retryLoad() {
    setState(() {
      _coupons = const [];
      if (widget.repositoryFactory != null) {
        _repositoryFuture = widget.repositoryFactory!();
      }
      _couponsFuture = _loadCoupons();
    });
  }

  Future<void> _checkCalendarMonth() async {
    final strings = AppLocalizations.of(context)!;
    final now = DateTime.now();
    if (now.year == _observedMonth.year && now.month == _observedMonth.month) {
      return;
    }
    _observedMonth = now;
    try {
      final coupons = await (await _repositoryFuture).load(now: now);
      if (mounted) setState(() => _coupons = coupons);
    } catch (_) {
      if (mounted) _showMessage(strings.couponLoadError);
    }
  }

  Future<void> _activate(Coupon coupon) async {
    if (_activatingIds.contains(coupon.id) ||
        !coupon.isEligibleAt(DateTime.now())) {
      return;
    }
    final strings = AppLocalizations.of(context)!;
    setState(() => _activatingIds.add(coupon.id));
    final activatedAt = DateTime.now();
    try {
      final repository = await _repositoryFuture;
      final activated = await repository.activate(coupon.id, at: activatedAt);
      if (!activated) return;

      final updated = coupon.copyWith(
        isActivated: true,
        lastActivatedAt: activatedAt,
      );
      if (mounted) {
        setState(() {
          _coupons = [
            for (final item in _coupons)
              if (item.id == updated.id) updated else item,
          ];
        });
        _confettiController.play();
      }

      var notificationFailed = false;
      try {
        await widget.onActivated?.call(updated);
      } catch (_) {
        notificationFailed = true;
      }
      try {
        await widget.notifier?.notifyActivated(updated);
      } catch (_) {
        notificationFailed = true;
      }
      if (notificationFailed) _showMessage(strings.couponNotificationWarning);
    } catch (_) {
      if (mounted) _showMessage(strings.couponActivationError);
    } finally {
      if (mounted) setState(() => _activatingIds.remove(coupon.id));
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _calendarTimer?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.couponTitle,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        strings.couponSubtitle,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (widget.notifier == null) ...[
                        const SizedBox(height: 8),
                        Text(
                          strings.couponNotificationNotConfigured,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<Coupon>>(
                    future: _couponsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _MessageState(
                          icon: Icons.error_outline_rounded,
                          title: strings.couponLoadError,
                          actionLabel: strings.couponRetry,
                          onAction: _retryLoad,
                        );
                      }
                      if (!snapshot.hasData) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 14),
                              Text(strings.couponLoading),
                            ],
                          ),
                        );
                      }
                      if (snapshot.data!.isEmpty) {
                        return _MessageState(
                          icon: Icons.card_giftcard_rounded,
                          title: strings.couponEmptyTitle,
                          description: strings.couponEmptyDescription,
                        );
                      }
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                        itemCount: _coupons.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              mainAxisExtent: 292,
                            ),
                        itemBuilder: (context, index) {
                          final coupon = _coupons[index];
                          return _CouponCard(
                            key: ValueKey(coupon.id),
                            coupon: coupon,
                            isBusy: _activatingIds.contains(coupon.id),
                            onActivate: () => _activate(coupon),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  emissionFrequency: 0.08,
                  numberOfParticles: 18,
                  maxBlastForce: 18,
                  minBlastForce: 8,
                  gravity: 0.25,
                  colors: const [
                    AppColors.rose,
                    AppColors.peach,
                    AppColors.lavender,
                    AppColors.teal,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppColors.rose),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center),
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(description!, textAlign: TextAlign.center),
            ],
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 14),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({
    super.key,
    required this.coupon,
    required this.isBusy,
    required this.onActivate,
  });

  final Coupon coupon;
  final bool isBusy;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final eligible = coupon.isEligibleAt(DateTime.now());
    return Container(
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1C8F536D),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(couponIcon(coupon.icon), color: AppColors.rose, size: 28),
          const SizedBox(height: 7),
          Text(
            coupon.type == CouponType.daily
                ? strings.dailyCouponTitle
                : coupon.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontSize: 15, height: 1.15),
          ),
          const SizedBox(height: 5),
          Expanded(
            child: Text(
              coupon.type == CouponType.daily
                  ? strings.dailyCouponDescription
                  : coupon.description,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.mutedInk, height: 1.25),
            ),
          ),
          if (eligible) ...[
            CouponScratchReveal(
              key: ValueKey('scratch-${coupon.id}'),
              onThresholdReached: onActivate,
              onTapFallback: onActivate,
              scratchHint: strings.couponScratchHint,
              enabled: !isBusy,
            ),
            const SizedBox(height: 7),
            FilledButton(
              onPressed: isBusy ? null : onActivate,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                textStyle: const TextStyle(fontSize: 13),
              ),
              child: isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(strings.couponActivate),
            ),
          ] else ...[
            Text(
              coupon.type == CouponType.daily && !coupon.isActivated
                  ? strings.dailyCouponExpired
                  : switch (coupon.type) {
                      CouponType.monthly => strings.couponMonthly,
                      CouponType.oneTime => strings.couponOneTime,
                      CouponType.daily => strings.couponDaily,
                    },
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: AppColors.mutedInk),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: null,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Text(strings.couponUsed),
            ),
          ],
        ],
      ),
    );
  }
}

class CouponScratchReveal extends StatefulWidget {
  const CouponScratchReveal({
    super.key,
    required this.onThresholdReached,
    required this.onTapFallback,
    this.scratchHint,
    this.enabled = true,
    this.threshold = 0.4,
  });

  final VoidCallback onThresholdReached;
  final VoidCallback onTapFallback;
  final String? scratchHint;
  final bool enabled;
  final double threshold;

  @override
  State<CouponScratchReveal> createState() => _CouponScratchRevealState();
}

class _CouponScratchRevealState extends State<CouponScratchReveal> {
  static const _columns = 24;
  static const _rows = 12;

  final Set<int> _scratchedCells = {};
  final List<Offset> _scratchPoints = [];
  bool _thresholdReached = false;

  void _scratch(Offset point, Size size) {
    if (!widget.enabled || _thresholdReached || size.isEmpty) return;
    final x = (point.dx / size.width).clamp(0.0, 1.0);
    final y = (point.dy / size.height).clamp(0.0, 1.0);
    final column = (x * (_columns - 1)).round();
    final row = (y * (_rows - 1)).round();
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        final targetX = column + dx;
        final targetY = row + dy;
        if (targetX >= 0 &&
            targetX < _columns &&
            targetY >= 0 &&
            targetY < _rows) {
          _scratchedCells.add(targetY * _columns + targetX);
        }
      }
    }
    _scratchPoints.add(Offset(x, y));
    if (_scratchedCells.length / (_columns * _rows) >= widget.threshold) {
      _thresholdReached = true;
      widget.onThresholdReached();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scratchHint =
        widget.scratchHint ?? AppLocalizations.of(context)!.couponScratchHint;
    return Semantics(
      button: true,
      label: scratchHint,
      onTap: widget.enabled ? widget.onTapFallback : null,
      child: SizedBox(
        height: 54,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            return GestureDetector(
              key: const ValueKey('scratch-surface'),
              behavior: HitTestBehavior.opaque,
              onTap: widget.enabled ? widget.onTapFallback : null,
              onPanStart: widget.enabled
                  ? (details) => _scratch(details.localPosition, size)
                  : null,
              onPanUpdate: widget.enabled
                  ? (details) => _scratch(details.localPosition, size)
                  : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFFFFF0F4),
                        borderRadius: BorderRadius.all(Radius.circular(13)),
                      ),
                      child: Center(
                        child: Text(
                          scratchHint,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.roseDeep,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    CustomPaint(
                      foregroundPainter: _ScratchCoverPainter(_scratchPoints),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFCE8FA4), Color(0xFFE6B8C6)],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ScratchCoverPainter extends CustomPainter {
  _ScratchCoverPainter(this.points);

  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final scratchPath = Path();
    for (var index = 0; index < points.length; index++) {
      final point = Offset(
        points[index].dx * size.width,
        points[index].dy * size.height,
      );
      if (index == 0) {
        scratchPath.moveTo(point.dx, point.dy);
      } else {
        scratchPath.lineTo(point.dx, point.dy);
      }
    }
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE2A9BA),
    );
    canvas.drawPath(
      scratchPath,
      Paint()
        ..blendMode = BlendMode.clear
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(24, size.height * 0.54)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScratchCoverPainter oldDelegate) =>
      oldDelegate.points != points;
}
