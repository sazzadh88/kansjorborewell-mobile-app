import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/splash_screen.dart';

void main() {
  testWidgets('Kansjor Borewell app renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SplashScreen())),
    );
    await tester.pump();

    expect(find.text('Kansjor Borewell'), findsOneWidget);
  });
}
