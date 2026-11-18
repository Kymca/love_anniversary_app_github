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
  const MoodIncomingEnvelope({
    super.key,
    required this.mood,
    this.size = const Size(96, 96),
  });

  final DailyMood? mood;
  final Size size;

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
    final mood = widget.mood;
    final label = mood == null
        ? strings.duckMoodEnvelopeUnavailable
        : _isOpen
        ? strings.duckMoodEnvelopeOpen(_moodLabel(strings, mood))
        : strings.duckMoodEnvelopeClosed;
    final frame = _frame;
    final faceFrame = _faceFrame;
    return Semantics(
      button: mood != null,
      enabled: mood != null,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          key: const ValueKey('incoming-mood-envelope'),
          onTap: mood == null ? null : _toggle,
          child: SizedBox(
            key: ValueKey('incoming-mood-envelope-frame-$frame'),
            width: widget.size.width,
            height: widget.size.height,
            child: Stack(
              children: [
                SizedBox(
                  width: widget.size.width,
                  height: widget.size.height,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      maxWidth: widget.size.width * _frameCount,
                      maxHeight: widget.size.height,
                      child: Transform.translate(
                        offset: Offset(-widget.size.width * frame, 0),
                        child: Image.asset(
                          'assets/images/mood_envelopes/envelope_opening_sheet.png',
                          width: widget.size.width * _frameCount,
                          height: widget.size.height,
                          filterQuality: FilterQuality.none,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_frame >= 8 && mood != null)
                  Positioned(
                    left: widget.size.width * 0.3125,
                    top: widget.size.height * 0.0729,
                    child: SizedBox(
                      key: const ValueKey('mood-envelope-face'),
                      width: widget.size.width * 0.375,
                      height: widget.size.height * 0.375,
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.centerLeft,
                          maxWidth:
                              widget.size.width *
                              0.375 *
                              moodEnvelopeFaceFrameCount,
                          maxHeight: widget.size.height * 0.375,
                          child: Transform.translate(
                            key: ValueKey(
                              'mood-envelope-face-frame-$faceFrame',
                            ),
                            offset: Offset(
                              -widget.size.width * 0.375 * faceFrame,
                              0,
                            ),
                            child: Image.asset(
                              'assets/images/mood_envelopes/'
                              '${mood.name}_loop.png',
                              width:
                                  widget.size.width *
                                  0.375 *
                                  moodEnvelopeFaceFrameCount,
                              height: widget.size.height * 0.375,
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
