import 'package:flutter/foundation.dart';   // ChangeNotifier and Float32List

// ring buffer: keeps only the newest [capacity] samples,
// when it is full every new sample overwrites the oldest one
// ChangeNotifier: other objects (the chart) can listen and get told when new data arrives
class EkgBuffer extends ChangeNotifier {
  EkgBuffer(this.capacity) : _data = Float32List(capacity); 
  // initialization list, because _data is final and depends on capacity, final needs to be set here 

  final int capacity;       // max number of samples, e.g. 5 s x 250 Hz = 1250
  final Float32List _data;  // the samples in mV, fixed size, allocated once

  int _writeIndex = 0;      // where the next sample will be written
  int _count = 0;           // how many samples are stored (grows until capacity)

  // add one sample (in mV), listeners are NOT told (used by addAll)
  void add(double value) {
    _data[_writeIndex] = value;
    _writeIndex = (_writeIndex + 1) % capacity;   // after the last slot go back to 0
    if (_count < capacity) _count++;
  }

  // add several samples (one BLE packet) and tell the listeners once
  void addAll(List<double> values) {
    for (double v in values) {
      add(v);
    }
    notifyListeners();
  }

  // number of stored samples
  int get length => _count;

  // sample number i, counted from the OLDEST stored sample (0 = oldest, length - 1 = newest)
  double operator [](int i) {
    // the oldest sample is _count places behind the write position
    int oldest = (_writeIndex - _count + capacity) % capacity;
    return _data[(oldest + i) % capacity];
  }

  // remove everything, e.g. when a new recording starts
  void clear() {
    _writeIndex = 0;
    _count = 0;
    notifyListeners();
  }
}
