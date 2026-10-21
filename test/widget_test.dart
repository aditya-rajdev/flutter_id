import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import 'package:id_card_studio_flutter/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  });

  testWidgets('ID Card Studio app launches', (WidgetTester tester) async {
    await tester.pumpWidget(const IDCardStudioApp());

    // Pump one frame instead of waiting for all animations to settle.
    await tester.pump();

    expect(find.byType(IDCardStudioApp), findsOneWidget);
  });
}
