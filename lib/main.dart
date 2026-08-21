import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: KansjorBorewellApp()));
}

class KansjorBorewellApp extends ConsumerWidget {
  const KansjorBorewellApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Kansjor Borewell',
    theme: buildAppTheme(),
    routerConfig: ref.watch(routerProvider),
  );
}
