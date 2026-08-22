import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';

import '../theme/desk_theme.dart';
import 'nav_items.dart';

final sidebarCollapsedProvider = NotifierProvider<SidebarNotifier, bool>(
  SidebarNotifier.new,
);

class SidebarNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

class AppShell extends ConsumerWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collapsed = ref.watch(sidebarCollapsedProvider);
    final user = ref.watch(authProvider).value;
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: collapsed ? 64 : 220,
            color: const Color(0xFF1F2937),
            child: Column(
              children: [
                SizedBox(
                  height: 56,
                  child: Center(
                    child: collapsed
                        ? const Icon(Icons.inventory_2_rounded, color: Colors.white)
                        : const Text(
                            'KANSJOR',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      for (final item in navItems)
                        if (item.allowedFor(user))
                          _NavTile(
                            item: item,
                            collapsed: collapsed,
                            selected: location.startsWith(item.path),
                          ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                IconButton(
                  tooltip: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
                  onPressed: () => ref.read(sidebarCollapsedProvider.notifier).toggle(),
                  icon: Icon(
                    collapsed ? Icons.menu_open_rounded : Icons.menu_rounded,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.collapsed,
    required this.selected,
  });

  final NavItem item;
  final bool collapsed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected
            ? DeskColors.primary.withValues(alpha: 0.25)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => context.go(item.path),
          child: SizedBox(
            height: 40,
            child: Row(
              mainAxisAlignment:
                  collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                if (!collapsed) const SizedBox(width: 12),
                Icon(
                  item.icon,
                  size: 20,
                  color: selected ? Colors.white : Colors.white60,
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
