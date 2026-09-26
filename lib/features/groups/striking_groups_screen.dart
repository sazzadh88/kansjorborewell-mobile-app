import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_widgets.dart';

class StrikingGroupsScreen extends ConsumerStatefulWidget {
  const StrikingGroupsScreen({super.key});

  @override
  ConsumerState<StrikingGroupsScreen> createState() =>
      _StrikingGroupsScreenState();
}

class _StrikingGroupsScreenState extends ConsumerState<StrikingGroupsScreen> {
  DateTimeRange? _range;
  int _page = 1;

  bool get _canManage =>
      ref.watch(authProvider).value?.hasPermission('striking.manage') ?? false;

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
    });
  }

  Future<void> _openDialog([StrikingGroupRecord? record]) async {
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
            record == null ? 'Add Striking Group' : 'Edit Striking Group',
          ),
          content: SingleChildScrollView(
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
                    labelText: 'Striking Group Name',
                    hintText: 'e.g. Group A, Team Red',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: brickTypeId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Brick Type / Product',
                  ),
                  items: bricks
                      .map(
                        (b) => DropdownMenuItem(
                          value: b.id,
                          child: Text(
                            b.name,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                    await api.createStrikingGroup(payload);
                  } else {
                    await api.updateStrikingGroup(record.id, payload);
                  }
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx, true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
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
      ref.invalidate(strikingGroupsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              record == null
                  ? 'Striking group record created.'
                  : 'Striking group record updated.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _delete(StrikingGroupRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Striking Group Record?'),
        content: Text(
          'Are you sure you want to delete ${record.groupName} (${record.quantity} items)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(apiClientProvider).deleteStrikingGroup(record.id);
        ref.invalidate(strikingGroupsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Striking group record deleted.')),
          );
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
    final groups = ref.watch(strikingGroupsProvider(query));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Striking Groups'),
        actions: [
          IconButton(
            tooltip: 'Filter date',
            icon: const Icon(Icons.date_range_outlined),
            onPressed: _pickRange,
          ),
          if (_range != null)
            IconButton(
              tooltip: 'Clear filter',
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() => _range = null),
            ),
        ],
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton(
              onPressed: () => _openDialog(),
              child: const Icon(Icons.add),
            )
          : null,
      body: SafeArea(
        child: groups.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(apiErrorMessage(error))),
          data: (data) => data.items.isEmpty
              ? const Center(child: Text('No striking group records found.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: data.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = data.items[index];
                    return AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.accentTint,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.group_work_outlined,
                              color: AppColors.accentDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.groupName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${item.product} · ${item.formattedDateTime}',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                                if (item.remarks != null &&
                                    item.remarks!.isNotEmpty)
                                  Text(
                                    item.remarks!,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${item.quantity} pcs',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.accentDark,
                            ),
                          ),
                          if (_canManage) ...[
                            PopupMenuButton<String>(
                              onSelected: (val) {
                                if (val == 'edit') _openDialog(item);
                                if (val == 'delete') _delete(item);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    'Delete',
                                    style: TextStyle(color: AppColors.danger),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
