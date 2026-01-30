import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class DelayCalibrationService {
  final List<int> _delays = [];
  DateTime? _lastBeatTime;
  int _beatCount = 0;
  final int _totalBeats = 8;
  int? _cachedDelayOffset;

  // Callback เมื่อ calibration เสร็จ
  Function(int delayOffset)? onCalibrationComplete;

  // Callback สำหรับอัพเดทความคืบหน้า
  Function(int currentBeat, int totalBeats)? onProgress;

  int get beatCount => _beatCount;
  int get totalBeats => _totalBeats;
  bool get isComplete => _beatCount >= _totalBeats;
  double get progress => _beatCount / _totalBeats;

  // บันทึกเวลาที่ metronome beat
  void onMetronomeBeat(int beatNumber) {
    _lastBeatTime = DateTime.now();
    print('🎵 [CALIB] Beat #$beatNumber at ${_lastBeatTime!.millisecondsSinceEpoch}');
  }

  // เรียกเมื่อตรวจจับโน้ต
  void onNoteDetected(String note) {
    print('🎹 [CALIB] Note detected: $note (beat count: $_beatCount/$_totalBeats)');

    if (_beatCount >= _totalBeats) {
      print('⚠️ [CALIB] Already completed, ignoring note');
      return;
    }

    if (_lastBeatTime == null) {
      print('⚠️ [CALIB] No beat time recorded yet, ignoring note');
      return;
    }

    // For calibration, only accept C4 notes
    if (note != 'C4') {
      print('❌ [CALIB] Wrong note (expected C4, got $note)');
      return;
    }

    final now = DateTime.now();
    final delay = now.difference(_lastBeatTime!).inMilliseconds;
    print('⏱️ [CALIB] Delay calculated: ${delay}ms');

    // กรอง delay ที่ผิดปกติ (< 0 หรือ > 500ms)
    if (delay < 0 || delay > 500) {
      print('⚠️ [CALIB] Delay out of range (${delay}ms), ignoring');
      return;
    }

    _delays.add(delay);
    _beatCount++;
    print('✅ [CALIB] Delay accepted! Progress: $_beatCount/$_totalBeats');

    onProgress?.call(_beatCount, _totalBeats);

    if (_beatCount >= _totalBeats) {
      _completeCalibration();
    }
  }

  void _completeCalibration() {
    if (_delays.isEmpty) return;

    // ใช้ median แทน average เพื่อกรอง outliers
    _delays.sort();
    final median = _delays[_delays.length ~/ 2];

    _saveDelayOffset(median);
    _cachedDelayOffset = median;
    onCalibrationComplete?.call(median);
  }

  Future<void> _saveDelayOffset(int offset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('delay_offset', offset);
  }

  Future<int> getDelayOffset() async {
    // ถ้ามี cache อยู่แล้วใช้เลย
    if (_cachedDelayOffset != null) {
      return _cachedDelayOffset!;
    }

    final prefs = await SharedPreferences.getInstance();
    final offset = prefs.getInt('delay_offset') ?? 0;
    _cachedDelayOffset = offset;
    return offset;
  }

  Future<bool> hasCalibrated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('delay_offset');
  }

  void reset() {
    _delays.clear();
    _lastBeatTime = null;
    _beatCount = 0;
  }

  Future<void> clearCalibration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('delay_offset');
    _cachedDelayOffset = null;
    reset();
  }

  // สำหรับ debug
  List<int> get delays => List.unmodifiable(_delays);
}
