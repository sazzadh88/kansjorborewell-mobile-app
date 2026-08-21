import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_widgets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to access factory operations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final isAdmin = user?.role == 'admin';
    return FactoryShell(
      currentIndex: 3,
      title: 'Profile',
      action: IconButton(
        tooltip: 'Edit profile',
        onPressed: () => context.push('/profile/edit'),
        icon: const Icon(Icons.edit_outlined),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Text(
              'Your workspace',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 5),
            Text(
              'Account details and operational shortcuts.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 31,
                    backgroundColor: AppColors.accent,
                    child: Text(
                      user?.name.substring(0, 1).toUpperCase() ?? 'J',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Factory user',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          user?.mobile ?? '',
                          style: const TextStyle(color: Colors.white60),
                        ),
                        const SizedBox(height: 11),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            (user?.role ?? 'operator').toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (isAdmin || user?.role == 'manager') ...[
              const SectionHeading(title: 'Inventory'),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.inventory_2_outlined,
                title: 'Inventory',
                subtitle: 'Manage cement, sand, and production materials',
                onTap: () => context.push('/inventory'),
              ),
              const SizedBox(height: 18),
            ],
            if (isAdmin) ...[
              const SectionHeading(title: 'Administration'),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.groups_outlined,
                title: 'Staff',
                subtitle: 'Create, edit, and remove staff accounts',
                onTap: () => context.push('/admin/staff'),
              ),
              const SizedBox(height: 8),
            ],
            const SectionHeading(title: 'Dispatch masters'),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.storefront_outlined,
              title: 'Parties',
              subtitle: 'Manage receiving customers and parties',
              onTap: () => context.push('/masters/parties'),
            ),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.local_shipping_outlined,
              title: 'Vehicles',
              subtitle: 'Manage dispatch vehicles',
              onTap: () => context.push('/masters/vehicles'),
            ),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.badge_outlined,
              title: 'Drivers',
              subtitle: 'Manage driver records',
              onTap: () => context.push('/masters/drivers'),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => _confirmSignOut(context, ref),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accentTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.accentDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    ),
  );
}
