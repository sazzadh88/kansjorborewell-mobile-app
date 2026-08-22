import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

import '../widgets/desk_page.dart';
import '../widgets/metric_tile.dart';
import '../theme/desk_theme.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardProvider);
    final user = ref.watch(authProvider).value;
    final showProduction = user?.hasPermission('production.view') ?? false;
    final showDispatch = user?.hasPermission('dispatch.view') ?? false;
    final showProducts = user?.hasPermission('products.view') ?? false;
    return DeskPage(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: summary.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text(apiErrorMessage(error)),
          ),
          data: (data) => ListView(
            children: [
              Text(
                'Operations overview',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Factory snapshot for ${data.date}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: DeskColors.muted),
              ),
              if (showProduction || showDispatch || showProducts) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (showProduction)
                      Expanded(
                        child: MetricTile(
                          label: 'Today production',
                          value: '${data.productionQty} pcs',
                          icon: Icons.precision_manufacturing_outlined,
                          color: DeskColors.primary,
                        ),
                      ),
                    if (showProduction && showDispatch)
                      const SizedBox(width: 12),
                    if (showDispatch)
                      Expanded(
                        child: MetricTile(
                          label: 'Today dispatched',
                          value: '${data.saleQty} pcs',
                          icon: Icons.local_shipping_outlined,
                          color: DeskColors.dispatched,
                        ),
                      ),
                    if ((showProduction || showDispatch) && showProducts)
                      const SizedBox(width: 12),
                    if (showProducts)
                      Expanded(
                        child: MetricTile(
                          label: 'Active brick types',
                          value: '${data.brickTypes.length}',
                          icon: Icons.view_module_outlined,
                          color: DeskColors.settled,
                        ),
                      ),
                  ],
                ),
              ],
              if (showProducts) ...[
                const SizedBox(height: 20),
                Text(
                  'Brick type stock',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Product')),
                      DataColumn(label: Text('Code')),
                      DataColumn(label: Text('Current stock'), numeric: true),
                      DataColumn(label: Text('Reorder level'), numeric: true),
                      DataColumn(label: Text('Status')),
                    ],
                    rows: data.brickTypes.map((brick) {
                      final low = brick.currentStock <= brick.reorderLevel;
                      return DataRow(cells: [
                        DataCell(Text(brick.name)),
                        DataCell(Text(brick.code)),
                        DataCell(Text('${brick.currentStock}')),
                        DataCell(Text('${brick.reorderLevel}')),
                        DataCell(
                          Text(
                            low ? 'Low stock' : 'Healthy',
                            style: TextStyle(
                              color: low ? DeskColors.low : DeskColors.settled,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
