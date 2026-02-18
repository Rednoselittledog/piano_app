import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:record/record.dart';

/// Pitch Detection Service using YIN algorithm (Beethoven-style)
/// Reference: https://github.com/vadymmarkov/Beethoven
/// Algorithm: Autocorrelation-based YIN with CMND + parabolic interpolation
class PitchDetectionServiceSimple {
  AudioRecorder? _audioRecorder;
  StreamSubscription? _audioStreamSubscription;
  bool _isRecording = false;

  // YIN parameters (ตาม Beethoven)
  static const int _sampleRate = 44100;
  static const int _bufferSize = 4096; // ใหญ่กว่าเพื่อ low frequency accuracy
  static const double _yinThreshold = 0.05; // ตาม Beethoven
  static const double _levelThreshold = -40.0; // dBFS

  // Smoothing
  final List<double> _pitchHistory = [];
  DateTime _lastUpdate = DateTime.now();

  // Callback เมื่อตรวจจับโน้ต
  Function(String note, double frequency, double confidence)? onNoteDetected;

  bool get isRecording => _isRecording;

  Future<bool> start() async {
    print('🎙️ [YIN] Starting pitch detection...');

    if (_isRecording) {
      print('⚠️ [YIN] Already recording');
      return true;
    }

    try {
      _audioRecorder = AudioRecorder();

      final hasPermission = await _audioRecorder!.hasPermission();
      if (!hasPermission) {
        print('❌ [YIN] No microphone permission');
        return false;
      }

      if (await _audioRecorder!.isRecording()) {
        await _audioRecorder!.stop();
      }

      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
      );

      print('🎤 [YIN] Starting audio stream...');
      final stream = await _audioRecorder!.startStream(config);
      _isRecording = true;

      // Buffer accumulator เพราะ stream อาจส่งมาทีละน้อย
      final List<double> accumulator = [];

      // ทิ้ง 500ms แรก เพื่อให้ mic stabilize
      bool skipInitialFrames = true;
      final DateTime startTime = DateTime.now();

      _audioStreamSubscription = stream.listen((data) {
        if (skipInitialFrames) {
          if (DateTime.now().difference(startTime).inMilliseconds > 500) {
            skipInitialFrames = false;
            print('✅ [YIN] Initial frames skipped, now processing...');
          } else {
            return;
          }
        }

        // แปลง bytes เป็น float แล้วเพิ่มใน accumulator
        final samples = _convertBytesToFloat(Uint8List.fromList(data));
        accumulator.addAll(samples);

        // เมื่อสะสมครบ bufferSize แล้วค่อยประมวลผล
        while (accumulator.length >= _bufferSize) {
          final buffer = accumulator.sublist(0, _bufferSize);
          accumulator.removeRange(0, _bufferSize);
          _processBuffer(buffer);
        }
      });

      return true;
    } catch (e) {
      print('❌ [YIN] Error: $e');
      return false;
    }
  }

  void _processBuffer(List<double> buffer) {
    // 1. เช็ค level threshold (-60 dBFS)
    final rms = _calculateRMS(buffer);
    final dBFS = _rmsToDBFS(rms);
    print('📊 [YIN] Level: ${dBFS.toStringAsFixed(1)} dBFS');

    if (dBFS < _levelThreshold) {
      // เสียงเบาเกินไป → เคลียร์ history ถ้าเงียบนาน
      if (DateTime.now().difference(_lastUpdate).inMilliseconds > 500) {
        _pitchHistory.clear();
        print('🔇 [YIN] Below threshold (${dBFS.toStringAsFixed(1)} dBFS), clearing history');
      }
      return;
    }

    // 2. YIN: Difference Function
    final yinBuffer = _differenceFunction(buffer);

    // 3. YIN: Cumulative Mean Normalized Difference (CMND)
    _cumulativeMeanNormalizedDifference(yinBuffer);

    // 4. YIN: Absolute Threshold + Parabolic Interpolation
    final result = _absoluteThreshold(yinBuffer);
    if (result == null) {
      print('🔕 [YIN] No pitch detected (threshold not met)');
      return;
    }

    final tau = result['tau']!;
    final confidence = 1.0 - result['value']!; // invert ให้เป็น confidence

    // 5. คำนวณ frequency จาก tau
    final frequency = _sampleRate / tau;

    print('🎵 [YIN] tau=$tau, freq=${frequency.toStringAsFixed(1)} Hz, confidence=${confidence.toStringAsFixed(3)}');

    _updateNote(frequency, confidence);
  }

  // ---- YIN Algorithm Steps ----

  /// Step 1: Difference Function
  /// d(tau) = sum[ (x(j) - x(j+tau))^2 ]
  List<double> _differenceFunction(List<double> buffer) {
    final halfLen = buffer.length ~/ 2;
    final yinBuffer = List<double>.filled(halfLen, 0.0);

    // yinBuffer[0] = 0 โดย definition
    yinBuffer[0] = 0.0;

    for (int tau = 1; tau < halfLen; tau++) {
      double sum = 0.0;
      for (int j = 0; j < halfLen; j++) {
        final delta = buffer[j] - buffer[j + tau];
        sum += delta * delta;
      }
      yinBuffer[tau] = sum;
    }

    return yinBuffer;
  }

  /// Step 2: Cumulative Mean Normalized Difference (CMND)
  /// d'(tau) = 1 if tau==0, else d(tau) / [(1/tau) * sum_{j=1}^{tau} d(j)]
  void _cumulativeMeanNormalizedDifference(List<double> yinBuffer) {
    double runningSum = 0.0;
    yinBuffer[0] = 1.0;

    for (int tau = 1; tau < yinBuffer.length; tau++) {
      runningSum += yinBuffer[tau];
      if (runningSum == 0.0) {
        yinBuffer[tau] = 1.0;
      } else {
        yinBuffer[tau] = yinBuffer[tau] * tau / runningSum;
      }
    }
  }

  /// Step 3: Absolute Threshold
  /// หา tau แรกที่ yinBuffer[tau] < threshold และเป็น local minimum
  /// คืนค่า {tau, value} พร้อม parabolic interpolation
  Map<String, double>? _absoluteThreshold(List<double> yinBuffer) {
    for (int tau = 2; tau < yinBuffer.length - 1; tau++) {
      if (yinBuffer[tau] < _yinThreshold) {
        // ค้นหา local minimum โดยเลื่อนไปจนกว่า value จะเพิ่มขึ้น
        while (tau + 1 < yinBuffer.length && yinBuffer[tau + 1] < yinBuffer[tau]) {
          tau++;
        }

        // Parabolic Interpolation เพื่อ sub-sample precision
        final interpolated = _parabolicInterpolation(yinBuffer, tau);
        return {'tau': interpolated, 'value': yinBuffer[tau]};
      }
    }

    // ไม่เจอ pitch ที่ผ่าน threshold
    return null;
  }

  /// Parabolic Interpolation
  /// หา minimum จริงระหว่าง sample โดยใช้ parabola fit
  double _parabolicInterpolation(List<double> buffer, int tau) {
    final x0 = tau - 1;
    final x2 = tau + 1;

    if (x0 < 0) return tau.toDouble();
    if (x2 >= buffer.length) return tau.toDouble();

    // Fit parabola ผ่าน 3 จุด: (x0, y0), (tau, y1), (x2, y2)
    final y0 = buffer[x0];
    final y1 = buffer[tau];
    final y2 = buffer[x2];

    // Vertex ของ parabola: x = tau + (y0 - y2) / (2 * (y0 - 2*y1 + y2))
    final denominator = 2.0 * (y0 - 2.0 * y1 + y2);
    if (denominator.abs() < 1e-10) return tau.toDouble(); // ป้องกัน div by zero

    final betterTau = tau + (y0 - y2) / denominator;
    return betterTau;
  }

  // ---- Helper Functions ----

  /// คำนวณ RMS (Root Mean Square)
  double _calculateRMS(List<double> buffer) {
    if (buffer.isEmpty) return 0.0;
    double sum = 0.0;
    for (final sample in buffer) {
      sum += sample * sample;
    }
    return sqrt(sum / buffer.length);
  }

  /// แปลง RMS เป็น dBFS
  /// dBFS = 20 * log10(rms)
  /// 0 dBFS = maximum level, -60 dBFS = near silence
  double _rmsToDBFS(double rms) {
    if (rms <= 0.0) return -100.0;
    return 20.0 * log(rms) / ln10;
  }

  void _updateNote(double pitch, double confidence) {
    // กรองช่วง piano: A0 (27.5 Hz) ถึง C8 (4186 Hz)
    if (pitch < 27.5 || pitch > 4186.0) {
      print('⚠️ [YIN] Out of piano range: ${pitch.toStringAsFixed(1)} Hz');
      return;
    }

    _pitchHistory.add(pitch);
    if (_pitchHistory.length > 5) _pitchHistory.removeAt(0);

    // Throttle callback ทุก 150ms
    if (DateTime.now().difference(_lastUpdate).inMilliseconds > 150) {
      final avgPitch = _pitchHistory.reduce((a, b) => a + b) / _pitchHistory.length;
      final note = _getNoteFromHz(avgPitch);

      print('✅ [YIN] Note: $note (${avgPitch.toStringAsFixed(1)} Hz, conf=${confidence.toStringAsFixed(3)})');

      onNoteDetected?.call(note, avgPitch, confidence);
      _lastUpdate = DateTime.now();
    }
  }

  /// แปลง frequency เป็น note name
  /// n = round(12 * log2(f / 440) + 69)
  String _getNoteFromHz(double frequency) {
    final n = (12.0 * (log(frequency / 440.0) / ln2) + 69.0).round();
    const noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final octave = (n ~/ 12) - 1;
    final noteName = noteNames[n % 12];
    return '$noteName$octave';
  }

  /// แปลง PCM 16-bit bytes เป็น float [-1.0, 1.0]
  List<double> _convertBytesToFloat(Uint8List bytes) {
    final int16 = Int16List.view(bytes.buffer);
    return int16.map((x) => x / 32768.0).toList();
  }

  Future<void> stop() async {
    print('🛑 [YIN] Stopping...');
    await _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;

    if (_audioRecorder != null && await _audioRecorder!.isRecording()) {
      await _audioRecorder!.stop();
    }
    if (_audioRecorder != null) {
      await _audioRecorder!.dispose();
      _audioRecorder = null;
    }

    _isRecording = false;
    _pitchHistory.clear();
    print('🛑 [YIN] Stopped');
  }

  Future<void> dispose() async {
    await stop();
  }
}
