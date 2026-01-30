import 'package:flutter/material.dart';
import 'calibration_screen.dart';
import 'play_screen.dart';
import '../services/metronome_service.dart';
import '../services/pitch_detection_service_simple.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final MetronomeService _metronome;
  late final PitchDetectionServiceSimple _pitchDetection;
  bool _isMetronomePlaying = false;
  bool _isPitchDetecting = false;
  String _detectedNote = '--';
  double _detectedFreq = 0.0;
  double _detectedProb = 0.0;

  @override
  void initState() {
    super.initState();
    _metronome = MetronomeService(bpm: 120);
    _pitchDetection = PitchDetectionServiceSimple();

    // Setup pitch detection callback
    _pitchDetection.onNoteDetected = (note, freq, prob) {
      if (mounted) {
        setState(() {
          _detectedNote = note;
          _detectedFreq = freq;
          _detectedProb = prob;
        });
      }
    };
  }

  @override
  void dispose() {
    _metronome.dispose();
    _pitchDetection.dispose();
    super.dispose();
  }

  void _toggleMetronome() {
    setState(() {
      if (_isMetronomePlaying) {
        _metronome.stop();
        _isMetronomePlaying = false;
      } else {
        _metronome.start();
        _isMetronomePlaying = true;
      }
    });
  }

  void _togglePitchDetection() async {
    if (_isPitchDetecting) {
      await _pitchDetection.stop();
      setState(() {
        _isPitchDetecting = false;
        _detectedNote = '--';
        _detectedFreq = 0.0;
        _detectedProb = 0.0;
      });
    } else {
      final started = await _pitchDetection.start();
      if (started && mounted) {
        setState(() {
          _isPitchDetecting = true;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot access microphone')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Piano Rhythm Trainer'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.piano, size: 60, color: Colors.blue),
                const SizedBox(height: 15),
                const Text(
                  'Piano Rhythm Trainer',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Train your piano rhythm skills',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () async {
                    print('🔘 [HOME] Calibrate button pressed');

                    // Stop pitch detection ก่อนไป calibration screen
                    if (_isPitchDetecting) {
                      print('🛑 [HOME] Stopping pitch detection before calibration');
                      await _pitchDetection.stop();
                      setState(() {
                        _isPitchDetecting = false;
                        _detectedNote = '--';
                        _detectedFreq = 0.0;
                        _detectedProb = 0.0;
                      });
                    }

                    // Stop metronome ด้วย
                    if (_isMetronomePlaying) {
                      print('🛑 [HOME] Stopping metronome before calibration');
                      _metronome.stop();
                      setState(() => _isMetronomePlaying = false);
                    }

                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) {
                            print('📱 [HOME] Building CalibrationScreen');
                            return const CalibrationScreen();
                          },
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.tune, size: 20),
                  label: const Text('Calibrate Delay'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 15),
                ElevatedButton.icon(
                  onPressed: () async {
                    print('🔘 [HOME] Practice button pressed');

                    // Stop pitch detection ก่อนไป play screen
                    if (_isPitchDetecting) {
                      print('🛑 [HOME] Stopping pitch detection before practice');
                      await _pitchDetection.stop();
                      setState(() {
                        _isPitchDetecting = false;
                        _detectedNote = '--';
                        _detectedFreq = 0.0;
                        _detectedProb = 0.0;
                      });
                    }

                    // Stop metronome ด้วย
                    if (_isMetronomePlaying) {
                      print('🛑 [HOME] Stopping metronome before practice');
                      _metronome.stop();
                      setState(() => _isMetronomePlaying = false);
                    }

                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) {
                            print('📱 [HOME] Building PlayScreen');
                            return const PlayScreen();
                          },
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.play_arrow, size: 20),
                  label: const Text('Practice Song'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 30),
                const Divider(),
                const SizedBox(height: 10),
                const Text(
                  'Test Metronome',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _toggleMetronome,
                  icon: Icon(_isMetronomePlaying ? Icons.stop : Icons.volume_up),
                  label: Text(_isMetronomePlaying ? 'Stop Metronome' : 'Play Metronome'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    textStyle: const TextStyle(fontSize: 16),
                    backgroundColor: _isMetronomePlaying ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),
                const Text(
                  'Test Pitch Detection',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _togglePitchDetection,
                  icon: Icon(_isPitchDetecting ? Icons.stop : Icons.mic),
                  label: Text(_isPitchDetecting ? 'Stop Detection' : 'Start Detection'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    textStyle: const TextStyle(fontSize: 16),
                    backgroundColor: _isPitchDetecting ? Colors.red : Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                if (_isPitchDetecting) ...[
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Note: $_detectedNote',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Frequency: ${_detectedFreq.toStringAsFixed(1)} Hz',
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Confidence: ${(_detectedProb * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.all(10.0),
                  child: Text(
                    'Tip: Calibrate first to measure your detection delay,\nthen practice songs for better accuracy!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
