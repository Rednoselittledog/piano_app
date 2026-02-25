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
  DateTime? _metronomeStartTime; // เวลาที่ metronome เริ่ม
  int _currentNoteIndex = 0;
  final Map<int, Judgment> _judgments = {};
  final List<RecordedNote> _recordedNotes = [];
  final List<DateTime> _beatTimes = []; // เก็บเวลาทุก beat
  bool _hasStarted = false; // เริ่มนับหรือยัง

  // Same Note Debouncing
  String? _lastDetectedNote;
  DateTime? _lastDetectedTime;

  // Onset-based note detection
  String? _lastAcceptedNote;
  DateTime? _lastAcceptedTime;

  // Callback
  Function(Judgment judgment)? onJudgment;

  RhythmJudgeService({
    required this.song,
    required this.delayOffset,
  });

  // เรียกเมื่อ metronome beat
  void onMetronomeBeat(int beatNumber) {
    final now = DateTime.now();
    _beatTimes.add(now);
    if (_metronomeStartTime == null) {
      _metronomeStartTime = now;
    }
    print('🎵 [JUDGE] Beat #$beatNumber at ${now.millisecondsSinceEpoch}');
  }

  Map<int, Judgment> get judgments => Map.unmodifiable(_judgments);
  List<RecordedNote> get recordedNotes => List.unmodifiable(_recordedNotes);
  int get currentNoteIndex => _currentNoteIndex;
  bool get isComplete => _currentNoteIndex >= song.notes.length;

  /// เรียกเมื่อ onset detection ตรวจจับโน้ตใหม่
  /// ใช้แทน onNoteDetected เพื่อป้องกันเสียงค้างจากโน้ตก่อนหน้า
  void onNoteOnset(String detectedNote, DateTime onsetTime) {
    print('💥 [JUDGE-ONSET] Note onset: $detectedNote (current index: $_currentNoteIndex/${song.notes.length})');
    _processNote(detectedNote, onsetTime, isOnset: true);
  }

  /// เรียกเมื่อ pitch detection ตรวจจับโน้ต (sustained)
  /// ใช้สำหรับ fallback เมื่อไม่มี onset
  void onNoteDetected(String detectedNote, DateTime detectedTime) {
    print('🎹 [JUDGE] Note detected: $detectedNote (current index: $_currentNoteIndex/${song.notes.length}, started: $_hasStarted)');
    _processNote(detectedNote, detectedTime, isOnset: false);
  }

  /// ประมวลผลโน้ตที่ตรวจจับได้
  void _processNote(String detectedNote, DateTime detectedTime, {required bool isOnset}) {
    // ถ้าเล่นจบแล้ว ไม่ต้องให้คะแนน
    if (_currentNoteIndex >= song.notes.length) return;

    final expectedNote = song.notes[_currentNoteIndex];

    // ถ้าเป็น onset → ยอมรับทันที (ข้าม debouncing)
    // ถ้าไม่ใช่ onset → ต้องผ่าน Same Note Debouncing
    if (!isOnset) {
      if (_lastDetectedNote == detectedNote && _lastDetectedTime != null) {
        final windowMs = _getDebounceWindow(expectedNote);
        final elapsedMs = detectedTime.difference(_lastDetectedTime!).inMilliseconds;

        if (elapsedMs < windowMs) {
          print('⚠️ [DEBOUNCE] Ignoring duplicate $detectedNote (${elapsedMs}ms < ${windowMs}ms window)');
          return;
        }
      }

      // ป้องกันเสียงค้าง: ถ้าโน้ตที่คาดหวังต่างจากโน้ตที่ยอมรับล่าสุด
      // แต่ detect ได้โน้ตเดียวกับโน้ตที่ยอมรับล่าสุด → ปฏิเสธ (เสียงค้าง)
      if (_lastAcceptedNote != null && _lastAcceptedTime != null) {
        final timeSinceLastAccepted = detectedTime.difference(_lastAcceptedTime!).inMilliseconds;

        if (expectedNote.note != _lastAcceptedNote &&
            detectedNote == _lastAcceptedNote &&
            timeSinceLastAccepted < 1000) {
          print('⚠️ [SUSTAIN-REJECT] Ignoring sustained $detectedNote (expected: ${expectedNote.note}, last accepted: $_lastAcceptedNote, ${timeSinceLastAccepted}ms ago)');
          return;
        }
      }
    }

    // ถ้ายังไม่เริ่ม -> เช็คว่าตรงกับโน้ตแรกหรือไม่
    if (!_hasStarted) {
      // เช็คว่าตรงกับโน้ตแรกในเพลงหรือไม่ (±2 semitones)
      if (_checkNoteMatch(detectedNote, expectedNote.note)) {
        _hasStarted = true;
        _startTime = detectedTime;

        // ทิ้ง beat times ก่อนโน้ตแรก และเริ่มใหม่จาก beat ที่ใกล้ที่สุด
        final nearestBeatIndex = _beatTimes.lastIndexWhere((beat) => beat.isBefore(detectedTime));
        if (nearestBeatIndex >= 0) {
          _metronomeStartTime = _beatTimes[nearestBeatIndex];
          _beatTimes.removeRange(0, nearestBeatIndex);
          print('✅ [JUDGE] First note matched! Starting from nearest beat at ${_metronomeStartTime!.millisecondsSinceEpoch}');
        } else {
          _metronomeStartTime = _beatTimes.isNotEmpty ? _beatTimes.first : detectedTime;
          print('✅ [JUDGE] First note matched! No beat before note, using first beat');
        }

        print('✅ [JUDGE] Note: $detectedNote (expected: ${expectedNote.note})');
        // ไม่ return เพื่อให้ประเมินโน้ตแรกด้วย
      } else {
        print('⚠️ [JUDGE] Waiting for first note (expected: ${expectedNote.note}, got: $detectedNote)');
        return; // รอโน้ตแรกที่ถูก
      }
    }

    // บันทึกโน้ตที่กด
    if (_startTime == null) {
      _startTime = detectedTime;
      _recordedNotes.add(RecordedNote(note: detectedNote, timestamp: 0.0));
    } else {
      final elapsed = detectedTime.difference(_startTime!).inMilliseconds / 1000.0;
      _recordedNotes.add(RecordedNote(note: detectedNote, timestamp: elapsed));
    }

    // คำนวณเวลาที่คาดหวัง (จากโน้ตในเพลง)
    final expectedTime = expectedNote.startTime;

    // หา beat ที่ใกล้ที่สุดกับเวลาที่คาดหวัง
    DateTime? targetBeat;
    if (_metronomeStartTime != null) {
      final beatDuration = 60.0 / song.bpm; // วินาทีต่อ beat
      final expectedBeatNumber = (expectedTime / beatDuration).round();
      final targetBeatTime = _metronomeStartTime!.add(Duration(milliseconds: (expectedBeatNumber * beatDuration * 1000).round()));

      // หา beat ที่ใกล้ที่สุดกับ targetBeatTime
      for (final beatTime in _beatTimes) {
        if ((beatTime.difference(targetBeatTime).inMilliseconds.abs()) < 100) {
          targetBeat = beatTime;
          break;
        }
      }
    }

    // ถ้าหา beat ไม่เจอ -> ใช้วิธีเดิม (อ้างอิงจาก _startTime)
    double actualTime;
    if (targetBeat != null) {
      // วัด delay จาก beat ที่ใกล้ที่สุด
      final delayFromBeat = detectedTime.difference(targetBeat).inMilliseconds - delayOffset;
      actualTime = expectedTime + (delayFromBeat / 1000.0);
      print('⏱️ [JUDGE] Using metronome beat: delay=${delayFromBeat}ms from beat at ${targetBeat.millisecondsSinceEpoch}');
    } else {
      // ใช้วิธีเดิม (fallback)
      final elapsedMs = detectedTime.difference(_startTime!).inMilliseconds - delayOffset;
      actualTime = elapsedMs / 1000.0;
      print('⚠️ [JUDGE] No metronome beat found, using startTime reference');
    }

    // คำนวณความคลาดเคลื่อนเป็น %
    final beatDuration = 60.0 / song.bpm; // วินาทีต่อ beat
    final errorMs = ((actualTime - expectedTime) * 1000).abs();
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
      expectedTime: expectedTime,
      actualTime: actualTime,
    );

    _judgments[_currentNoteIndex] = judgment;
    _currentNoteIndex++;

    // อัพเดท tracking
    _lastDetectedNote = detectedNote;
    _lastDetectedTime = detectedTime;
    _lastAcceptedNote = detectedNote;
    _lastAcceptedTime = detectedTime;

    print('✅ [JUDGE] Judgment: ${judgment.level} (error: ${errorPercent.toStringAsFixed(1)}%)');
    onJudgment?.call(judgment);
  }

  /// คำนวณ debounce window จาก note duration
  /// ใช้ 80% ของ note duration เพื่อบล็อกโน้ตซ้ำ
  int _getDebounceWindow(NoteEvent note) {
    final beatDuration = 60.0 / song.bpm; // วินาทีต่อ beat
    final noteDuration = note.duration * beatDuration; // วินาทีของโน้ตนี้
    final windowSeconds = noteDuration * 0.8; // ใช้ 80% ของ note duration
    return (windowSeconds * 1000).round(); // แปลงเป็น milliseconds
  }

  bool _checkNoteMatch(String played, String expected) {
    // แปลงโน้ตเป็น semitone
    final expectedSemitone = _noteToSemitone(expected);
    final playedSemitone = _noteToSemitone(played);

    // ยอมรับโน้ตที่ห่างกัน ±1 semitone
    // เปลี่ยนจาก ±2 semitones เป็น ±1 เพื่อป้องกันเสียงค้างจากโน้ตก่อนหน้า
    final difference = (playedSemitone - expectedSemitone).abs();
    return difference <= 1;
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
    _metronomeStartTime = null;
    _currentNoteIndex = 0;
    _judgments.clear();
    _recordedNotes.clear();
    _beatTimes.clear();
    _hasStarted = false;
    _lastDetectedNote = null;
    _lastDetectedTime = null;
    _lastAcceptedNote = null;
    _lastAcceptedTime = null;
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
