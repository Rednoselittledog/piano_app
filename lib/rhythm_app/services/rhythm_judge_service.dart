import 'package:flutter/material.dart';
import '../models/song.dart';

enum JudgmentLevel {
  perfect,  // เขียว
  good,     // เหลือง
  miss,     // แดง
}

class Judgment {
  final int noteIndex;
  final JudgmentLevel level;
  final double errorPercent;
  final String expectedNote;
  final String playedNote;
  final double expectedTime;
  final double actualTime;

  Judgment({
    required this.noteIndex,
    required this.level,
    required this.errorPercent,
    required this.expectedNote,
    required this.playedNote,
    required this.expectedTime,
    required this.actualTime,
  });

  Color get color {
    switch (level) {
      case JudgmentLevel.perfect:
        return Colors.green;
      case JudgmentLevel.good:
        return Colors.yellow;
      case JudgmentLevel.miss:
        return Colors.red;
    }
  }
}

class RhythmJudgeService {
  final Song song;
  final int delayOffset; // milliseconds

  DateTime? _startTime;
  int _currentNoteIndex = 0;
  final Map<int, Judgment> _judgments = {};
  final List<RecordedNote> _recordedNotes = [];

  // Callback
  Function(Judgment judgment)? onJudgment;

  RhythmJudgeService({
    required this.song,
    required this.delayOffset,
  });

  Map<int, Judgment> get judgments => Map.unmodifiable(_judgments);
  List<RecordedNote> get recordedNotes => List.unmodifiable(_recordedNotes);
  int get currentNoteIndex => _currentNoteIndex;
  bool get isComplete => _currentNoteIndex >= song.notes.length;

  void onNoteDetected(String detectedNote, DateTime detectedTime) {
    // บันทึกโน้ตที่กด
    if (_startTime == null) {
      _startTime = detectedTime;
      _recordedNotes.add(RecordedNote(note: detectedNote, timestamp: 0.0));
    } else {
      final elapsed = detectedTime.difference(_startTime!).inMilliseconds / 1000.0;
      _recordedNotes.add(RecordedNote(note: detectedNote, timestamp: elapsed));
    }

    // ถ้าเล่นจบแล้ว ไม่ต้องให้คะแนน
    if (_currentNoteIndex >= song.notes.length) return;

    final expectedNote = song.notes[_currentNoteIndex];

    // คำนวณเวลาจริง (ชดเชย delay)
    final elapsedMs = detectedTime.difference(_startTime!).inMilliseconds - delayOffset;
    final actualTime = elapsedMs / 1000.0;

    // คำนวณความคลาดเคลื่อนเป็น %
    final beatDuration = 60.0 / song.bpm; // วินาทีต่อ beat
    final errorMs = ((actualTime - expectedNote.startTime) * 1000).abs();
    final errorPercent = (errorMs / (beatDuration * 1000)) * 100;

    // ให้คะแนน
    JudgmentLevel level;
    if (errorPercent > 50) {
      level = JudgmentLevel.miss;    // พลาดมาก (เกินครึ่งช่วง)
    } else if (errorPercent > 25) {
      level = JudgmentLevel.good;    // พอใช้
    } else {
      level = JudgmentLevel.perfect; // ดีมาก
    }

    // เช็คว่าโน้ตตรงไหม
    if (!_checkNoteMatch(detectedNote, expectedNote.note)) {
      level = JudgmentLevel.miss; // โน้ตผิด → แดง
    }

    final judgment = Judgment(
      noteIndex: _currentNoteIndex,
      level: level,
      errorPercent: errorPercent,
      expectedNote: expectedNote.note,
      playedNote: detectedNote,
      expectedTime: expectedNote.startTime,
      actualTime: actualTime,
    );

    _judgments[_currentNoteIndex] = judgment;
    _currentNoteIndex++;

    onJudgment?.call(judgment);
  }

  bool _checkNoteMatch(String played, String expected) {
    // แปลงโน้ตเป็น semitone
    final expectedSemitone = _noteToSemitone(expected);
    final playedSemitone = _noteToSemitone(played);

    // ยอมรับโน้ตที่ห่างกัน ±2 semitones
    final difference = (playedSemitone - expectedSemitone).abs();
    return difference <= 2;
  }

  int _noteToSemitone(String note) {
    final noteNames = {
      'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5,
      'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11,
      'Db': 1, 'Eb': 3, 'Gb': 6, 'Ab': 8, 'Bb': 10,
    };

    final match = RegExp(r'([A-G][#b]?)(\d+)').firstMatch(note);
    if (match == null) return 0;

    final noteName = match.group(1)!;
    final octave = int.parse(match.group(2)!);

    final semitoneInOctave = noteNames[noteName] ?? 0;
    return octave * 12 + semitoneInOctave;
  }

  void reset() {
    _startTime = null;
    _currentNoteIndex = 0;
    _judgments.clear();
    _recordedNotes.clear();
  }

  // สถิติ
  Map<String, int> getStatistics() {
    int perfect = 0;
    int good = 0;
    int miss = 0;

    for (final judgment in _judgments.values) {
      switch (judgment.level) {
        case JudgmentLevel.perfect:
          perfect++;
          break;
        case JudgmentLevel.good:
          good++;
          break;
        case JudgmentLevel.miss:
          miss++;
          break;
      }
    }

    return {
      'perfect': perfect,
      'good': good,
      'miss': miss,
      'total': song.notes.length,
      'played': _judgments.length,
    };
  }

  double getAccuracy() {
    if (_judgments.isEmpty) return 0.0;

    final stats = getStatistics();
    final perfect = stats['perfect']!;
    final good = stats['good']!;
    final total = stats['played']!;

    // คะแนน: Perfect = 100%, Good = 50%, Miss = 0%
    return ((perfect * 100 + good * 50) / (total * 100)) * 100;
  }
}
