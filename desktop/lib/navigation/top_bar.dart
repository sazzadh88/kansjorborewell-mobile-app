import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';

import 'shortcuts.dart';

class TopBar extends ConsumerWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE1E4E9)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          SizedBox(
            width: 240,
            child: TextField(
              focusNode: searchFocusNode,
              decoration: const InputDecoration(
                hintText: 'Search records...  (Ctrl+F)',
                border: InputBorder.none,
                filled: false,
                isDense: true,
              ),
            ),
          ),
          const Spacer(),
          if (user != null)
            _RoleBadge(role: user.role),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded, size: 20),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: 'Profile',
            onSelected: (value) {
              if (value == 'logout') {
                ref.read(authProvider.notifier).logout();
                context.go('/login');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'logout', child: Text('Sign out')),
            ],
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                (user?.name.isNotEmpty ?? false)
                    ? user!.name.substring(0, 1).toUpperCase()
                    : 'U',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
