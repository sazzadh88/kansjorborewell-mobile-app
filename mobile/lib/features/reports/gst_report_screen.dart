import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_widgets.dart';

class GstReportScreen extends ConsumerStatefulWidget {
  const GstReportScreen({super.key});

  @override
  ConsumerState<GstReportScreen> createState() => _GstReportScreenState();
}

class _GstReportScreenState extends ConsumerState<GstReportScreen> {
  DateTimeRange? _range;
  bool _exporting = false;

  String _date(DateTime value) => value.toIso8601String().substring(0, 10);

  String _money(double value) => value.toStringAsFixed(2);

  ({String? from, String? to}) get _query => (
    from: _range == null ? null : _date(_range!.start),
    to: _range == null ? null : _date(_range!.end),
  );

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      helpText: 'Select GST report range, up to 90 days',
    );
    if (picked == null) return;
    if (picked.end.difference(picked.start).inDays > 89) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a range of 90 days or less.')),
        );
      }
      return;
    }
    setState(() => _range = picked);
  }

  Future<void> _exportGstCsv() async {
    if (_range == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a date range first, then export.'),
        ),
      );
      await _pickRange();
      if (_range == null || !mounted) return;
    }
    final from = _date(_range!.start);
    final to = _date(_range!.end);
    final fileName = 'gst-report-$from-$to.csv';
    setState(() => _exporting = true);
    try {
      final csv = await ref
          .read(apiClientProvider)
          .exportGstCsv(from: from, to: to);
      await ref.read(apiClientProvider).saveCsvToDownloads(fileName, csv);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded $fileName successfully.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(gstReportProvider(_query));
    return Scaffold(
      appBar: AppBar(
        title: const Text('GST report'),
        actions: [
          IconButton(
            tooltip: 'Filter report range',
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range_outlined),
          ),
          IconButton(
            tooltip: 'Export GST format',
            onPressed: _exporting ? null : _exportGstCsv,
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
          ),
          IconButton(
            tooltip: 'Refresh report',
            onPressed: () => ref.invalidate(gstReportProvider(_query)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(gstReportProvider(_query));
          await ref.read(gstReportProvider(_query).future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Text(
              'GST on dispatches',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 5),
            Text(
              'Taxable freight, GST, and totals grouped by party.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            report.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(36),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => ErrorState(
                message: 'GST report unavailable.',
                onRetry: () => ref.invalidate(gstReportProvider(_query)),
              ),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TotalCard(
                    taxable: data.taxableAmount,
                    gst: data.gstAmount,
                    total: data.totalAmount,
                  ),
                  const SizedBox(height: 18),
                  const SectionHeading(title: 'Party breakdown'),
                  const SizedBox(height: 12),
                  if (data.rows.isEmpty)
                    const AppCard(
                      child: EmptyState(
                        title: 'No dispatches',
                        message:
                            'Dispatch transactions in the selected range will appear here.',
                      ),
                    )
                  else
                    ...data.rows.map(
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
                              _row('Taxable', '₹ ${_money(row.taxableAmount)}'),
                              _row(
                                'GST (${row.gstRate.toStringAsFixed(0)}%)',
                                '₹ ${_money(row.gstAmount)}',
                              ),
                              const Divider(height: 20),
                              _row(
                                'Total',
                                '₹ ${_money(row.totalAmount)}',
                                bold: true,
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

  Widget _row(String label, String value, {bool bold = false}) => Padding(
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
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            fontSize: bold ? 16 : 14,
          ),
        ),
      ],
    ),
  );
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.taxable,
    required this.gst,
    required this.total,
  });

  final double taxable;
  final double gst;
  final double total;

  @override
  Widget build(BuildContext context) => AppCard(
    color: AppColors.ink,
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TOTAL GST SUMMARY',
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
            const Text('Taxable', style: TextStyle(color: Colors.white70)),
            Text(
              '₹ ${taxable.toStringAsFixed(2)}',
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
            const Text('GST', style: TextStyle(color: Colors.white70)),
            Text(
              '₹ ${gst.toStringAsFixed(2)}',
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
              'Total',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '₹ ${total.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
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
