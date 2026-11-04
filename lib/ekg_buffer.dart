import 'package:flutter/foundation.dart';   // ChangeNotifier and Float32List

// ring buffer: keeps only the newest [capacity] samples,
// when it is full every new sample overwrites the oldest one, a normal list would keep shifting the existing samples and would be slow
// ChangeNotifier: other objects (the chart) can listen and get told when new data arrives
class EkgBuffer extends ChangeNotifier {
  EkgBuffer(this.capacity) : _data = Float32List(capacity); 
  // initialization list, because _data is final and depends on capacity, final needs to be set here 

  final int capacity;       // max number of samples, e.g. 5 s x 250 Hz = 1250
  final Float32List _data;  // the samples in mV, fixed size, allocated once
  // a list saves every digit as a double, float32list saves 4 bytes per sample, so it is more memory efficient

  int _writeIndex = 0;      // where the next sample will be written
  int _count = 0;           // how many samples are stored (grows until capacity)

  // add one sample (in mV), listeners are NOT told (used by addAll)
  void add(double value) {
    _data[_writeIndex] = value;
    _writeIndex = (_writeIndex + 1) % capacity;   // after the last slot go back to 0
    if (_count < capacity) _count++;
  }
  // add the sample to the current "drawer" 
  // shift the write index to the next slot, wrap around if needed (% capacity)
  // _count grows until capacity then stays there at 1250
  // no notifyListeners() here, see addAll()

  // add several samples (one BLE packet) and tell the listeners once
  void addAll(List<double> values) {
    for (double v in values) {
      add(v);
    }
    notifyListeners();
  }
  // 10 samples from the packet and then tell the listeners once, so the chart is not redrawn 10 times

  // number of stored samples
  int get length => _count;

  // sample number i, counted from the OLDEST stored sample (0 = oldest, length - 1 = newest)
  double operator [](int i) {
    // a wrong index would silently return an old value from some slot,
    // assert stops with an error, but only in debug mode (no cost in the release app)
    assert(i >= 0 && i < _count, 'EkgBuffer index $i out of range 0..${_count - 1}');

    // the oldest sample is _count places behind the write position
    int oldest = (_writeIndex - _count + capacity) % capacity;
    return _data[(oldest + i) % capacity];
  }
  // operator [] is a getter, so you can use it like a list: buffer[0] gives the oldest sample, buffer[buffer.length - 1] gives the newest

  // remove everything, e.g. when a new recording starts
  void clear() {
    _writeIndex = 0;
    _count = 0;
    notifyListeners();
  }
  // _data is not cleared, but the next samples will overwrite the old ones, and the chart will be redrawn with no samples
}
