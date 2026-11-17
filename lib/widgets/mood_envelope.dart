import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/daily_mood.dart';

const moodEnvelopeAnimationFramesPerSecond = 30;
const moodEnvelopeFrameInterval = Duration(microseconds: 33333);
const _frameCount = 18;
const moodEnvelopeFaceFrameCount = 60;

int moodEnvelopeFaceFrameIndex(Duration elapsed) =>
    ((elapsed.inMicroseconds * moodEnvelopeAnimationFramesPerSecond) ~/
        Duration.microsecondsPerSecond) %
    moodEnvelopeFaceFrameCount;

class MoodIncomingEnvelope extends StatefulWidget {
  const MoodIncomingEnvelope({super.key, required this.mood});

  final DailyMood mood;

  @override
  State<MoodIncomingEnvelope> createState() => _MoodIncomingEnvelopeState();
}

class _MoodIncomingEnvelopeState extends State<MoodIncomingEnvelope>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  int _frame = 0;
  int _faceFrame = 0;
  bool _isOpen = false;
  bool _opening = true;

  @override
  void didUpdateWidget(covariant MoodIncomingEnvelope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mood != oldWidget.mood) {
      _ticker.stop();
      setState(() {
        _isOpen = false;
        _opening = true;
        _frame = 0;
        _faceFrame = 0;
      });
    }
  }

  void _onTick(Duration elapsed) {
    final tick =
        elapsed.inMicroseconds *
        moodEnvelopeAnimationFramesPerSecond ~/
        Duration.microsecondsPerSecond;
    if (!_opening && tick >= _frameCount) {
      _ticker.stop();
      setState(() => _frame = 0);
      return;
    }
    final frame = _opening
        ? tick.clamp(0, _frameCount - 1).toInt()
        : (_frameCount - 1 - tick).clamp(0, _frameCount - 1).toInt();
    final faceFrame = _isOpen ? moodEnvelopeFaceFrameIndex(elapsed) : 0;
    if (frame != _frame || faceFrame != _faceFrame) {
      setState(() {
        _frame = frame;
        _faceFrame = faceFrame;
      });
    }
  }

  void _toggle() {
    _opening = !_isOpen;
    _isOpen = _opening;
    _frame = _opening ? 0 : _frameCount - 1;
    _faceFrame = 0;
    _ticker
      ..stop()
      ..start();
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final moodName = _moodLabel(strings, widget.mood);
    final label = _isOpen
        ? strings.duckMoodEnvelopeOpen(moodName)
        : strings.duckMoodEnvelopeClosed;
    final frame = _frame;
    final faceFrame = _faceFrame;
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          key: const ValueKey('incoming-mood-envelope'),
          onTap: _toggle,
          child: SizedBox(
            key: ValueKey('incoming-mood-envelope-frame-$frame'),
            width: 96,
            height: 96,
            child: Stack(
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      maxWidth: 96.0 * _frameCount,
                      maxHeight: 96,
                      child: Transform.translate(
                        offset: Offset(-96.0 * frame, 0),
                        child: Image.asset(
                          'assets/images/mood_envelopes/envelope_opening_sheet.png',
                          width: 96.0 * _frameCount,
                          height: 96,
                          filterQuality: FilterQuality.none,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_frame >= 8)
                  Positioned(
                    left: 30,
                    top: 7,
                    child: SizedBox(
                      key: const ValueKey('mood-envelope-face'),
                      width: 36,
                      height: 36,
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.centerLeft,
                          maxWidth: 36.0 * moodEnvelopeFaceFrameCount,
                          maxHeight: 36,
                          child: Transform.translate(
                            key: ValueKey(
                              'mood-envelope-face-frame-$faceFrame',
                            ),
                            offset: Offset(-36.0 * faceFrame, 0),
                            child: Image.asset(
                              'assets/images/mood_envelopes/'
                              '${widget.mood.name}_loop.png',
                              width: 36.0 * moodEnvelopeFaceFrameCount,
                              height: 36,
                              filterQuality: FilterQuality.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
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
