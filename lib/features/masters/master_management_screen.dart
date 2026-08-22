import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_widgets.dart';

class MasterManagementScreen extends ConsumerStatefulWidget {
  const MasterManagementScreen({
    required this.resource,
    required this.title,
    required this.fields,
    super.key,
  });
  final String resource;
  final String title;
  final List<String> fields;

  @override
  ConsumerState<MasterManagementScreen> createState() =>
      _MasterManagementState();
}

class _MasterManagementState extends ConsumerState<MasterManagementScreen> {
  final _controllers = <String, TextEditingController>{};
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  int? _editingId;

  bool get _canWrite => switch (widget.resource) {
    'machines' => ref.read(authProvider).value?.hasPermission('products.manage') ?? false,
    _ => ref.read(authProvider).value?.hasPermission('masters.manage') ?? false,
  };

  IconData get _icon => switch (widget.resource) {
    'vehicles' => Icons.local_shipping_outlined,
    'drivers' => Icons.badge_outlined,
    'machines' => Icons.precision_manufacturing_outlined,
    _ => Icons.storefront_outlined,
  };

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      _controllers[field] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _validate(String field, String? value) {
    final text = value?.trim() ?? '';
    final required = field == widget.fields.first;
    if (required && text.isEmpty) return 'Required';
    if (field == 'mobile' &&
        text.isNotEmpty &&
        !RegExp(r'^\+?[0-9]{7,15}$').hasMatch(text)) {
      return 'Enter a valid mobile number';
    }
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final payload = {
      for (final field in widget.fields)
        field: _controllers[field]!.text.trim(),
    };
    try {
      if (_editingId == null) {
        await ref
            .read(apiClientProvider)
            .createMaster(widget.resource, payload);
      } else {
        await ref
            .read(apiClientProvider)
            .updateMaster(widget.resource, _editingId!, payload);
      }
      _clearForm();
      _invalidateList();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editingId == null
                  ? '${widget.title} added.'
                  : '${widget.title} updated.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _clearForm() {
    for (final controller in _controllers.values) {
      controller.clear();
    }
    setState(() => _editingId = null);
  }

  void _startEdit(Map<String, dynamic> row) {
    _editingId = row['id'] as int;
    for (final field in widget.fields) {
      _controllers[field]!.text = row[field]?.toString() ?? '';
    }
    setState(() {});
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${widget.title.toLowerCase()}?'),
        content: const Text(
          'This record will be removed from future dispatch pickers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(apiClientProvider)
          .deleteMaster(widget.resource, row['id'] as int);
      _invalidateList();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${widget.title} deleted.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      }
    }
  }

  void _invalidateList() {
    switch (widget.resource) {
      case 'vehicles':
        ref.invalidate(vehiclesProvider);
        break;
      case 'drivers':
        ref.invalidate(driversProvider);
        break;
      case 'machines':
        ref.invalidate(machinesProvider);
        break;
      default:
        ref.invalidate(partiesProvider);
    }
  }

  Widget _recordTile(Map<String, dynamic> row) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: AppCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accentTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon, color: AppColors.accentDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (row['name'] ?? row['registration_number'] ?? 'Record')
                      .toString(),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  'ID ${row['id']}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (_canWrite) ...[
            IconButton(
              tooltip: 'Edit',
              onPressed: () => _startEdit(row),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: () => _delete(row),
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            ),
          ],
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final provider = switch (widget.resource) {
      'vehicles' => vehiclesProvider,
      'drivers' => driversProvider,
      'machines' => machinesProvider,
      _ => partiesProvider,
    };
    final items = ref.watch(provider);
    final title = _editingId == null
        ? 'Add ${widget.title.toLowerCase()}'
        : 'Edit ${widget.title.toLowerCase()}';
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(provider);
          await ref.read(provider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            if (_canWrite) ...[
              FormSection(
                title: title,
                subtitle:
                    'Validated records appear immediately in dispatch pickers.',
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      for (final field in widget.fields)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextFormField(
                            controller: _controllers[field],
                            keyboardType: field == 'mobile'
                                ? TextInputType.phone
                                : TextInputType.text,
                            validator: (value) => _validate(field, value),
                            decoration: InputDecoration(
                              labelText: field.replaceAll('_', ' '),
                              prefixIcon: Icon(_icon),
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          if (_editingId != null)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _saving ? null : _clearForm,
                                child: const Text('Cancel edit'),
                              ),
                            ),
                          if (_editingId != null) const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: Icon(
                                _editingId == null
                                    ? Icons.add
                                    : Icons.save_outlined,
                              ),
                              label: Text(
                                _saving
                                    ? 'Saving'
                                    : _editingId == null
                                    ? 'Add ${widget.title.toLowerCase()}'
                                    : 'Save changes',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
            ],
            SectionHeading(
              title: 'Saved ${widget.title.toLowerCase()}s',
              action: IconButton(
                onPressed: () => ref.invalidate(provider),
                icon: const Icon(Icons.refresh),
              ),
            ),
            const SizedBox(height: 12),
            items.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorState(
                message: 'Could not load ${widget.title.toLowerCase()}s.',
                onRetry: () => ref.invalidate(provider),
              ),
              data: (rows) {
                final maps = rows is List<Map<String, dynamic>>
                    ? rows
                    : rows.map((r) {
                        if (r is MachineModel) {
                          return {'id': r.id, 'name': r.name, 'code': r.code, 'is_active': r.isActive};
                        }
                        return r as Map<String, dynamic>;
                      }).toList();
                if (maps.isEmpty) {
                  return EmptyState(
                    title: 'No records yet',
                    message: _canWrite
                        ? 'Add a record above to make it available in dispatch.'
                        : 'No ${widget.title.toLowerCase()} records yet.',
                  );
                }
                return Column(children: maps.map(_recordTile).toList());
              },
            ),
          ],
        ),
      ),
    );
  }
}
