import 'song.dart';

class SampleSongs {
  // เพลงง่ายสำหรับ calibration - โน้ตเดียว 8 จังหวะ
  static Song get calibrationSong => Song(
    id: 'calibration',
    title: 'Calibration Exercise',
    bpm: 60,
    timeSignature: "4/4",
    notes: List.generate(8, (i) => NoteEvent(
      note: 'C4',
      startTime: i * 1.0, // quarter note = 1.0 วินาทีที่ 60 BPM
      duration: 1.0,
    )),
  );

  // Twinkle Twinkle Little Star - เพลงง่ายสำหรับฝึก
  static Song get twinkleTwinkle => Song(
    id: 'twinkle',
    title: 'Twinkle Twinkle Little Star',
    bpm: 60,
    timeSignature: "4/4",
    notes: [
      // Measure 1: C C G G
      NoteEvent(note: 'C4', startTime: 0.0, duration: 1.0),
      NoteEvent(note: 'C4', startTime: 1.0, duration: 1.0),
      NoteEvent(note: 'G4', startTime: 2.0, duration: 1.0),
      NoteEvent(note: 'G4', startTime: 3.0, duration: 1.0),

      // Measure 2: A A G
      NoteEvent(note: 'A4', startTime: 4.0, duration: 1.0),
      NoteEvent(note: 'A4', startTime: 5.0, duration: 1.0),
      NoteEvent(note: 'G4', startTime: 6.0, duration: 2.0),

      // Measure 3: F F E E
      NoteEvent(note: 'F4', startTime: 8.0, duration: 1.0),
      NoteEvent(note: 'F4', startTime: 9.0, duration: 1.0),
      NoteEvent(note: 'E4', startTime: 10.0, duration: 1.0),
      NoteEvent(note: 'E4', startTime: 11.0, duration: 1.0),

      // Measure 4: D D C
      NoteEvent(note: 'D4', startTime: 12.0, duration: 1.0),
      NoteEvent(note: 'D4', startTime: 13.0, duration: 1.0),
      NoteEvent(note: 'C4', startTime: 14.0, duration: 2.0),
    ],
  );

  // เพลงทดสอบสั้นมาก - 4 โน้ตตัวดำ (1 ห้อง)
  static Song get verySimpleTest => Song(
    id: 'very_simple',
    title: 'Very Simple - 4 Notes',
    bpm: 60,
    timeSignature: "4/4",
    notes: [
      NoteEvent(note: 'C4', startTime: 0.0, duration: 1.0),
      NoteEvent(note: 'D4', startTime: 1.0, duration: 1.0),
      NoteEvent(note: 'E4', startTime: 2.0, duration: 1.0),
      NoteEvent(note: 'C4', startTime: 3.0, duration: 1.0),
    ],
  );

  // เพลงทดสอบง่ายๆ - 8 โน้ตตัวดำ (2 ห้อง)
  static Song get simpleTest => Song(
    id: 'simple_test',
    title: 'Simple Test - 8 Notes',
    bpm: 60,
    timeSignature: "4/4",
    notes: [
      // ห้องที่ 1: C D E F
      NoteEvent(note: 'C4', startTime: 0.0, duration: 1.0),
      NoteEvent(note: 'D4', startTime: 1.0, duration: 1.0),
      NoteEvent(note: 'E4', startTime: 2.0, duration: 1.0),
      NoteEvent(note: 'F4', startTime: 3.0, duration: 1.0),

      // ห้องที่ 2: G A B C5
      NoteEvent(note: 'G4', startTime: 4.0, duration: 1.0),
      NoteEvent(note: 'A4', startTime: 5.0, duration: 1.0),
      NoteEvent(note: 'B4', startTime: 6.0, duration: 1.0),
      NoteEvent(note: 'C5', startTime: 7.0, duration: 1.0),
    ],
  );

  static List<Song> get allSongs => [
    verySimpleTest,
    simpleTest,
    twinkleTwinkle,
  ];
}
