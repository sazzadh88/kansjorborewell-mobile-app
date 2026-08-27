import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

import '../widgets/desk_page.dart';
import '../theme/desk_theme.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Stock Movement filter state
  DateTimeRange? _movementRange;
  int _movementPage = 1;
  bool _refreshing = false;

  bool get _canManage =>
      ref.watch(authProvider).value?.hasPermission('inventory.manage') ?? false;
  bool get _canReport =>
      ref.watch(authProvider).value?.hasPermission('inventory.report') ?? false;

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
    ref.invalidate(rawMaterialsProvider);
    ref.invalidate(inventoryReportProvider);
    try {
      await Future.wait([
        ref.read(rawMaterialsProvider.future),
        if (_canReport) ref.read(inventoryReportProvider(_movementQuery).future),
      ]);
    } catch (_) {}
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _refreshing = false);
    }
  }

  ({String? from, String? to, int page}) get _movementQuery => (
        from: _movementRange == null ? null : _date(_movementRange!.start),
        to: _movementRange == null ? null : _date(_movementRange!.end),
        page: _movementPage,
      );

  @override
  void initState() {
    super.initState();
    final canReport =
        ref.read(authProvider).value?.hasPermission('inventory.report') ?? false;
    _tabController = TabController(length: canReport ? 2 : 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickMovementRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _movementRange,
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
      _movementRange = picked;
      _movementPage = 1;
    });
  }

  Future<void> _exportMovementCsv() async {
    if (_movementRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date range first.')),
      );
      return;
    }
    final from = _date(_movementRange!.start);
    final to = _date(_movementRange!.end);
    final fileName = 'inventory-$from-$to.csv';
    try {
      final csv = await ref
          .read(apiClientProvider)
          .exportInventoryCsv(from: from, to: to);
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

  Future<void> _openStockDialog(RawMaterialModel item, {required bool isStockIn}) async {
    final qtyCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    DateTime txDate = DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Text('${isStockIn ? "Stock In" : "Stock Out"} — ${item.name}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Current Stock: ${item.currentStock} ${item.unit}'),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Date: ${_date(txDate)}'),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogCtx,
                      initialDate: txDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => txDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Quantity (${item.unit})',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: remarksCtrl,
                  decoration: const InputDecoration(labelText: 'Remarks (Optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final qty = double.tryParse(qtyCtrl.text.trim());
                if (qty == null || qty <= 0) {
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid positive quantity.')),
                  );
                  return;
                }
                final payload = {
                  'quantity': qty,
                  'transaction_date': _date(txDate),
                  if (remarksCtrl.text.trim().isNotEmpty) 'remarks': remarksCtrl.text.trim(),
                };
                try {
                  final api = ref.read(apiClientProvider);
                  if (isStockIn) {
                    await api.stockInRawMaterial(item.id, payload);
                  } else {
                    await api.stockOutRawMaterial(item.id, payload);
                  }
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx, true);
                } catch (e) {
                  if (dialogCtx.mounted) {
                    ScaffoldMessenger.of(dialogCtx).showSnackBar(
                      SnackBar(content: Text(apiErrorMessage(e))),
                    );
                  }
                }
              },
              child: Text(isStockIn ? 'Stock In' : 'Stock Out'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      ref.invalidate(rawMaterialsProvider);
      ref.invalidate(inventoryReportProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${isStockIn ? "Stock In" : "Stock Out"} recorded.')),
        );
      }
    }
  }

  Future<void> _openMaterialDialog([RawMaterialModel? item]) async {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final unitCtrl = TextEditingController(text: item?.unit ?? 'kg');
    final stockCtrl = TextEditingController(text: item != null ? '${item.currentStock}' : '0');
    final reorderCtrl = TextEditingController(text: item != null ? '${item.reorderLevel}' : '100');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item == null ? 'Add Raw Material' : 'Edit Raw Material'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Material Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: unitCtrl,
                decoration: const InputDecoration(labelText: 'Unit (e.g. kg, ton, bag)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stockCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: item == null ? 'Initial Stock' : 'Current Stock',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reorderCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Reorder Level'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final unit = unitCtrl.text.trim();
              final stock = double.tryParse(stockCtrl.text.trim()) ?? 0.0;
              final reorder = double.tryParse(reorderCtrl.text.trim()) ?? 0.0;
              if (name.isEmpty || unit.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please provide name and unit.')),
                );
                return;
              }
              final payload = {
                'name': name,
                'unit': unit,
                'current_stock': stock,
                'reorder_level': reorder,
              };
              try {
                final api = ref.read(apiClientProvider);
                if (item == null) {
                  await api.createMaster('raw-materials', payload);
                } else {
                  await api.updateMaster('raw-materials', item.id, payload);
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(apiErrorMessage(e))),
                  );
                }
              }
            },
            child: Text(item == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );

    if (saved == true) {
      ref.invalidate(rawMaterialsProvider);
      ref.invalidate(inventoryReportProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(item == null ? 'Material created.' : 'Material updated.')),
        );
      }
    }
  }

  Future<void> _deleteMaterial(RawMaterialModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${item.name}?'),
        content: const Text('Are you sure you want to delete this raw material?'),
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
        await ref.read(apiClientProvider).deleteMaster('raw-materials', item.id);
        ref.invalidate(rawMaterialsProvider);
        ref.invalidate(inventoryReportProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Material deleted.')),
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
    return DeskPage(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Inventory', style: Theme.of(context).textTheme.displaySmall),
                    const SizedBox(height: 4),
                    Text(
                      'Raw materials stock, reorder levels, and stock movement ledger',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: DeskColors.muted),
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
                const SizedBox(width: 8),
                if (_canManage)
                  FilledButton.icon(
                    onPressed: () => _openMaterialDialog(),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Material'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                const Tab(
                  iconMargin: EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Raw Materials Stock'),
                    ],
                  ),
                ),
                if (_canReport)
                  const Tab(
                    iconMargin: EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.swap_horiz_rounded, size: 16),
                        SizedBox(width: 8),
                        Text('Stock Movement Report'),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRawMaterialsTab(),
                  if (_canReport) _buildStockMovementTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRawMaterialsTab() {
    final materials = ref.watch(rawMaterialsProvider);
    return materials.when(skipLoadingOnReload: true, skipLoadingOnRefresh: true, 
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(apiErrorMessage(error))),
      data: (items) => Card(
        child: SingleChildScrollView(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Material')),
              DataColumn(label: Text('Unit')),
              DataColumn(label: Text('Current stock'), numeric: true),
              DataColumn(label: Text('Reorder level'), numeric: true),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: items.map((item) {
              final low = item.isLowStock;
              return DataRow(cells: [
                DataCell(Text(item.name)),
                DataCell(Text(item.unit)),
                DataCell(Text('${item.currentStock}')),
                DataCell(Text('${item.reorderLevel}')),
                DataCell(
                  Text(
                    low ? 'Low' : 'OK',
                    style: TextStyle(
                      color: low ? DeskColors.low : DeskColors.settled,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_canManage) ...[
                        OutlinedButton(
                          onPressed: () => _openStockDialog(item, isStockIn: true),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 28),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text('Stock In', style: TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton(
                          onPressed: () => _openStockDialog(item, isStockIn: false),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 28),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text('Stock Out', style: TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          onPressed: () => _openMaterialDialog(item),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline, size: 16, color: DeskColors.danger),
                          onPressed: () => _deleteMaterial(item),
                        ),
                      ],
                    ],
                  ),
                ),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildStockMovementTab() {
    final report = ref.watch(inventoryReportProvider(_movementQuery));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _pickMovementRange,
              icon: const Icon(Icons.date_range, size: 16),
              label: Text(_movementRange == null
                  ? 'Filter date'
                  : '${_date(_movementRange!.start)} → ${_date(_movementRange!.end)}'),
            ),
            if (_movementRange != null) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Clear filter',
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => setState(() {
                  _movementRange = null;
                  _movementPage = 1;
                }),
              ),
            ],
            if (_canReport) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _exportMovementCsv,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Export CSV'),
              ),
            ],
            const Spacer(),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: () => ref.invalidate(inventoryReportProvider),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: report.when(skipLoadingOnReload: true, skipLoadingOnRefresh: true, 
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text(apiErrorMessage(error))),
            data: (data) => Column(
              children: [
                Expanded(
                  child: Card(
                    child: data.items.isEmpty
                        ? const Center(child: Text('No movement records found.'))
                        : SingleChildScrollView(
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Date & Time')),
                                DataColumn(label: Text('Material')),
                                DataColumn(label: Text('Type')),
                                DataColumn(label: Text('Quantity'), numeric: true),
                                DataColumn(label: Text('Remarks')),
                              ],
                              rows: data.items.map((m) {
                                final isOut = m.isOut;
                                return DataRow(cells: [
                                  DataCell(Text(m.formattedDateTime)),
                                  DataCell(Text(m.material)),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isOut
                                            ? DeskColors.danger.withValues(alpha: 0.12)
                                            : DeskColors.settled.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        m.type.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isOut ? DeskColors.danger : DeskColors.settled,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '${isOut ? '-' : '+'}${m.quantity} ${m.unit}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: isOut ? DeskColors.danger : DeskColors.settled,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(m.remarks != null && m.remarks!.isNotEmpty ? m.remarks! : '—')),
                                ]);
                              }).toList(),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${data.total} total movements · page $_movementPage of ${data.lastPage}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DeskColors.muted),
                    ),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: _movementPage > 1
                              ? () => setState(() => _movementPage--)
                              : null,
                          child: const Text('Previous'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _movementPage < data.lastPage
                              ? () => setState(() => _movementPage++)
                              : null,
                          child: const Text('Next'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
