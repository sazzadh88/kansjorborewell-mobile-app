import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_widgets.dart';

class InventoryReportScreen extends ConsumerStatefulWidget {
  const InventoryReportScreen({super.key});

  @override
  ConsumerState<InventoryReportScreen> createState() =>
      _InventoryReportScreenState();
}

class _InventoryReportScreenState extends ConsumerState<InventoryReportScreen> {
  DateTimeRange? _range;
  int _page = 1;

  String _date(DateTime value) => value.toIso8601String().substring(0, 10);

  String _humanDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${parsed.day.toString().padLeft(2, '0')} ${months[parsed.month - 1]} ${parsed.year}';
  }

  String _format(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  ({String? from, String? to, int page}) get _query => (
    from: _range == null ? null : _date(_range!.start),
    to: _range == null ? null : _date(_range!.end),
    page: _page,
  );

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      helpText: 'Select report range, up to 30 days',
    );
    if (picked == null) return;
    if (picked.end.difference(picked.start).inDays > 29) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a range of 30 days or less.')),
        );
      }
      return;
    }
    setState(() {
      _range = picked;
      _page = 1;
    });
  }

  Future<void> _export() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      helpText: 'Select export range, up to 30 days',
    );
    if (picked == null) return;
    if (picked.end.difference(picked.start).inDays > 29) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a range of 30 days or less.')),
        );
      }
      return;
    }
    final from = _date(picked.start);
    final to = _date(picked.end);
    try {
      final csv = await ref
          .read(apiClientProvider)
          .exportInventoryCsv(from: from, to: to);
      final path = await ref
          .read(apiClientProvider)
          .saveCsvToDownloads('inventory-$from-$to.csv', csv);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('CSV saved to $path')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(inventoryReportProvider(_query));
    final rangeLabel = _range == null
        ? 'All records'
        : '${_humanDate(_date(_range!.start))} → ${_humanDate(_date(_range!.end))}';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory report'),
        actions: [
          IconButton(
            tooltip: 'Filter report range',
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range_outlined),
          ),
          IconButton(
            tooltip: 'Export inventory report',
            onPressed: _export,
            icon: const Icon(Icons.file_download_outlined),
          ),
          IconButton(
            tooltip: 'Refresh report',
            onPressed: () => ref.invalidate(inventoryReportProvider(_query)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(inventoryReportProvider(_query));
            await ref.read(inventoryReportProvider(_query).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Stock movements',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  StatusBadge(label: rangeLabel),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                'Newest 20 stock movements by default.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              report.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(36),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, _) => ErrorState(
                  message: apiErrorMessage(error),
                  onRetry: () =>
                      ref.invalidate(inventoryReportProvider(_query)),
                ),
                data: (result) => Column(
                  children: [
                    if (result.items.isEmpty)
                      const AppCard(
                        child: EmptyState(
                          title: 'No movements yet',
                          message:
                              'Stock-in, stock-out, and production usage will appear here.',
                        ),
                      )
                    else
                      ...result.items.map(
                        (movement) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: movement.isOut
                                        ? AppColors.dangerTint
                                        : AppColors.accentTint,
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: Icon(
                                    movement.isOut
                                        ? Icons.arrow_downward_rounded
                                        : Icons.arrow_upward_rounded,
                                    color: movement.isOut
                                        ? AppColors.danger
                                        : AppColors.accentDark,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        movement.material,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${_humanDate(movement.date)} · ${movement.type.toUpperCase()}',
                                        style: const TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (movement.remarks != null &&
                                          movement.remarks!.isNotEmpty)
                                        Text(
                                          movement.remarks!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${movement.isOut ? '-' : '+'}${_format(movement.quantity)} ${movement.unit}',
                                  style: TextStyle(
                                    color: movement.isOut
                                        ? AppColors.danger
                                        : AppColors.success,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (result.lastPage > 1)
                      _PaginationBar(
                        currentPage: result.currentPage,
                        lastPage: result.lastPage,
                        onPrevious: result.currentPage > 1
                            ? () => setState(() => _page--)
                            : null,
                        onNext: result.currentPage < result.lastPage
                            ? () => setState(() => _page++)
                            : null,
                      ),
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

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.currentPage,
    required this.lastPage,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentPage;
  final int lastPage;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
      Text(
        '$currentPage / $lastPage',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
    ],
  );
}
