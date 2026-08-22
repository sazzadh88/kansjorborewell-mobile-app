import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.borderColor,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Card(
    color: color,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: borderColor ?? AppColors.border),
    ),
    child: Padding(padding: padding, child: child),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({required this.title, this.action, super.key});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      if (action != null) action!,
    ],
  );
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.tint = AppColors.accentTint,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.accentDark, size: 21),
            ),
            const Icon(
              Icons.arrow_outward_rounded,
              color: AppColors.muted,
              size: 16,
            ),
          ],
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: AppColors.muted),
        ),
      ],
    ),
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.label, this.warning = false, super.key});

  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: warning ? AppColors.warningTint : AppColors.accentTint,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: warning ? AppColors.warning : AppColors.success,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class FormSection extends StatelessWidget {
  const FormSection({
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 18),
        child,
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({required this.title, required this.message, super.key});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.accentTint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.inbox_outlined,
              size: 30,
              color: AppColors.accentDark,
            ),
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

class ErrorState extends StatelessWidget {
  const ErrorState({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.dangerTint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.cloud_off_outlined,
              size: 30,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

class MasterPickerLoading extends StatelessWidget {
  const MasterPickerLoading({
    required this.label,
    required this.icon,
    super.key,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    decoration: BoxDecoration(
      color: AppColors.paperWarm,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        Icon(icon, color: AppColors.accentDark),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Loading $label',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ],
    ),
  );
}

class FactoryShell extends ConsumerWidget {
  const FactoryShell({
    required this.currentIndex,
    required this.child,
    required this.title,
    this.action,
    super.key,
  });

  final int currentIndex;
  final Widget child;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final showProduction = user?.hasPermission('production.view') ?? false;
    final showDispatch = user?.hasPermission('dispatch.view') ?? false;
    final showInventory = user?.hasPermission('inventory.view') ?? false;
    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.grid_view_outlined),
        selectedIcon: Icon(Icons.grid_view_rounded),
        label: 'Overview',
      ),
      if (showProduction)
        const NavigationDestination(
          icon: Icon(Icons.precision_manufacturing_outlined),
          selectedIcon: Icon(Icons.precision_manufacturing),
          label: 'Production',
        ),
      if (showDispatch)
        const NavigationDestination(
          icon: Icon(Icons.local_shipping_outlined),
          selectedIcon: Icon(Icons.local_shipping),
          label: 'Dispatch',
        ),
      if (showInventory)
        const NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2),
          label: 'Inventory',
        ),
      const NavigationDestination(
        icon: Icon(Icons.account_circle_outlined),
        selectedIcon: Icon(Icons.account_circle),
        label: 'Profile',
      ),
    ];
    final paths = <String>[
      '/dashboard',
      if (showProduction) '/production',
      if (showDispatch) '/dispatch',
      if (showInventory) '/inventory',
      '/profile',
    ];
    int safeIndex = 0;
    if (currentIndex == 0) {
      safeIndex = 0;
    } else if (currentIndex == 1) {
      safeIndex = showProduction ? paths.indexOf('/production') : 0;
    } else if (currentIndex == 2) {
      safeIndex = showDispatch ? paths.indexOf('/dispatch') : 0;
    } else if (currentIndex == 4) {
      safeIndex = showInventory ? paths.indexOf('/inventory') : 0;
    } else if (currentIndex == 3) {
      safeIndex = paths.indexOf('/profile');
    }
    if (safeIndex < 0 || safeIndex >= destinations.length) {
      safeIndex = 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: Theme.of(context).textTheme.titleLarge),
        actions: [if (action != null) action!, const SizedBox(width: 8)],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        destinations: destinations,
        onDestinationSelected: (index) => context.go(paths[index]),
      ),
    );
  }
}
