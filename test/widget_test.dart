import 'package:flutter_test/flutter_test.dart';
import 'package:tewapp/rhythm_app/rhythm_app.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RhythmApp());

    // Verify that the home screen loads
    expect(find.text('Piano Rhythm Trainer'), findsOneWidget);
    expect(find.text('Calibrate Delay'), findsOneWidget);
    expect(find.text('Practice Song'), findsOneWidget);
  });
}
