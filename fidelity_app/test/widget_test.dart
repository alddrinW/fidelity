// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fidelity_app/main.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App initializes successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FidelityApp()));

    // Because AuthWrapper starts with a CircularProgressIndicator instead of LoginScreen
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
