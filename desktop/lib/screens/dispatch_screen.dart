import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

import '../widgets/desk_page.dart';
import '../theme/desk_theme.dart';

class DispatchScreen extends ConsumerStatefulWidget {
  const DispatchScreen({super.key});

  @override
  ConsumerState<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends ConsumerState<DispatchScreen> {
  DateTimeRange? _range;
  int _page = 1;
  int? _selectedId;

  bool get _canCreate =>
      ref.watch(authProvider).value?.hasPermission('dispatch.create') ?? false;
  bool get _canEdit =>
      ref.watch(authProvider).value?.hasPermission('dispatch.edit') ?? false;
  bool get _canDelete =>
      ref.watch(authProvider).value?.hasPermission('dispatch.delete') ?? false;
  bool get _canExport =>
      ref.watch(authProvider).value?.hasPermission('dispatch.export') ?? false;

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
    final fileName = 'dispatch-$from-$to.csv';
    try {
      final csv = await ref
          .read(apiClientProvider)
          .exportCsv('dispatches', from: from, to: to);
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
    }
  }

  Future<void> _openEntryDialog([DispatchRecord? record]) async {
    ref.invalidate(brickTypesProvider);
    ref.invalidate(designsProvider);
    ref.invalidate(partiesProvider);
    ref.invalidate(vehiclesProvider);
    ref.invalidate(driversProvider);

    final bricks = await ref.read(brickTypesProvider.future);
    final designs = await ref.read(designsProvider.future);
    final parties = await ref.read(partiesProvider.future);
    final vehicles = await ref.read(vehiclesProvider.future);
    final drivers = await ref.read(driversProvider.future);

    if (!mounted) return;

    if (bricks.isEmpty || parties.isEmpty || vehicles.isEmpty) {
      final missing = [
        if (bricks.isEmpty) 'products',
        if (parties.isEmpty) 'parties',
        if (vehicles.isEmpty) 'vehicles',
      ].join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot create dispatch: no $missing available. '
            'Add them under Masters first, then retry.',
          ),
        ),
      );
      return;
    }

    int? brickTypeId = record?.brickTypeId ?? bricks.firstOrNull?.id;
    int? designId = record?.designId;
    int? partyId =
        record?.partyId ?? (parties.firstOrNull?['id'] as num?)?.toInt();
    int? vehicleId =
        record?.vehicleId ?? (vehicles.firstOrNull?['id'] as num?)?.toInt();
    int? driverId =
        record?.driverId ?? (drivers.firstOrNull?['id'] as num?)?.toInt();

    final qtyCtrl = TextEditingController(
      text: record != null ? '${record.quantity}' : '',
    );
    final freightCtrl = TextEditingController(
      text: record?.freightAmount != null ? '${record!.freightAmount}' : '',
    );
    final paidCtrl = TextEditingController(
      text: record != null ? '${record.paidAmount}' : '0',
    );
    String paymentStatus = record?.paymentStatus ?? 'due';
    String? paymentMode = record?.paymentMode ?? 'cash';
    final remarksCtrl = TextEditingController(text: record?.remarks ?? '');
    DateTime date = record != null
        ? DateTime.parse(record.date)
        : DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final selectedBrick = bricks
              .where((b) => b.id == brickTypeId)
              .firstOrNull;
          final isPaver = selectedBrick?.isPaver ?? false;

          return AlertDialog(
            title: Text(record == null ? 'New Dispatch' : 'Edit Dispatch'),
            content: SizedBox(
              width: 480,
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
                      value: brickTypeId,
                      decoration: const InputDecoration(labelText: 'Product'),
                      items: bricks
                          .map(
                            (b) => DropdownMenuItem(
                              value: b.id,
                              child: Text(b.name),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          brickTypeId = val;
                          final b = bricks
                              .where((item) => item.id == val)
                              .firstOrNull;
                          if (b == null || !b.isPaver) designId = null;
                        });
                      },
                    ),
                    if (isPaver) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: designId,
                        decoration: const InputDecoration(
                          labelText: 'Design (Paver)',
                        ),
                        items: [
                          const DropdownMenuItem<int>(
                            value: null,
                            child: Text('None / Default'),
                          ),
                          ...designs.map(
                            (d) => DropdownMenuItem(
                              value: d.id,
                              child: Text(d.label),
                            ),
                          ),
                        ],
                        onChanged: (val) =>
                            setDialogState(() => designId = val),
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: partyId,
                      decoration: const InputDecoration(
                        labelText: 'Party / Buyer',
                      ),
                      items: parties
                          .map(
                            (p) => DropdownMenuItem(
                              value: (p['id'] as num).toInt(),
                              child: Text(p['name']?.toString() ?? ''),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setDialogState(() => partyId = val),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: vehicleId,
                            decoration: const InputDecoration(
                              labelText: 'Vehicle',
                            ),
                            items: vehicles
                                .map(
                                  (v) => DropdownMenuItem(
                                    value: (v['id'] as num).toInt(),
                                    child: Text(
                                      v['registration_number']?.toString() ??
                                          '',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setDialogState(() => vehicleId = val),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: driverId,
                            decoration: const InputDecoration(
                              labelText: 'Driver (Optional)',
                            ),
                            items: [
                              const DropdownMenuItem<int>(
                                value: null,
                                child: Text('None'),
                              ),
                              ...drivers.map(
                                (d) => DropdownMenuItem(
                                  value: (d['id'] as num).toInt(),
                                  child: Text(d['name']?.toString() ?? ''),
                                ),
                              ),
                            ],
                            onChanged: (val) =>
                                setDialogState(() => driverId = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity Loaded (pcs)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: freightCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Freight (₹)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: paidCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Paid Amount (₹)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: paymentStatus,
                            decoration: const InputDecoration(
                              labelText: 'Payment Status',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'due',
                                child: Text('Due'),
                              ),
                              DropdownMenuItem(
                                value: 'paid',
                                child: Text('Paid'),
                              ),
                              DropdownMenuItem(
                                value: 'partial',
                                child: Text('Partial'),
                              ),
                            ],
                            onChanged: (val) => setDialogState(
                              () => paymentStatus = val ?? 'due',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: paymentMode,
                            decoration: const InputDecoration(
                              labelText: 'Payment Mode',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'cash',
                                child: Text('Cash'),
                              ),
                              DropdownMenuItem(
                                value: 'upi',
                                child: Text('UPI / Online'),
                              ),
                              DropdownMenuItem(
                                value: 'bank_transfer',
                                child: Text('Bank Transfer'),
                              ),
                              DropdownMenuItem(
                                value: 'cheque',
                                child: Text('Cheque'),
                              ),
                            ],
                            onChanged: (val) =>
                                setDialogState(() => paymentMode = val),
                          ),
                        ),
                      ],
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
                  final freight = double.tryParse(freightCtrl.text.trim());
                  final paid = double.tryParse(paidCtrl.text.trim()) ?? 0.0;
                  final missing = <String>[
                    if (brickTypeId == null) 'product',
                    if (partyId == null) 'party',
                    if (vehicleId == null) 'vehicle',
                    if (qty == null || qty <= 0) 'quantity',
                  ];
                  if (missing.isNotEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Please fill valid ${missing.join(', ')}.',
                        ),
                      ),
                    );
                    return;
                  }
                  final payload = {
                    'dispatch_date': _date(date),
                    'brick_type_id': brickTypeId,
                    if (designId != null) 'design_id': designId,
                    'party_id': partyId,
                    'vehicle_id': vehicleId,
                    if (driverId != null) 'driver_id': driverId,
                    'quantity_loaded': qty,
                    if (freight != null) 'freight_amount': freight,
                    'payment_status': paymentStatus,
                    'paid_amount': paid,
                    if (paymentMode != null) 'payment_mode': paymentMode,
                    if (remarksCtrl.text.trim().isNotEmpty)
                      'remarks': remarksCtrl.text.trim(),
                  };
                  try {
                    final api = ref.read(apiClientProvider);
                    if (record == null) {
                      await api.createDispatch(payload);
                    } else {
                      await api.updateDispatch(record.id, payload);
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
      ref.invalidate(dispatchRecordsProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(brickTypesProvider);
      ref.invalidate(dispatchDuesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              record == null ? 'Dispatch created.' : 'Dispatch updated.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteEntry(DispatchRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Dispatch?'),
        content: Text(
          'Are you sure you want to delete dispatch #${record.id} for ${record.party}?',
        ),
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
        await ref.read(apiClientProvider).deleteDispatch(record.id);
        ref.invalidate(dispatchRecordsProvider);
        ref.invalidate(dashboardProvider);
        ref.invalidate(brickTypesProvider);
        ref.invalidate(dispatchDuesProvider);
        setState(() => _selectedId = null);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Dispatch deleted.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(dispatchRecordsProvider(query));

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
                              'Dispatch register',
                              style: Theme.of(context).textTheme.displaySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${data.total} entries · page $_page of ${data.lastPage}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: DeskColors.muted),
                            ),
                          ],
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: _pickRange,
                          icon: const Icon(Icons.date_range, size: 16),
                          label: Text(
                            _range == null
                                ? 'Filter date'
                                : '${_date(_range!.start)} → ${_date(_range!.end)}',
                          ),
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
                            label: const Text('New Dispatch'),
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
                              DataColumn(label: Text('Product')),
                              DataColumn(label: Text('Design')),
                              DataColumn(label: Text('Party')),
                              DataColumn(label: Text('Vehicle')),
                              DataColumn(label: Text('Qty'), numeric: true),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: data.items.map((item) {
                              final selected = item.id == _selectedId;
                              return DataRow(
                                selected: selected,
                                onSelectChanged: (_) =>
                                    setState(() => _selectedId = item.id),
                                cells: [
                                  DataCell(Text(item.date)),
                                  DataCell(Text(item.product)),
                                  DataCell(Text(item.design ?? '—')),
                                  DataCell(Text(item.party)),
                                  DataCell(Text(item.vehicle)),
                                  DataCell(Text('${item.quantity}')),
                                  DataCell(
                                    Text(
                                      item.isPaid ? 'Paid' : 'Due',
                                      style: TextStyle(
                                        color: item.isPaid
                                            ? DeskColors.settled
                                            : DeskColors.low,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_canEdit)
                                          IconButton(
                                            tooltip: 'Edit',
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                              size: 16,
                                            ),
                                            onPressed: () =>
                                                _openEntryDialog(item),
                                          ),
                                        if (_canDelete)
                                          IconButton(
                                            tooltip: 'Delete',
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 16,
                                              color: DeskColors.danger,
                                            ),
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
                width: 340,
                child: _DetailPane(
                  record: data.items
                      .where((e) => e.id == _selectedId)
                      .firstOrNull,
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

  final DispatchRecord? record;
  final bool canEdit;
  final bool canDelete;
  final Function(DispatchRecord) onEdit;
  final Function(DispatchRecord) onDelete;

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
                      Text(
                        'Dispatch detail',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
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
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: DeskColors.danger,
                          ),
                          onPressed: () => onDelete(record!),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _row('Date', record!.date),
                  _row('Product', record!.product),
                  _row('Design', record!.design ?? '—'),
                  _row('Party', record!.party),
                  _row('Vehicle', record!.vehicle),
                  _row('Driver', record!.driver ?? '—'),
                  _row('Quantity', '${record!.quantity} pcs'),
                  _row('Freight', '₹ ${record!.freightAmount ?? 0}'),
                  _row('Paid', '₹ ${record!.paidAmount}'),
                  _row('Due', '₹ ${record!.dueAmount}'),
                  _row('Mode', record!.paymentMode ?? '—'),
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
