import 'package:flutter/foundation.dart';   // ValueListenable
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';   // SystemChrome: orientation and system bars
import '../ekg_buffer.dart';
import '../l10n/app_localizations.dart';
import 'ekg_chart.dart';
import 'heart_rate_text.dart';
import 'zoom_selector.dart';

// the chart over the whole screen, turned to landscape, without the status and navigation bars,
// like full screen video on YouTube
// it shows the SAME buffer as the screen below, so a live recording keeps drawing here
class FullscreenChartScreen extends StatefulWidget {
  const FullscreenChartScreen({
    super.key,
    required this.buffer,
    required this.sampleRateHz,
    required this.mvPerBigSquare,
    this.onDragSamples,
    this.bpm,
    this.beats,
    this.beatMarkers,
  });

  final EkgBuffer buffer;
  final int sampleRateHz;
  final double mvPerBigSquare;
  // only for recordings: a drag moves the window by this many samples (null = live, no dragging)
  final void Function(int samples)? onDragSamples;
  // the heart rate under the scale text: live, or of the 5 s window of a recording (null = not shown)
  final ValueListenable<int?>? bpm;
  // only live: fires on every beat, the heart jumps (see HeartRateText)
  final Listenable? beats;
  // only recordings: where the R waves are in the buffer (see EkgChart)
  final ValueListenable<List<int>>? beatMarkers;

  // opens the screen, returns the zoom chosen there, so the screen below can take it over
  static Future<double?> open(
    BuildContext context, {
    required EkgBuffer buffer,
    required int sampleRateHz,
    required double mvPerBigSquare,
    void Function(int samples)? onDragSamples,
    ValueListenable<int?>? bpm,
    Listenable? beats,
    ValueListenable<List<int>>? beatMarkers,
  }) {
    return Navigator.of(context).push<double>(MaterialPageRoute(
      builder: (context) => FullscreenChartScreen(
        buffer: buffer,
        sampleRateHz: sampleRateHz,
        mvPerBigSquare: mvPerBigSquare,
        onDragSamples: onDragSamples,
        bpm: bpm,
        beats: beats,
        beatMarkers: beatMarkers,
      ),
    ));
  }

  @override
  State<FullscreenChartScreen> createState() => _FullscreenChartScreenState();
}

class _FullscreenChartScreenState extends State<FullscreenChartScreen> {
  late double _mvPerBigSquare = widget.mvPerBigSquare;

  @override
  void initState() {
    super.initState();
    // only the two landscape directions, the phone can still be turned 180°
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // hide the status and navigation bars, a swipe from the edge shows them for a moment
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // back to normal: every orientation allowed again, bars visible
    SystemChrome.setPreferredOrientations([]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    EkgChartColors chartColors = EkgChartColors.of(context);   // for the buttons on the chart
    // the back gesture also gives the zoom back, not only the exit button
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_mvPerBigSquare);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        // SafeArea: keeps the chart away from the camera cut-out in landscape
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) => GestureDetector(
                    onHorizontalDragUpdate: widget.onDragSamples == null
                        ? null
                        : (details) {
                            // the whole buffer = the whole width, finger left = later
                            double samplesPerPx = widget.buffer.capacity / constraints.maxWidth;
                            widget.onDragSamples!(-(details.delta.dx * samplesPerPx).round());
                          },
                    child: EkgChart(
                      buffer: widget.buffer,
                      sampleRateHz: widget.sampleRateHz,
                      mvPerBigSquare: _mvPerBigSquare,
                      beatMarkers: widget.beatMarkers,
                    ),
                  ),
                ),
              ),
              // heart rate under the scale text (the bottom edge has the beat markers),
              // in the color that is readable on the chart (dark on paper, light on the monitor)
              if (widget.bpm != null)
                Positioned(
                  left: 8,
                  top: 20,
                  child: HeartRateText(bpm: widget.bpm!, beats: widget.beats, fontSize: 22, color: chartColors.controls),
                ),
              // buttons in the top right corner, the scale text is in the top left
              Positioned(
                top: 0,
                right: 0,
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(
                          () => _mvPerBigSquare = ZoomSelector.next(_mvPerBigSquare)),   // Auto -> ×1 -> ... -> ×8 -> Auto
                      child: Text(ZoomSelector.label(_mvPerBigSquare, AppLocalizations.of(context)),
                          style: TextStyle(color: chartColors.controls, fontSize: 18)),
                    ),
                    IconButton(
                      icon: Icon(Icons.fullscreen_exit, color: chartColors.controls),
                      tooltip: AppLocalizations.of(context).fullscreenExit,
                      onPressed: () => Navigator.of(context).pop(_mvPerBigSquare),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// small button for the top right corner of a normal chart, opens the full screen
class FullscreenButton extends StatelessWidget {
  const FullscreenButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      // dark on the paper, light on the monitor (dark theme)
      icon: Icon(Icons.fullscreen, color: EkgChartColors.of(context).controls),
      tooltip: AppLocalizations.of(context).fullscreenEnter,
      onPressed: onPressed,
    );
  }
}
