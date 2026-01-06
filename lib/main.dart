import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

void main() => runApp(const MaterialApp(home: BasicPitchPianoApp()));

class BasicPitchPianoApp extends StatefulWidget {
  const BasicPitchPianoApp({super.key});
  @override
  State<BasicPitchPianoApp> createState() => _BasicPitchPianoAppState();
}

class DetectedNote {
  final int midiNote;
  final String noteName;
  final double onset;
  final double offset;
  final double confidence;

  DetectedNote({
    required this.midiNote,
    required this.noteName,
    required this.onset,
    required this.offset,
    required this.confidence,
  });
}

class _BasicPitchPianoAppState extends State<BasicPitchPianoApp> {
  final _recorder = AudioRecorder();
  Interpreter? _interpreter;
  bool _isRecording = false;
  StreamSubscription? _audioSubscription;

  List<DetectedNote> _activeNotes = [];
  String _statusMessage = "Loading model...";
  String _chordName = "";
  double _overallVolume = 0.0;

  // Basic Pitch Constants (MUST be 2 seconds - model requirement)
  static const int sampleRate = 22050;
  static const int fftHop = 256;
  static const int audioWindowLength = 2;
  static const int audioSamples = sampleRate * audioWindowLength - fftHop; // 43844 samples

  // Audio buffer for accumulating samples
  List<double> _audioBuffer = [];
  final int _targetBufferSize = audioSamples;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/nmp.tflite');

      if (mounted) {
        setState(() {
          _statusMessage = "Model loaded! Ready to detect piano notes.";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = "Model load error: $e";
        });
      }
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _audioSubscription?.cancel();
      await _recorder.stop();
      setState(() {
        _isRecording = false;
        _activeNotes = [];
        _chordName = "";
        _statusMessage = "Stopped";
        _audioBuffer.clear();
      });
    } else {
      if (!await Permission.microphone.request().isGranted) {
        setState(() {
          _statusMessage = "Microphone permission denied";
        });
        return;
      }

      if (_interpreter == null) {
        setState(() {
          _statusMessage = "Model not loaded yet";
        });
        return;
      }

      // Start recording at 22050 Hz directly (Basic Pitch requirement)
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 22050,
        numChannels: 1,
      ));

      setState(() {
        _isRecording = true;
        _statusMessage = "Listening...";
        _audioBuffer.clear();
      });

      _audioSubscription = stream.listen((data) {
        _processAudioData(data);
      });
    }
  }

  void _processAudioData(Uint8List data) {
    if (!mounted || _interpreter == null) return;

    // Convert Uint8List to List<double> (PCM16) - already at 22050 Hz
    List<double> samples = [];
    for (int i = 0; i < data.length - 1; i += 2) {
      int sample = data[i] | (data[i + 1] << 8);
      if (sample > 32767) sample -= 65536;
      samples.add(sample / 32768.0); // Normalize to [-1, 1]
    }

    if (samples.isEmpty) return;

    // Add to buffer
    _audioBuffer.addAll(samples);

    // Calculate volume (before inference to show real-time feedback)
    double sumSquares = 0.0;
    for (var s in samples) {
      sumSquares += s * s;
    }
    double rms = sqrt(sumSquares / samples.length);

    if (mounted) {
      setState(() {
        _overallVolume = rms * 10; // Amplify for visibility (clamp to 1.0 in UI)
      });
    }

    // When we have enough samples, run inference
    if (_audioBuffer.length >= _targetBufferSize) {
      List<double> inputAudio = _audioBuffer.take(_targetBufferSize).toList();
      // Use 75% overlap (skip 25%) for responsive real-time detection
      // This updates every ~0.5 seconds
      _audioBuffer = _audioBuffer.skip(_targetBufferSize ~/ 4).toList();

      _runInference(inputAudio);
    }
  }

  void _runInference(List<double> audioSamples) {
    try {
      // Model expects input shape [1, 43844, 1]
      // Reshape audioSamples to 3D: [batch=1][samples=43844][channels=1]
      var input = List.generate(
        1,
        (_) => List.generate(
          audioSamples.length,
          (i) => [audioSamples[i]], // Wrap each sample in array for channel dimension
        ),
      );

      // Prepare outputs - model outputs [1, 172, 88] based on error messages
      int nFrames = 172;
      int nNotes = 88;

      var outputNote = List.generate(
        1,
        (_) => List.generate(nFrames, (_) => List.filled(nNotes, 0.0)),
      );

      var outputOnset = List.generate(
        1,
        (_) => List.generate(nFrames, (_) => List.filled(nNotes, 0.0)),
      );

      var outputContour = List.generate(
        1,
        (_) => List.generate(nFrames, (_) => List.filled(264, 0.0)),
      );

      var outputs = {
        0: outputNote,
        1: outputOnset,
        2: outputContour,
      };

      // Run inference
      _interpreter!.runForMultipleInputs([input], outputs);

      // Post-process outputs
      _postProcessOutputs(outputNote[0], outputOnset[0]);
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = "Inference error: $e";
        });
      }
    }
  }

  void _postProcessOutputs(List<List<double>> noteFrames, List<List<double>> onsetFrames) {
    const double noteThreshold = 0.2; // Lower threshold for better polyphonic detection

    // Find currently active notes using peak detection per frame
    Map<int, double> noteActivations = {};

    // Check each frame independently for polyphonic detection
    for (int frame = 0; frame < noteFrames.length; frame++) {
      for (int note = 0; note < 88; note++) {
        double activation = noteFrames[frame][note];
        double onsetValue = onsetFrames[frame][note];

        // Combine note activation and onset for better detection
        double combined = activation * 0.7 + onsetValue * 0.3;

        if (!noteActivations.containsKey(note) || combined > noteActivations[note]!) {
          noteActivations[note] = combined;
        }
      }
    }

    // Find active notes
    List<DetectedNote> detectedNotes = [];
    noteActivations.forEach((note, activation) {
      if (activation > noteThreshold) {
        String noteName = _midiToNoteName(note + 21); // MIDI 21 = A0

        detectedNotes.add(DetectedNote(
          midiNote: note + 21,
          noteName: noteName,
          onset: 0.0,
          offset: 0.0,
          confidence: activation,
        ));
      }
    });

    // Sort by confidence (highest first)
    detectedNotes.sort((a, b) => b.confidence.compareTo(a.confidence));

    // Keep top 10 notes max
    if (detectedNotes.length > 10) {
      detectedNotes = detectedNotes.take(10).toList();
    }

    // Determine chord name
    String chordName = _getChordName(detectedNotes);

    // Find max activation for debug display
    double maxActivation = 0.0;
    int maxNote = 0;
    noteActivations.forEach((note, activation) {
      if (activation > maxActivation) {
        maxActivation = activation;
        maxNote = note;
      }
    });

    if (mounted) {
      setState(() {
        _activeNotes = detectedNotes;
        _chordName = chordName;
        if (detectedNotes.isNotEmpty) {
          _statusMessage = "Detected ${detectedNotes.length} note(s)";
        } else {
          // Show debug info when no notes detected
          String debugMaxNote = _midiToNoteName(maxNote + 21);
          _statusMessage = "Max: $debugMaxNote (${(maxActivation * 100).toStringAsFixed(1)}%) | Vol: ${(_overallVolume * 100).toStringAsFixed(0)}%";
        }
      });
    }
  }

  String _midiToNoteName(int midiNote) {
    const notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
    int noteIndex = midiNote % 12;
    int octave = (midiNote ~/ 12) - 1;
    return "${notes[noteIndex]}$octave";
  }

  String _getChordName(List<DetectedNote> notes) {
    if (notes.isEmpty) return "";
    if (notes.length == 1) return notes[0].noteName;

    // Get note indices (C=0, C#=1, ..., B=11)
    List<int> noteIndices = notes.map((n) => n.midiNote % 12).toSet().toList();
    noteIndices.sort();

    if (noteIndices.length < 2) return notes[0].noteName;

    // Find root note (lowest note)
    int root = noteIndices[0];
    String rootName = _midiToNoteName(notes.map((n) => n.midiNote).reduce(min));
    rootName = rootName.substring(0, rootName.length - 1); // Remove octave

    // Calculate intervals from root
    List<int> intervals = noteIndices.map((n) => (n - root) % 12).toList()..sort();

    // Common chord patterns
    if (intervals.toString() == "[0, 4, 7]") return "$rootName major";
    if (intervals.toString() == "[0, 3, 7]") return "$rootName minor";
    if (intervals.toString() == "[0, 4, 7, 11]") return "$rootName maj7";
    if (intervals.toString() == "[0, 3, 7, 10]") return "$rootName min7";
    if (intervals.toString() == "[0, 4, 7, 10]") return "$rootName dom7";
    if (intervals.toString() == "[0, 3, 6]") return "$rootName dim";
    if (intervals.toString() == "[0, 4, 8]") return "$rootName aug";
    if (intervals.toString() == "[0, 2, 7]") return "$rootName sus2";
    if (intervals.toString() == "[0, 5, 7]") return "$rootName sus4";

    // If no match, just show notes
    return "${notes.length} notes";
  }

  @override
  void dispose() {
    _audioSubscription?.cancel();
    _recorder.dispose();
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text('Basic Pitch Piano Detector', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Status
              Text(
                _statusMessage,
                style: const TextStyle(color: Colors.green, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Volume meter
              Container(
                width: 300,
                height: 20,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _overallVolume.clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[800],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Chord name (if detected)
              if (_chordName.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.purple, width: 2),
                  ),
                  child: Text(
                    _chordName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // Current notes display
              Container(
                height: 250,
                padding: const EdgeInsets.all(20),
                child: _activeNotes.isEmpty
                    ? const Center(
                        child: Text(
                          "No notes detected",
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      )
                    : Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: _activeNotes.map((note) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: note.confidence),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  note.noteName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "MIDI ${note.midiNote}",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  "${(note.confidence * 100).toStringAsFixed(0)}%",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 30),

              // Control button
              ElevatedButton(
                onPressed: _toggleRecording,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRecording ? Colors.red : Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                ),
                child: Text(
                  _isRecording ? "STOP" : "START",
                  style: const TextStyle(fontSize: 24, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
