import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

import '../widgets/desk_page.dart';
import '../theme/desk_theme.dart';

class LoadingGroupsScreen extends ConsumerStatefulWidget {
  const LoadingGroupsScreen({super.key});

  @override
  ConsumerState<LoadingGroupsScreen> createState() =>
      _LoadingGroupsScreenState();
}

class _LoadingGroupsScreenState extends ConsumerState<LoadingGroupsScreen> {
  DateTimeRange? _range;
  int _page = 1;
  int? _selectedId;

  bool get _canManage =>
      ref.watch(authProvider).value?.hasPermission('loading.manage') ?? false;

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
      helpText: 'Select date range',
    );
    if (picked == null) return;
    setState(() {
      _range = picked;
      _page = 1;
      _selectedId = null;
    });
  }

  Future<void> _openDialog([LoadingGroupRecord? record]) async {
    final bricks = await ref.read(brickTypesProvider.future);
    if (!mounted) return;

    final groupNameCtrl = TextEditingController(text: record?.groupName ?? '');
    int? brickTypeId = record?.brickTypeId ?? bricks.firstOrNull?.id;
    final qtyCtrl = TextEditingController(
      text: record != null ? '${record.quantity}' : '',
    );
    final remarksCtrl = TextEditingController(text: record?.remarks ?? '');
    DateTime date = record != null
        ? DateTime.parse(record.date)
        : DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            record == null ? 'Add Loading Group' : 'Edit Loading Group',
          ),
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
                  TextField(
                    controller: groupNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Loading Group Name',
                      hintText: 'e.g. Loading Crew 1, Team Bravo',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: brickTypeId,
                    decoration: const InputDecoration(
                      labelText: 'Brick Type / Product',
                    ),
                    items: bricks
                        .map(
                          (b) => DropdownMenuItem(
                            value: b.id,
                            child: Text(b.name),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setDialogState(() => brickTypeId = val),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Number of Items / Quantity',
                      hintText: 'e.g. 1000',
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
                final groupName = groupNameCtrl.text.trim();
                final qty = int.tryParse(qtyCtrl.text.trim());
                if (groupName.isEmpty ||
                    brickTypeId == null ||
                    qty == null ||
                    qty <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please fill group name, product, and valid quantity.',
                      ),
                    ),
                  );
                  return;
                }
                final payload = {
                  'entry_date': _date(date),
                  'group_name': groupName,
                  'brick_type_id': brickTypeId,
                  'quantity': qty,
                  if (remarksCtrl.text.trim().isNotEmpty)
                    'remarks': remarksCtrl.text.trim(),
                };
                try {
                  final api = ref.read(apiClientProvider);
                  if (record == null) {
                    await api.createLoadingGroup(payload);
                  } else {
                    await api.updateLoadingGroup(record.id, payload);
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
        ),
      ),
    );

    if (saved == true) {
      ref.invalidate(loadingGroupsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              record == null
                  ? 'Loading group record created.'
                  : 'Loading group record updated.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _delete(LoadingGroupRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Loading Group Record?'),
        content: Text(
          'Are you sure you want to delete ${record.groupName} (${record.quantity} items)?',
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
        await ref.read(apiClientProvider).deleteLoadingGroup(record.id);
        ref.invalidate(loadingGroupsProvider);
        setState(() => _selectedId = null);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Loading group record deleted.')),
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
    final groups = ref.watch(loadingGroupsProvider(query));

    return DeskPage(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: groups.when(
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
                              'Loading Groups',
                              style: Theme.of(context).textTheme.displaySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${data.total} records · page $_page of ${data.lastPage}',
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
                        if (_canManage) ...[
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: () => _openDialog(),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('New Loading Group'),
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
                              DataColumn(label: Text('Date & Time')),
                              DataColumn(label: Text('Group Name')),
                              DataColumn(label: Text('Product')),
                              DataColumn(
                                label: Text('Number of Items'),
                                numeric: true,
                              ),
                              DataColumn(label: Text('Remarks')),
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
                                  DataCell(Text(item.formattedDateTime)),
                                  DataCell(
                                    Text(
                                      item.groupName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(item.product)),
                                  DataCell(
                                    Text(
                                      '${item.quantity}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(item.remarks ?? '—')),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_canManage) ...[
                                          IconButton(
                                            tooltip: 'Edit',
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                              size: 16,
                                            ),
                                            onPressed: () =>
                                                _openDialog(item),
                                          ),
                                          IconButton(
                                            tooltip: 'Delete',
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 16,
                                              color: DeskColors.danger,
                                            ),
                                            onPressed: () => _delete(item),
                                          ),
                                        ],
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
                  record: data.items
                      .where((e) => e.id == _selectedId)
                      .firstOrNull,
                  canManage: _canManage,
                  onEdit: _openDialog,
                  onDelete: _delete,
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
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  final LoadingGroupRecord? record;
  final bool canManage;
  final Function(LoadingGroupRecord) onEdit;
  final Function(LoadingGroupRecord) onDelete;

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
                        'Loading Detail',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      if (canManage) ...[
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => onEdit(record!),
                        ),
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
                    ],
                  ),
                  const SizedBox(height: 12),
                  _row('Date & Time', record!.formattedDateTime),
                  _row('Group Name', record!.groupName),
                  _row('Product', record!.product),
                  _row('Items', '${record!.quantity} pcs'),
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
          width: 100,
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
