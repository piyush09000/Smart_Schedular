import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:timetable_app/main.dart';
import 'package:timetable_app/services/database_service.dart';

void main() {
  testWidgets('App loads', (WidgetTester tester) async {
    final db = DatabaseService();

    await tester.pumpWidget(MyApp(database: db));

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
