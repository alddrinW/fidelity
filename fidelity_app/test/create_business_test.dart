// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fidelity_app/features/business/create_business_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Navigation to CreateBusinessScreen smoke test', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: CreateBusinessScreen()),
      ),
    );

    // Verify CreateBusinessScreen builds with AppBar and stepper
    expect(find.byType(CreateBusinessScreen), findsOneWidget);
    expect(find.text('Siguiente'), findsOneWidget);
  });
}
