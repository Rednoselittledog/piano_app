import 'package:flutter/material.dart';
import 'package:simple_sheet_music/simple_sheet_music.dart';
import '../models/song.dart';

class ColoredSheetMusic extends StatefulWidget {
  final Song song;
  final Map<int, Color> noteColors; // {noteIndex: color}
  final double width;
  final double height;

  const ColoredSheetMusic({
    super.key,
    required this.song,
    this.noteColors = const {},
    this.width = 800,
    this.height = 200,
  });

  @override
  State<ColoredSheetMusic> createState() => _ColoredSheetMusicState();
}

class _ColoredSheetMusicState extends State<ColoredSheetMusic> {
  List<Measure>? _measures;
  bool _isBuilding = false;

  @override
  void initState() {
    super.initState();
    _buildMeasuresAsync();
  }

  @override
  void didUpdateWidget(ColoredSheetMusic oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebuild only if colors changed
    if (oldWidget.noteColors != widget.noteColors) {
      _buildMeasuresAsync();
    }
  }

  Future<void> _buildMeasuresAsync() async {
    if (_isBuilding) return;
    setState(() => _isBuilding = true);

    // Defer to next frame
    await Future.delayed(Duration.zero);

    final measures = _buildMeasures();

    if (mounted) {
      setState(() {
        _measures = measures;
        _isBuilding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_measures == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SimpleSheetMusic(
      width: widget.width,
      height: widget.height,
      measures: _measures!,
    );
  }

  List<Measure> _buildMeasures() {
    final measures = <Measure>[];
    final beatsPerMeasure = int.parse(widget.song.timeSignature.split('/')[0]);

    bool isFirstMeasure = true;

    for (int i = 0; i < widget.song.notes.length; i += beatsPerMeasure) {
      final notesInMeasure = widget.song.notes.sublist(
        i,
        (i + beatsPerMeasure) > widget.song.notes.length
            ? widget.song.notes.length
            : i + beatsPerMeasure,
      );

      final measureElements = <Object>[];

      // ห้องแรก: เพิ่ม clef
      if (isFirstMeasure) {
        measureElements.add(Clef(ClefType.treble));
        isFirstMeasure = false;
      }

      // เพิ่มโน้ต
      for (int j = 0; j < notesInMeasure.length; j++) {
        final noteIndex = i + j;
        final noteEvent = notesInMeasure[j];

        // กำหนดสี
        final color = widget.noteColors[noteIndex] ?? Colors.black;

        final noteData = _parseNote(noteEvent.note);
        measureElements.add(Note(
          noteData.pitch,
          noteDuration: _parseNoteDuration(noteEvent.duration),
          accidental: noteData.accidental,
          color: color,
        ));
      }

      measures.add(Measure(measureElements.cast()));
    }

    return measures;
  }

  _NoteData _parseNote(String noteString) {
    // แปลง "C4", "C#4", "Db4" -> Pitch + Accidental
    final match = RegExp(r'([A-G])([#b]?)(\d+)').firstMatch(noteString);
    if (match == null) return _NoteData(Pitch.c4, null);

    final noteName = match.group(1)!;
    final accidental = match.group(2) ?? '';
    final octave = int.parse(match.group(3)!);

    // แปลง sharp/flat
    Accidental? acc;
    if (accidental == '#') {
      acc = Accidental.sharp;
    } else if (accidental == 'b') {
      acc = Accidental.flat;
    }

    // Map note letter -> Pitch
    final pitch = _getPitch(noteName, octave);

    return _NoteData(pitch, acc);
  }

  Pitch _getPitch(String letter, int octave) {
    // Map แบบง่าย
    final pitchMap = {
      'C': [Pitch.c1, Pitch.c2, Pitch.c3, Pitch.c4, Pitch.c5, Pitch.c6, Pitch.c7, Pitch.c8],
      'D': [Pitch.d1, Pitch.d2, Pitch.d3, Pitch.d4, Pitch.d5, Pitch.d6, Pitch.d7],
      'E': [Pitch.e1, Pitch.e2, Pitch.e3, Pitch.e4, Pitch.e5, Pitch.e6, Pitch.e7],
      'F': [Pitch.f1, Pitch.f2, Pitch.f3, Pitch.f4, Pitch.f5, Pitch.f6, Pitch.f7],
      'G': [Pitch.g1, Pitch.g2, Pitch.g3, Pitch.g4, Pitch.g5, Pitch.g6, Pitch.g7],
      'A': [Pitch.a0, Pitch.a1, Pitch.a2, Pitch.a3, Pitch.a4, Pitch.a5, Pitch.a6, Pitch.a7],
      'B': [Pitch.b0, Pitch.b1, Pitch.b2, Pitch.b3, Pitch.b4, Pitch.b5, Pitch.b6, Pitch.b7],
    };

    final pitches = pitchMap[letter];
    if (pitches == null) return Pitch.c4;

    // C0 ไม่มีใน enum, เริ่มที่ C1
    final index = letter == 'C' ? octave - 1 : (letter == 'A' || letter == 'B') ? octave : octave - 1;
    if (index < 0 || index >= pitches.length) return Pitch.c4;

    return pitches[index];
  }

  NoteDuration _parseNoteDuration(double duration) {
    // แปลงเวลา (วินาที) เป็น NoteDuration
    if (duration <= 0.25) return NoteDuration.sixteenth;
    if (duration <= 0.5) return NoteDuration.eighth;
    if (duration <= 1.0) return NoteDuration.quarter;
    if (duration <= 2.0) return NoteDuration.half;
    return NoteDuration.whole;
  }
}

class _NoteData {
  final Pitch pitch;
  final Accidental? accidental;

  _NoteData(this.pitch, this.accidental);
}
