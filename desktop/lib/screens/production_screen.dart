import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

import '../widgets/desk_page.dart';
import '../theme/desk_theme.dart';

class ProductionScreen extends ConsumerStatefulWidget {
  const ProductionScreen({super.key});

  @override
  ConsumerState<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends ConsumerState<ProductionScreen> {
  DateTimeRange? _range;
  int _page = 1;
  int? _selectedId;

  bool get _canCreate =>
      ref.watch(authProvider).value?.hasPermission('production.create') ?? false;
  bool get _canEdit =>
      ref.watch(authProvider).value?.hasPermission('production.edit') ?? false;
  bool get _canDelete =>
      ref.watch(authProvider).value?.hasPermission('production.delete') ?? false;
  bool get _canExport =>
      ref.watch(authProvider).value?.hasPermission('production.export') ?? false;

  String _date(DateTime value) => value.toIso8601String().substring(0, 10);

  ({String? from, String? to, int page}) get query => (
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
      helpText: 'Select up to 30 days',
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
      _selectedId = null;
    });
  }

  Future<void> _exportCsv() async {
    if (_range == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date range first.')),
      );
      return;
    }
    final from = _date(_range!.start);
    final to = _date(_range!.end);
    final fileName = 'production-$from-$to.csv';
    try {
      final csv = await ref
          .read(apiClientProvider)
          .exportCsv('production-entries', from: from, to: to);
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
    }
  }

  Future<void> _openEntryDialog([ProductionRecord? record]) async {
    final machines = await ref.read(machinesProvider.future);
    final bricks = await ref.read(brickTypesProvider.future);
    final designs = await ref.read(designsProvider.future);

    if (!mounted) return;

    int? machineId = record?.machineId ?? machines.firstOrNull?.id;
    int? brickTypeId = record?.brickTypeId ?? bricks.firstOrNull?.id;
    int? designId = record?.designId;
    final qtyCtrl = TextEditingController(
      text: record != null ? '${record.quantity}' : '',
    );
    final remarksCtrl = TextEditingController(text: record?.remarks ?? '');
    DateTime date = record != null ? DateTime.parse(record.date) : DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final selectedBrick = bricks.where((b) => b.id == brickTypeId).firstOrNull;
          final isPaver = selectedBrick?.isPaver ?? false;

          return AlertDialog(
            title: Text(record == null ? 'Add Production Entry' : 'Edit Production Entry'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Date: ${_date(date)}'),
                      trailing: const Icon(Icons.calendar_today, size: 18),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => date = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: machineId,
                      decoration: const InputDecoration(labelText: 'Machine'),
                      items: machines
                          .map((m) => DropdownMenuItem(value: m.id, child: Text(m.name)))
                          .toList(),
                      onChanged: (val) => setDialogState(() => machineId = val),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: brickTypeId,
                      decoration: const InputDecoration(labelText: 'Brick Type / Product'),
                      items: bricks
                          .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name)))
                          .toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          brickTypeId = val;
                          final b = bricks.where((item) => item.id == val).firstOrNull;
                          if (b == null || !b.isPaver) designId = null;
                        });
                      },
                    ),
                    if (isPaver) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: designId,
                        decoration: const InputDecoration(labelText: 'Design (Paver)'),
                        items: [
                          const DropdownMenuItem<int>(value: null, child: Text('None / Default')),
                          ...designs.map(
                            (d) => DropdownMenuItem(value: d.id, child: Text(d.label)),
                          ),
                        ],
                        onChanged: (val) => setDialogState(() => designId = val),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity Produced',
                        hintText: 'e.g. 500',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: remarksCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Remarks (Optional)',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final qty = int.tryParse(qtyCtrl.text.trim());
                  if (machineId == null || brickTypeId == null || qty == null || qty <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Please fill valid machine, product, and quantity.')),
                    );
                    return;
                  }
                  final payload = {
                    'production_date': _date(date),
                    'machine_id': machineId,
                    'brick_type_id': brickTypeId,
                    if (designId != null) 'design_id': designId,
                    'quantity_produced': qty,
                    if (remarksCtrl.text.trim().isNotEmpty)
                      'remarks': remarksCtrl.text.trim(),
                  };
                  try {
                    final api = ref.read(apiClientProvider);
                    if (record == null) {
                      await api.createProduction(payload);
                    } else {
                      await api.updateProduction(record.id, payload);
                    }
                    if (dialogCtx.mounted) Navigator.pop(dialogCtx, true);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(apiErrorMessage(e))),
                      );
                    }
                  }
                },
                child: Text(record == null ? 'Create' : 'Save'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true) {
      ref.invalidate(productionRecordsProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(brickTypesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(record == null ? 'Production entry created.' : 'Production entry updated.')),
        );
      }
    }
  }

  Future<void> _deleteEntry(ProductionRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text('Are you sure you want to delete production entry #${record.id} (${record.product}, ${record.quantity} pcs)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: DeskColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(apiClientProvider).deleteProduction(record.id);
        ref.invalidate(productionRecordsProvider);
        ref.invalidate(dashboardProvider);
        ref.invalidate(brickTypesProvider);
        setState(() => _selectedId = null);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Production entry deleted.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(apiErrorMessage(e))),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(productionRecordsProvider(query));

    return DeskPage(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: records.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(apiErrorMessage(error))),
          data: (data) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Production register',
                              style: Theme.of(context).textTheme.displaySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${data.total} entries · page $_page of ${data.lastPage}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: DeskColors.muted),
                            ),
                          ],
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: _pickRange,
                          icon: const Icon(Icons.date_range, size: 16),
                          label: Text(_range == null
                              ? 'Filter date'
                              : '${_date(_range!.start)} → ${_date(_range!.end)}'),
                        ),
                        if (_range != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Clear filter',
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() {
                              _range = null;
                              _page = 1;
                            }),
                          ),
                        ],
                        if (_canExport) ...[
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _exportCsv,
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text('Export CSV'),
                          ),
                        ],
                        if (_canCreate) ...[
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: () => _openEntryDialog(),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('New Entry'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Card(
                        child: SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Machine')),
                              DataColumn(label: Text('Product')),
                              DataColumn(label: Text('Design')),
                              DataColumn(label: Text('Qty'), numeric: true),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: data.items.map((item) {
                              final selected = item.id == _selectedId;
                              return DataRow(
                                selected: selected,
                                onSelectChanged: (_) => setState(
                                  () => _selectedId = item.id,
                                ),
                                cells: [
                                  DataCell(Text(item.date)),
                                  DataCell(Text(item.machine)),
                                  DataCell(Text(item.product)),
                                  DataCell(Text(item.design ?? '—')),
                                  DataCell(Text('${item.quantity}')),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_canEdit)
                                          IconButton(
                                            tooltip: 'Edit',
                                            icon: const Icon(Icons.edit_outlined, size: 16),
                                            onPressed: () => _openEntryDialog(item),
                                          ),
                                        if (_canDelete)
                                          IconButton(
                                            tooltip: 'Delete',
                                            icon: const Icon(Icons.delete_outline, size: 16, color: DeskColors.danger),
                                            onPressed: () => _deleteEntry(item),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: _page > 1
                              ? () => setState(() => _page--)
                              : null,
                          child: const Text('Previous'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _page < data.lastPage
                              ? () => setState(() => _page++)
                              : null,
                          child: const Text('Next'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 320,
                child: _DetailPane(
                  record: data.items.where((e) => e.id == _selectedId).firstOrNull,
                  canEdit: _canEdit,
                  canDelete: _canDelete,
                  onEdit: _openEntryDialog,
                  onDelete: _deleteEntry,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailPane extends StatelessWidget {
  const _DetailPane({
    required this.record,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  final ProductionRecord? record;
  final bool canEdit;
  final bool canDelete;
  final Function(ProductionRecord) onEdit;
  final Function(ProductionRecord) onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: record == null
            ? Center(
                child: Text(
                  'Select a row to view details',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: DeskColors.muted),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Entry detail', style: Theme.of(context).textTheme.titleLarge),
                      const Spacer(),
                      if (canEdit)
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => onEdit(record!),
                        ),
                      if (canDelete)
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline, size: 18, color: DeskColors.danger),
                          onPressed: () => onDelete(record!),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _row('Date', record!.date),
                  _row('Machine', record!.machine),
                  _row('Product', record!.product),
                  _row('Design', record!.design ?? '—'),
                  _row('Quantity', '${record!.quantity} pcs'),
                  const SizedBox(height: 12),
                  const Divider(),
                  Text(
                    record!.remarks ?? 'No remarks',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(color: DeskColors.muted, fontSize: 12),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );
}
