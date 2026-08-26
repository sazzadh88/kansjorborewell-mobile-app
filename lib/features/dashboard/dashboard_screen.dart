import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_widgets.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardProvider);
    final user = ref.watch(authProvider).value;
    final trimmedName = user?.name.trim() ?? '';
    final firstName = trimmedName.isNotEmpty
        ? trimmedName.split(RegExp(r'\s+')).first
        : 'team';
    final initial = trimmedName.isNotEmpty
        ? trimmedName.substring(0, 1).toUpperCase()
        : 'K';

    return FactoryShell(
      currentIndex: 0,
      title: 'Overview',
      action: IconButton(
        tooltip: 'Refresh dashboard',
        onPressed: () => ref.invalidate(dashboardProvider),
        icon: const Icon(Icons.sync_rounded),
      ),
      child: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: () async {
            ref.invalidate(dashboardProvider);
            await ref.read(dashboardProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: .14),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Good day, $firstName',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Factory control room',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.accent,
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    summary.when(
                      data: (data) => Row(
                        children: [
                          const Icon(
                            Icons.today_outlined,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            data.date.isNotEmpty ? data.date : 'Today',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          StatusBadge(
                            label: '${data.brickTypes.length} brick types',
                          ),
                        ],
                      ),
                      loading: () => const Row(
                        children: [
                          Icon(
                            Icons.today_outlined,
                            color: Colors.white70,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Loading overview...',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      error: (_, __) => const Row(
                        children: [
                          Icon(
                            Icons.today_outlined,
                            color: Colors.white70,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Offline',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              summary.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, _) => ErrorState(
                  message: apiErrorMessage(error),
                  onRetry: () => ref.invalidate(dashboardProvider),
                ),
                data: (data) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (user?.hasPermission('production.view') == true ||
                        user?.hasPermission('dispatch.view') == true) ...[
                      const SectionHeading(title: 'Today at a glance'),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 148,
                        child: Row(
                          children: [
                            if (user?.hasPermission('production.view') == true)
                              Expanded(
                                child: MetricCard(
                                  label: 'Production',
                                  value: '${data.productionQty}',
                                  icon: Icons.precision_manufacturing_outlined,
                                ),
                              ),
                            if (user?.hasPermission('production.view') ==
                                    true &&
                                user?.hasPermission('dispatch.view') == true)
                              const SizedBox(width: 12),
                            if (user?.hasPermission('dispatch.view') == true)
                              Expanded(
                                child: MetricCard(
                                  label: 'Dispatched',
                                  value: '${data.saleQty}',
                                  icon: Icons.local_shipping_outlined,
                                  tint: const Color(0xFFE7EEF9),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                    ],
                    if (user?.hasPermission('products.view') == true) ...[
                      SectionHeading(
                        title: 'Finished stock',
                        action: Text(
                          '${data.brickTypes.length} types',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (user?.hasPermission('products.view') == true) ...[
                      if (data.brickTypes.isEmpty)
                        const AppCard(
                          child: EmptyState(
                            title: 'No stock records',
                            message:
                                'Brick stock will appear here once master data is available.',
                          ),
                        )
                      else
                        ...data.brickTypes.map((brick) {
                          final low = brick.currentStock <= brick.reorderLevel;
                          final target = brick.reorderLevel > 0
                              ? brick.reorderLevel * 4
                              : 100;
                          final rawRatio = target <= 0
                              ? 1.0
                              : (brick.currentStock / target);
                          final ratio = rawRatio.isNaN || rawRatio.isInfinite
                              ? 0.05
                              : rawRatio.clamp(0.05, 1.0);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AppCard(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                15,
                                16,
                                14,
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: low
                                              ? AppColors.warningTint
                                              : AppColors.accentTint,
                                          borderRadius: BorderRadius.circular(
                                            11,
                                          ),
                                        ),
                                        child: Icon(
                                          low
                                              ? Icons.warning_amber_rounded
                                              : Icons.inventory_2_outlined,
                                          color: low
                                              ? AppColors.warning
                                              : AppColors.accentDark,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              brick.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              brick.code,
                                              style: const TextStyle(
                                                color: AppColors.muted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${brick.currentStock}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                  fontFeatures: const [
                                                    FontFeature.tabularFigures(),
                                                  ],
                                                ),
                                          ),
                                          Text(
                                            'pieces',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium
                                                ?.copyWith(
                                                  color: AppColors.muted,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(99),
                                    child: LinearProgressIndicator(
                                      value: ratio,
                                      minHeight: 7,
                                      backgroundColor: AppColors.canvas,
                                      color: low
                                          ? AppColors.warning
                                          : AppColors.accent,
                                    ),
                                  ),
                                  if (low) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.info_outline,
                                          size: 14,
                                          color: AppColors.warning,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Below reorder level of ${brick.reorderLevel}',
                                          style: const TextStyle(
                                            color: AppColors.warning,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
