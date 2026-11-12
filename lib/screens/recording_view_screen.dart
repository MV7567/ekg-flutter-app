import 'dart:math';                          // max, min
import 'package:flutter/foundation.dart';    // compute, Float32List, Int32List
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../ekg_buffer.dart';
import '../ekg_config.dart';
import '../heart_rate_detector.dart';        // average bpm, bpm in the window
import '../recording/recording_file.dart';
import '../widgets/ekg_chart.dart';
import '../widgets/fullscreen_chart.dart';
import '../widgets/zoom_selector.dart';
import '../widgets/heart_rate_text.dart';
import 'recording_actions.dart';             // share, delete
import 'recordings_screen.dart';             // formatStart, formatDuration

// one saved recording: the whole file is loaded, the chart shows a 5 s window,
// the window is moved with the slider or by dragging the chart
class RecordingViewScreen extends StatefulWidget {
  const RecordingViewScreen({super.key, required this.recording});

  final RecordingInfo recording;

  @override
  State<RecordingViewScreen> createState() => _RecordingViewScreenState();
}

class _RecordingViewScreenState extends State<RecordingViewScreen> {
  // the same 5 s buffer as the live chart, but filled with the samples of the window
  final EkgBuffer _window = EkgBuffer(5 * sampleRateHz);

  Float32List? _samples;     // null while loading
  Object? _error;
  int _windowStart = 0;      // sample number of the left edge of the chart
  double _mvPerBigSquare = EkgChart.autoZoom;   // Auto: the QRS of every person fills the chart

  // heart beats of the whole recording, found once while loading
  Int32List _beats = Int32List(0);   // sample numbers of the R waves
  int? _averageBpm;                  // whole recording, null = not enough beats
  // for the 5 s window, ValueNotifiers so the full screen chart gets them too
  final ValueNotifier<int?> _windowBpm = ValueNotifier(null);
  final ValueNotifier<List<int>> _windowBeats = ValueNotifier(const []);   // positions in the window

  int get _maxStart => max(0, (_samples?.length ?? 0) - _window.capacity);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // compute runs the function in a background isolate (a separate thread with its own memory), (works only with static or global functions)
      // so the UI does not freeze while 150 000 lines are parsed and filtered
      // it passes a path (short text), instead of a list of lines because everyhting that gets to isolate is copied
      // the beats are searched in the same background trip (150 000 samples through the detector)
      RecordingData data = await compute(RecordingInfo.loadForView, widget.recording.file.path);
      if (!mounted) return;
      setState(() {
        _samples = data.millivolts;
        _beats = data.beats;
        _averageBpm = HeartRateDetector.averageBpm(data.beats, sampleRateHz);
      });
      _showWindow(0);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  // copies the samples of the window into the chart buffer, the chart repaints by itself
  void _showWindow(int start) {
    Float32List? samples = _samples;
    if (samples == null) return;
    start = start.clamp(0, _maxStart);   // never before the start or after the end
    setState(() => _windowStart = start);
    int end = min(start + _window.capacity, samples.length);
    _window.clear();
    _window.addAll(samples.sublist(start, end));
    // addAll calls notifyListeners, so the chart redraws itself like with BLE

    // the beats inside the window, counted from its left edge (= positions in the buffer)
    _windowBeats.value = [for (int beat in _beats) if (beat >= start && beat < end) beat - start];
    _windowBpm.value = HeartRateDetector.bpmBetween(_beats, start, end, sampleRateHz);
  }

  @override
  void dispose() {
    _windowBpm.dispose();
    _windowBeats.dispose();
    _window.dispose();    // because EkgBuffer is ChangeNotifier
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations t = AppLocalizations.of(context);   // texts in the chosen language
    return Scaffold(
      appBar: AppBar(
        title: Text(RecordingsScreen.formatStart(widget.recording.start, t)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: t.commonShare,
            onPressed: () => shareRecording(context, widget.recording),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: t.commonDelete,
            onPressed: () async {
              bool deleted = await confirmAndDeleteRecording(context, widget.recording);
              // back to the list, true tells it to read the folders again
              if (deleted && context.mounted) Navigator.of(context).pop(true);  // recording scree: "deleted."
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(child: Text(AppLocalizations.of(context).viewOpenError('$_error'), textAlign: TextAlign.center));
    }
    Float32List? samples = _samples;
    if (samples == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (samples.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context).viewNoSamples));
    }

    Duration windowFrom = _sampleTime(_windowStart);
    Duration windowTo = _sampleTime(min(_windowStart + _window.capacity, samples.length));
    Duration total = _sampleTime(samples.length);

    // SafeArea: not under the navigation bar (on the side in landscape)
    // SingleChildScrollView: in landscape the content is higher than the screen -> scroll instead of overflow
    return SafeArea(
      child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            width: double.infinity,
            // LayoutBuilder gives the width, needed to turn a drag in pixels into samples
            child: LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                // finger to the left = later in the recording, like moving paper
                onHorizontalDragUpdate: (details) { //shift in pixels
                  double samplesPerPx = _window.capacity / constraints.maxWidth;
                  _showWindow(_windowStart - (details.delta.dx * samplesPerPx).round());
                },
                // Stack: the full screen button lies on top of the chart
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: EkgChart(
                        buffer: _window,
                        sampleRateHz: sampleRateHz,
                        mvPerBigSquare: _mvPerBigSquare,
                        beatMarkers: _windowBeats,   // red triangles under the R waves
                      ),
                    ),
                    Positioned(top: 0, right: 0, child: FullscreenButton(onPressed: _openFullscreen)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('${RecordingsScreen.formatDuration(windowFrom)} – '
              '${RecordingsScreen.formatDuration(windowTo)}  /  '
              '${RecordingsScreen.formatDuration(total)}'),
          const SizedBox(height: 4),
          // heart rate in the visible 5 s, and of the whole recording
          Wrap(   // Wrap: goes to a second line instead of overflowing on a narrow screen
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            children: [
              HeartRateText(bpm: _windowBpm, fontSize: 22),
              Text(AppLocalizations.of(context).viewAverageBpm(_averageBpm?.toString() ?? '--')),
            ],
          ),
          // a recording shorter than 5 s fits on the chart, nothing to move
          if (_maxStart > 0)
            Slider(
              value: _windowStart.toDouble(), // the first sample of the window
              max: _maxStart.toDouble(),
              onChanged: (value) => _showWindow(value.round()),
            ),
          const SizedBox(height: 8),
          ZoomSelector(   // Auto ×1 ×2 ×4 ×8, the same on every screen
            value: _mvPerBigSquare,
            onChanged: (mv) => setState(() => _mvPerBigSquare = mv),
          ),
        ],
      ),
      ),
    );
  }

  // the same window buffer, dragging there moves the window here
  Future<void> _openFullscreen() async {
    double? mv = await FullscreenChartScreen.open(
      context,
      buffer: _window,
      sampleRateHz: sampleRateHz,
      mvPerBigSquare: _mvPerBigSquare,
      onDragSamples: (samples) => _showWindow(_windowStart + samples),
      bpm: _windowBpm,
      beatMarkers: _windowBeats,
    );
    if (mv != null && mounted) setState(() => _mvPerBigSquare = mv);   // zoom chosen in full screen
  }

  Duration _sampleTime(int sample) =>
      Duration(milliseconds: (sample * 1000 / sampleRateHz).round());
}
