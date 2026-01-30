import 'package:metronome/metronome.dart';

class MetronomeService {
  final Metronome _metronome = Metronome();
  int _bpm = 120;
  bool _isRunning = false;
  int _beatsPerMeasure = 4;

  // Callback เมื่อมี beat
  Function(int beatNumber)? onBeat;

  int get bpm => _bpm;
  bool get isRunning => _isRunning;
  int get currentBeat => 0; // Metronome package จัดการ beat เอง

  MetronomeService({int bpm = 120, int beatsPerMeasure = 4}) {
    _bpm = bpm;
    _beatsPerMeasure = beatsPerMeasure;
    _initMetronome();
  }

  Future<void> _initMetronome() async {
    try {
      await _metronome.init(
        'assets/audio/click.wav',
        bpm: _bpm,
        volume: 15, // ลดเสียงมาก ๆ เพื่อไม่ให้รบกวน microphone (0-100)
        enableTickCallback: true,
        timeSignature: _beatsPerMeasure,
      );

      // รับ callback เมื่อมี beat ผ่าน stream
      _metronome.tickStream.listen((tick) {
        onBeat?.call(tick);
      });

      print('✅ Metronome initialized');
    } catch (e) {
      print('❌ Failed to init metronome: $e');
    }
  }

  void start() {
    if (_isRunning) return;
    _metronome.play();
    _isRunning = true;
  }

  void stop() {
    _metronome.stop();
    _isRunning = false;
  }

  void setBPM(int newBpm) {
    _bpm = newBpm;
    _metronome.setBPM(newBpm);
  }

  void setBeatsPerMeasure(int beats) {
    _beatsPerMeasure = beats;
    _metronome.setTimeSignature(beats);
  }

  void dispose() {
    stop();
    _metronome.destroy();
  }
}
