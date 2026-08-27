import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

import '../widgets/desk_page.dart';
import '../theme/desk_theme.dart';

class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen({super.key});

  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: Card(child: Padding(padding: EdgeInsets.all(24), child: Row(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(width: 16), Text('Loading...')])))),
      );
    }
    ref.invalidate(dispatchDuesProvider);
    try {
      await ref.read(dispatchDuesProvider.future);
    } catch (_) {}
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dues = ref.watch(dispatchDuesProvider);
    return DeskPage(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: dues.when(skipLoadingOnReload: true, skipLoadingOnRefresh: true, 
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(apiErrorMessage(error))),
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Stock & dispatch ledger', style: Theme.of(context).textTheme.displaySmall),
                        const SizedBox(height: 4),
                        Text(
                          'Reconciliation view across parties and dues',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: DeskColors.muted),
                        ),
                      ],
                    ),
                  ),
                  _refreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          tooltip: 'Refresh',
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh),
                        ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _Stat('Total freight', '₹ ${data.freightAmount}'),
                      _Stat('Total paid', '₹ ${data.paidAmount}'),
                      _Stat('Final due', '₹ ${data.dueAmount}', highlight: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Party-wise dues', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Expanded(
                child: Card(
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Party')),
                        DataColumn(label: Text('Loads'), numeric: true),
                        DataColumn(label: Text('Freight'), numeric: true),
                        DataColumn(label: Text('Paid'), numeric: true),
                        DataColumn(label: Text('Due'), numeric: true),
                      ],
                      rows: data.parties.map((row) {
                        return DataRow(cells: [
                          DataCell(Text(row.party)),
                          DataCell(Text('${row.dispatches}')),
                          DataCell(Text('₹ ${row.freightAmount}')),
                          DataCell(Text('₹ ${row.paidAmount}')),
                          DataCell(
                            Text(
                              '₹ ${row.dueAmount}',
                              style: TextStyle(
                                color: row.dueAmount > 0 ? DeskColors.low : DeskColors.settled,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: DeskColors.muted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: highlight ? DeskColors.low : null,
            ),
          ),
        ],
      ),
    );
  }
}
