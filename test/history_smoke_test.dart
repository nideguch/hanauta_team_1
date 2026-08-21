import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanalog_app/features/history/history_screen.dart';

void main() {
  testWidgets('オープニングが章送りできる', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('130年前'), findsOneWidget);

    for (var i = 0; i < 7; i++) {
      await tester.tap(find.byType(HistoryScreen));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('HANALOG'), findsOneWidget);
    expect(find.text('一 分 を は じ め る'), findsOneWidget);
  });
}
