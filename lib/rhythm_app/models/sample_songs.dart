import 'song.dart';

class SampleSongs {
  // เพลงง่ายสำหรับ calibration - โน้ตเดียว 8 จังหวะ
  static Song get calibrationSong => Song(
    id: 'calibration',
    title: 'Calibration Exercise',
    bpm: 120,
    timeSignature: "4/4",
    notes: List.generate(8, (i) => NoteEvent(
      note: 'C4',
      startTime: i * 0.5, // quarter note = 0.5 วินาทีที่ 120 BPM
      duration: 0.5,
    )),
  );

  // Twinkle Twinkle Little Star - เพลงง่ายสำหรับฝึก
  static Song get twinkleTwinkle => Song(
    id: 'twinkle',
    title: 'Twinkle Twinkle Little Star',
    bpm: 120,
    timeSignature: "4/4",
    notes: [
      // Measure 1: C C G G
      NoteEvent(note: 'C4', startTime: 0.0, duration: 0.5),
      NoteEvent(note: 'C4', startTime: 0.5, duration: 0.5),
      NoteEvent(note: 'G4', startTime: 1.0, duration: 0.5),
      NoteEvent(note: 'G4', startTime: 1.5, duration: 0.5),

      // Measure 2: A A G
      NoteEvent(note: 'A4', startTime: 2.0, duration: 0.5),
      NoteEvent(note: 'A4', startTime: 2.5, duration: 0.5),
      NoteEvent(note: 'G4', startTime: 3.0, duration: 1.0),

      // Measure 3: F F E E
      NoteEvent(note: 'F4', startTime: 4.0, duration: 0.5),
      NoteEvent(note: 'F4', startTime: 4.5, duration: 0.5),
      NoteEvent(note: 'E4', startTime: 5.0, duration: 0.5),
      NoteEvent(note: 'E4', startTime: 5.5, duration: 0.5),

      // Measure 4: D D C
      NoteEvent(note: 'D4', startTime: 6.0, duration: 0.5),
      NoteEvent(note: 'D4', startTime: 6.5, duration: 0.5),
      NoteEvent(note: 'C4', startTime: 7.0, duration: 1.0),
    ],
  );

  // เพลงทดสอบสั้นมาก - 4 โน้ตตัวดำ (1 ห้อง)
  static Song get verySimpleTest => Song(
    id: 'very_simple',
    title: 'Very Simple - 4 Notes',
    bpm: 120,
    timeSignature: "4/4",
    notes: [
      NoteEvent(note: 'C4', startTime: 0.0, duration: 0.5),
      NoteEvent(note: 'D4', startTime: 0.5, duration: 0.5),
      NoteEvent(note: 'E4', startTime: 1.0, duration: 0.5),
      NoteEvent(note: 'C4', startTime: 1.5, duration: 0.5),
    ],
  );

  // เพลงทดสอบง่ายๆ - 8 โน้ตตัวดำ (2 ห้อง)
  static Song get simpleTest => Song(
    id: 'simple_test',
    title: 'Simple Test - 8 Notes',
    bpm: 120,
    timeSignature: "4/4",
    notes: [
      // ห้องที่ 1: C D E F
      NoteEvent(note: 'C4', startTime: 0.0, duration: 0.5),
      NoteEvent(note: 'D4', startTime: 0.5, duration: 0.5),
      NoteEvent(note: 'E4', startTime: 1.0, duration: 0.5),
      NoteEvent(note: 'F4', startTime: 1.5, duration: 0.5),

      // ห้องที่ 2: G A B C5
      NoteEvent(note: 'G4', startTime: 2.0, duration: 0.5),
      NoteEvent(note: 'A4', startTime: 2.5, duration: 0.5),
      NoteEvent(note: 'B4', startTime: 3.0, duration: 0.5),
      NoteEvent(note: 'C5', startTime: 3.5, duration: 0.5),
    ],
  );

  static List<Song> get allSongs => [
    verySimpleTest,
    simpleTest,
    twinkleTwinkle,
  ];
}
