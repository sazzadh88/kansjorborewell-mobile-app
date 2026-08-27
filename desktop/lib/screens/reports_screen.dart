import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

import '../widgets/desk_page.dart';
import '../theme/desk_theme.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTimeRange? _range;
  bool _exporting = false;
  bool _refreshing = false;

  String _date(DateTime value) => value.toIso8601String().substring(0, 10);

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
    ref.invalidate(gstReportProvider);
    try {
      await ref.read(gstReportProvider((from: _query.from, to: _query.to)).future);
    } catch (_) {}
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _refreshing = false);
    }
  }

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
      helpText: 'Select up to 90 days',
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
            content: Text('Please select a date range first.')),
      );
      return;
    }
    final from = _date(_range!.start);
    final to = _date(_range!.end);
    final fileName = 'gst-report-$from-$to.csv';
    setState(() => _exporting = true);
    try {
      final csv =
          await ref.read(apiClientProvider).exportGstCsv(from: from, to: to);
      await ref.read(apiClientProvider).saveCsvToDownloads(fileName, csv);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded $fileName successfully.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gst = ref.watch(gstReportProvider((from: _query.from, to: _query.to)));
    return DeskPage(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: gst.when(skipLoadingOnReload: true, skipLoadingOnRefresh: true, 
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(apiErrorMessage(error))),
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GST report',
                          style: Theme.of(context).textTheme.displaySmall),
                      const SizedBox(height: 4),
                      Text(
                        _range == null
                            ? 'Taxable freight, GST, and totals grouped by party · this month'
                            : '${_date(_range!.start)} → ${_date(_range!.end)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: DeskColors.muted),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _refreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          tooltip: 'Refresh',
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh, size: 18),
                        ),
                  const SizedBox(width: 4),
                  OutlinedButton.icon(
                    onPressed: _pickRange,
                    icon: const Icon(Icons.date_range, size: 16),
                    label: Text(_range == null
                        ? 'Filter period'
                        : '${_date(_range!.start)} → ${_date(_range!.end)}'),
                  ),
                  if (_range != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Clear filter',
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _range = null),
                    ),
                  ],
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _exporting ? null : _exportGstCsv,
                    icon: _exporting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download, size: 16),
                    label: const Text('Export GST format'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _Stat('Taxable', '₹ ${data.taxableAmount}'),
                      _Stat('GST', '₹ ${data.gstAmount}'),
                      _Stat('Total', '₹ ${data.totalAmount}', highlight: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Party breakdown', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Expanded(
                child: Card(
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Party')),
                        DataColumn(label: Text('Loads'), numeric: true),
                        DataColumn(label: Text('Taxable'), numeric: true),
                        DataColumn(label: Text('GST'), numeric: true),
                        DataColumn(label: Text('Total'), numeric: true),
                      ],
                      rows: data.rows.map((row) {
                        return DataRow(cells: [
                          DataCell(Text(row.party)),
                          DataCell(Text('${row.dispatches}')),
                          DataCell(Text('₹ ${row.taxableAmount}')),
                          DataCell(Text('₹ ${row.gstAmount}')),
                          DataCell(Text('₹ ${row.totalAmount}')),
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
              color: highlight ? DeskColors.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}
