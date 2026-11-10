import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_ble_app/widgets/fullscreen_chart.dart';

void main() {
  test('zoom button goes ×1 -> ×2 -> ×4 -> ×1', () {
    expect(FullscreenChartScreen.nextZoom(0.5), 0.25);
    expect(FullscreenChartScreen.nextZoom(0.25), 0.125);
    expect(FullscreenChartScreen.nextZoom(0.125), 0.5);
    expect(FullscreenChartScreen.nextZoom(0.3), 0.5);   // unknown value -> the first step
  });

  test('zoom label', () {
    expect(FullscreenChartScreen.zoomLabel(0.5), '×1');
    expect(FullscreenChartScreen.zoomLabel(0.25), '×2');
    expect(FullscreenChartScreen.zoomLabel(0.125), '×4');
  });
}
