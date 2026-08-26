import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_widgets.dart';

class DispatchDuesScreen extends ConsumerWidget {
  const DispatchDuesScreen({super.key});

  String _money(double value) => value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dues = ref.watch(dispatchDuesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispatch dues'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(dispatchDuesProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dispatchDuesProvider);
          await ref.read(dispatchDuesProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Text(
              'Paid vs due',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 5),
            Text(
              'Total freight, paid, and final due across all dispatches.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            dues.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(36),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => ErrorState(
                message: 'Dues summary unavailable.',
                onRetry: () => ref.invalidate(dispatchDuesProvider),
              ),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TotalCard(data: data),
                  const SizedBox(height: 18),
                  const SectionHeading(title: 'Party-wise dues'),
                  const SizedBox(height: 12),
                  if (data.parties.isEmpty)
                    const AppCard(
                      child: EmptyState(
                        title: 'No dues',
                        message:
                            'Dispatch loads will appear here with their payment status.',
                      ),
                    )
                  else
                    ...data.parties.map(
                      (row) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      row.party,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${row.dispatches} loads',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _row('Freight', '₹ ${_money(row.freightAmount)}'),
                              _row('Paid', '₹ ${_money(row.paidAmount)}'),
                              const Divider(height: 20),
                              _row(
                                'Due',
                                '₹ ${_money(row.dueAmount)}',
                                bold: true,
                                due: row.dueAmount > 0,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool bold = false,
    bool due = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: due ? AppColors.warning : null,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            fontSize: bold ? 16 : 14,
          ),
        ),
      ],
    ),
  );
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.data});

  final DispatchDues data;

  @override
  Widget build(BuildContext context) => AppCard(
    color: AppColors.ink,
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FINAL DISPATCH DUES',
          style: TextStyle(
            color: Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total freight',
              style: TextStyle(color: Colors.white70),
            ),
            Text(
              '₹ ${data.freightAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Paid', style: TextStyle(color: Colors.white70)),
            Text(
              '₹ ${data.paidAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(color: Colors.white24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Final due',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '₹ ${data.dueAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.amberAccent,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
