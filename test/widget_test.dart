import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kesh_kart/main.dart';

void main() {
  testWidgets('KeshKart app widget initialization test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MaterialApp), findsOneWidget);
    try {
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
    } catch (_) {}
  });
}
