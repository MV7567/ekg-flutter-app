import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_ble_app/widgets/ekg_chart.dart';

void main() {
  test('scale label shows all digits, without zeros at the end', () {
    expect(EkgChart.scaleLabel(0.2, 0.5), '1 square: 0.2 s × 0.5 mV');
    expect(EkgChart.scaleLabel(0.2, 0.25), '1 square: 0.2 s × 0.25 mV');
    expect(EkgChart.scaleLabel(0.2, 0.125), '1 square: 0.2 s × 0.125 mV');   // was 0.13
    expect(EkgChart.scaleLabel(0.2, 1), '1 square: 0.2 s × 1 mV');
  });
}
