import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Desktop power-user shortcuts:
///   Ctrl+N — new production entry (placeholder route, wired to production list)
///   Ctrl+F — focus the global search field in the top bar
///
/// Global focus node for the search field in the top bar.
final searchFocusNode = FocusNode();

class DesktopShortcuts extends StatelessWidget {
  const DesktopShortcuts({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyN, control: true):
            NewProductionIntent(),
        SingleActivator(LogicalKeyboardKey.keyF, control: true):
            FocusSearchIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          NewProductionIntent: CallbackAction<NewProductionIntent>(
            onInvoke: (intent) {
              context.go('/production');
              return null;
            },
          ),
          FocusSearchIntent: CallbackAction<FocusSearchIntent>(
            onInvoke: (intent) {
              searchFocusNode.requestFocus();
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }
}

class NewProductionIntent extends Intent {
  const NewProductionIntent();
}

class FocusSearchIntent extends Intent {
  const FocusSearchIntent();
}
