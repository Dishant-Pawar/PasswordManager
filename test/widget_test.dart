// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passwordmaster/main.dart';

void main() {
  testWidgets('SecureVaultApp smoke test', (WidgetTester tester) async {
    // Set screen size to prevent RenderFlex overflow
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;

    // Build our app and trigger a frame.
    await tester.pumpWidget(const SecureVaultApp());

    // Verify that our app shows title.
    expect(find.text('SecureVault'), findsOneWidget);

    // Let the splash screen timer run and resolve navigation
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Reset view settings
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
