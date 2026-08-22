import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kanjhor_desktop/theme/desk_theme.dart';

void main() {
  testWidgets('desk theme builds a compact light theme', (tester) async {
    final theme = DeskTheme.light();
    expect(theme.useMaterial3, isTrue);
    expect(theme.visualDensity, VisualDensity.compact);
  });

  testWidgets('desk theme builds a compact dark theme', (tester) async {
    final theme = DeskTheme.dark();
    expect(theme.brightness, Brightness.dark);
    expect(theme.visualDensity, VisualDensity.compact);
  });
}
