import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const rose = Color(0xFFB63D68);
  static const roseDeep = Color(0xFF843454);
  static const lavender = Color(0xFFE9E2F8);
  static const peach = Color(0xFFFFE3D8);
  static const ink = Color(0xFF513744);
  static const mutedInk = Color(0xFF896F7A);
  static const teal = Color(0xFF598E87);
  static const glassWhite = Color(0xDFFFFFFF);
}

abstract final class AppTheme {
  static const pageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFE5EC), Color(0xFFF2EAFB), Color(0xFFFFE8DC)],
    stops: [0, 0.56, 1],
  );

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.rose,
      surface: const Color(0xFFFFF8FA),
      primary: AppColors.rose,
      secondary: const Color(0xFF9B79B8),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: GoogleFonts.nunito().fontFamily,
      textTheme: GoogleFonts.nunitoTextTheme(
        const TextTheme(
          displaySmall: TextStyle(
            color: AppColors.ink,
            fontSize: 36,
            height: 1.12,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
          headlineSmall: TextStyle(
            color: AppColors.ink,
            fontSize: 25,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
          titleLarge: TextStyle(
            color: AppColors.ink,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: TextStyle(
            color: AppColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: TextStyle(
            color: AppColors.ink,
            fontSize: 16,
            height: 1.45,
          ),
          bodyMedium: TextStyle(
            color: AppColors.mutedInk,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.rose,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.rose
              : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.rose.withValues(alpha: 0.28)
              : const Color(0xFFE9DEE5),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

class AppGradientBackground extends StatelessWidget {
  const AppGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppTheme.pageGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            top: -90,
            right: -80,
            child: _GlowOrb(size: 250, color: Color(0x42FFFFFF)),
          ),
          const Positioned(
            bottom: -100,
            left: -90,
            child: _GlowOrb(size: 280, color: Color(0x38C994BC)),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color, blurRadius: size * 0.36, spreadRadius: 2),
        ],
      ),
      child: SizedBox.square(dimension: size),
    ),
  );
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.glassWhite,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1C8F536D),
                blurRadius: 22,
                offset: Offset(0, 9),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class RomanticTap extends StatefulWidget {
  const RomanticTap({
    super.key,
    required this.child,
    this.onTap,
    this.semanticsLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  @override
  State<RomanticTap> createState() => _RomanticTapState();
}

class _RomanticTapState extends State<RomanticTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );

  void _handleTap() {
    _controller.forward(from: 0);
    widget.onTap?.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticsLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            widget.child,
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final progress = Curves.easeOut.transform(_controller.value);
                  return Opacity(
                    opacity: (1 - progress).clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, -42 * progress),
                      child: Transform.scale(
                        scale: 0.65 + 0.55 * progress,
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: AppColors.rose,
                          size: 25,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
