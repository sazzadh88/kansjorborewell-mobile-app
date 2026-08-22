import 'package:flutter/material.dart';

import '../navigation/app_shell.dart';
import '../navigation/top_bar.dart';

class DeskPage extends StatelessWidget {
  const DeskPage({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: Column(
        children: [
          const TopBar(),
          Expanded(child: child),
        ],
      ),
    );
  }
}
