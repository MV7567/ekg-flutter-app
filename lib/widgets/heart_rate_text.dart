import 'package:flutter/foundation.dart';   // ValueListenable
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

// "♥ 72 bpm", or "♥ -- bpm" while the heart rate is not known yet
// listens to the ValueNotifier itself: only this small widget redraws when the number changes,
// not the whole screen
// beats (optional): fires on every detected beat -> the heart jumps, like on a hospital monitor
class HeartRateText extends StatefulWidget {
  const HeartRateText({super.key, required this.bpm, this.beats, this.fontSize = 24, this.color});

  final ValueListenable<int?> bpm;
  final Listenable? beats;   // null = the heart stands still (e.g. a saved recording)
  final double fontSize;
  final Color? color;   // null = the normal text color of the theme

  @override
  State<HeartRateText> createState() => _HeartRateTextState();
}

// SingleTickerProviderStateMixin: gives the AnimationController a "ticker",
// a callback on every screen frame (60 or 120 times per second) while the animation runs
class _HeartRateTextState extends State<HeartRateText> with SingleTickerProviderStateMixin {
  // the controller goes 0 -> 1 in 250 ms, every beat starts it again from 0
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 250));

  // 0 -> 1 of the controller becomes the size of the heart: quickly up to 135 %, slower back to 100 %
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 30),   // the first 30 % of the time
    TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 70),   // the rest
  ]).animate(_pulse);

  @override
  void initState() {
    super.initState();
    widget.beats?.addListener(_onBeat);
  }

  // the screen can give a different notifier when it rebuilds, listen to the new one
  @override
  void didUpdateWidget(HeartRateText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.beats != widget.beats) {
      oldWidget.beats?.removeListener(_onBeat);
      widget.beats?.addListener(_onBeat);
    }
  }

  void _onBeat() => _pulse.forward(from: 0);   // from 0: a new beat restarts a running jump

  @override
  void dispose() {
    widget.beats?.removeListener(_onBeat);   // the notifier lives longer than this widget
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations t = AppLocalizations.of(context);
    return ValueListenableBuilder<int?>(
      valueListenable: widget.bpm,
      builder: (context, value, _) => Row(
        mainAxisSize: MainAxisSize.min,   // only as wide as the content, so it can be centered
        children: [
          // ScaleTransition redraws only the heart on every frame, the text stays as it is,
          // scaling does not change the layout, so the text next to it does not jump
          ScaleTransition(
            scale: _scale,
            child: Icon(Icons.favorite, color: Colors.red, size: widget.fontSize),
          ),
          const SizedBox(width: 6),
          Text(
            t.heartRate(value?.toString() ?? '--'),
            style: TextStyle(fontSize: widget.fontSize, fontWeight: FontWeight.bold, color: widget.color),
          ),
        ],
      ),
    );
  }
}
