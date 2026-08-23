import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:window_manager/window_manager.dart';

import 'core/api_client.dart';
import 'navigation/shortcuts.dart';
import 'router.dart';
import 'theme/desk_theme.dart';
import 'theme/font_scale_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux)) {
    try {
      await windowManager.ensureInitialized();
      const windowOptions = WindowOptions(
        size: Size(1440, 900),
        minimumSize: Size(1024, 700),
        center: true,
        title: 'Kansjor Borewell — Back Office',
      );
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (_) {
      // Window manager not available in test or unsupported environment
    }
  }

  final apiClient = await buildTrustedDesktopApiClient();

  runApp(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
      ],
      child: const DeskApp(),
    ),
  );
}

class DeskApp extends ConsumerWidget {
  const DeskApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontScale = ref.watch(fontScaleProvider);

    return DesktopShortcuts(
      child: MaterialApp.router(
        title: 'Kansjor Borewell — Back Office',
        theme: DeskTheme.light().copyWith(
          textTheme: DeskTheme.light().textTheme.apply(
            fontSizeFactor: fontScale,
          ),
        ),
        routerConfig: ref.watch(routerProvider),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
