import 'dart:math';                          // max, min
import 'package:flutter/foundation.dart';    // compute, Float32List
import 'package:flutter/material.dart';
import '../ekg_buffer.dart';
import '../ekg_config.dart';
import '../recording/recording_file.dart';
import '../widgets/ekg_chart.dart';
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
  double _mvPerBigSquare = 0.25;

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
      Float32List samples =
          await compute(RecordingInfo.loadFilteredMillivolts, widget.recording.file.path);
      if (!mounted) return;
      setState(() => _samples = samples);
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
    _window.clear();
    _window.addAll(samples.sublist(start, min(start + _window.capacity, samples.length)));
    // addAll calls notifyListeners, so the chart redraws itself like with BLE
  }

  @override
  void dispose() {
    _window.dispose();    // because EkgBuffer is ChangeNotifier
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(RecordingsScreen.formatStart(widget.recording.start)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: () => shareRecording(context, widget.recording),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete',
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
      return Center(child: Text('Cannot open the recording:\n$_error', textAlign: TextAlign.center));
    }
    Float32List? samples = _samples;
    if (samples == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (samples.isEmpty) {
      return const Center(child: Text('The recording has no samples.'));
    }

    Duration windowFrom = _sampleTime(_windowStart);
    Duration windowTo = _sampleTime(min(_windowStart + _window.capacity, samples.length));
    Duration total = _sampleTime(samples.length);

    return Padding(
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
                child: EkgChart(
                  buffer: _window,
                  sampleRateHz: sampleRateHz,
                  mvPerBigSquare: _mvPerBigSquare,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('${RecordingsScreen.formatDuration(windowFrom)} – '
              '${RecordingsScreen.formatDuration(windowTo)}  /  '
              '${RecordingsScreen.formatDuration(total)}'),
          // a recording shorter than 5 s fits on the chart, nothing to move
          if (_maxStart > 0)
            Slider(
              value: _windowStart.toDouble(), // the first sample of the window
              max: _maxStart.toDouble(),
              onChanged: (value) => _showWindow(value.round()),
            ),
          const SizedBox(height: 8),
          SegmentedButton<double>(   // the same zoom as on the device screen
            segments: const [
              ButtonSegment(value: 0.5, label: Text('×1')),
              ButtonSegment(value: 0.25, label: Text('×2')),
              ButtonSegment(value: 0.125, label: Text('×4')),
            ],
            selected: {_mvPerBigSquare},
            showSelectedIcon: false,
            onSelectionChanged: (selection) =>
                setState(() => _mvPerBigSquare = selection.first),
          ),
        ],
      ),
    );
  }

  Duration _sampleTime(int sample) =>
      Duration(milliseconds: (sample * 1000 / sampleRateHz).round());
}
