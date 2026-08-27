import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_widgets.dart';

class BrickTypesScreen extends ConsumerStatefulWidget {
  const BrickTypesScreen({super.key});

  @override
  ConsumerState<BrickTypesScreen> createState() => _BrickTypesScreenState();
}

class _BrickTypesScreenState extends ConsumerState<BrickTypesScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _reorderController = TextEditingController();
  int? _editingId;
  bool _isPaver = false;
  String? _size;
  bool _saving = false;

  bool get _canWrite =>
      ref.read(authProvider).value?.hasPermission('products.manage') ?? false;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _reorderController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _nameController.clear();
    _codeController.clear();
    _reorderController.clear();
    setState(() {
      _editingId = null;
      _isPaver = false;
      _size = null;
    });
  }

  void _startEdit(BrickTypeModel item) {
    _nameController.text = item.name;
    _codeController.text = item.code;
    _reorderController.text = item.reorderLevel.toString();
    setState(() {
      _editingId = item.id;
      _isPaver = item.isPaver;
      _size = item.size;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim();
    final reorder = int.tryParse(_reorderController.text.trim()) ?? 0;
    if (name.isEmpty || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a brick type name and code.')),
      );
      return;
    }
    setState(() => _saving = true);
    final payload = {
      'name': name,
      'code': code,
      'reorder_level': reorder,
      'is_paver': _isPaver,
      if (_size != null && _size!.isNotEmpty) 'size': _size else 'size': null,
    };
    try {
      if (_editingId == null) {
        await ref.read(apiClientProvider).createMaster('brick-types', payload);
      } else {
        await ref
            .read(apiClientProvider)
            .updateMaster('brick-types', _editingId!, payload);
      }
      _resetForm();
      ref.invalidate(brickTypesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editingId == null ? 'Brick type added.' : 'Brick type updated.',
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

  Future<void> _delete(BrickTypeModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${item.name}?'),
        content: const Text(
          'This brick type cannot be deleted if it is used in production or dispatch.',
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
      await ref.read(apiClientProvider).deleteMaster('brick-types', item.id);
      ref.invalidate(brickTypesProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${item.name} deleted.')));
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
    final bricks = ref.watch(brickTypesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Brick types')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(brickTypesProvider);
          await ref.read(brickTypesProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            if (_canWrite) ...[
              FormSection(
                title: _editingId == null
                    ? 'Add brick type'
                    : 'Edit brick type',
                subtitle: _editingId == null
                    ? 'Create a brick type and mark it as paver if designs apply.'
                    : 'Update this brick type\'s name, code, reorder level, or type.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Icons.view_module_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _codeController,
                      decoration: const InputDecoration(
                        labelText: 'Code',
                        prefixIcon: Icon(Icons.qr_code_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _reorderController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Reorder level',
                        prefixIcon: Icon(Icons.warning_amber_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ref
                        .watch(brickSizesProvider)
                        .when(
                          loading: () => const SizedBox(height: 20),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (sizes) => DropdownButtonFormField<String?>(
                            initialValue: _size,
                            decoration: const InputDecoration(
                              labelText: 'Size / Thickness (Optional)',
                              prefixIcon: Icon(Icons.straighten_outlined),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('None'),
                              ),
                              ...sizes.map(
                                (s) => DropdownMenuItem<String?>(
                                  value: s['name']?.toString() ?? '',
                                  child: Text(s['name']?.toString() ?? ''),
                                ),
                              ),
                            ],
                            onChanged: (value) => setState(() => _size = value),
                          ),
                        ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                      ),
                      title: const Text(
                        'Paver block',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'Enables design selection in production',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                      value: _isPaver,
                      onChanged: (value) => setState(() => _isPaver = value),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (_editingId != null) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _saving ? null : _resetForm,
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(_saving ? 'Saving' : 'Save brick type'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
            ],
            const SectionHeading(title: 'Brick types'),
            const SizedBox(height: 12),
            bricks.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorState(
                message: 'Brick types are unavailable.',
                onRetry: () => ref.invalidate(brickTypesProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    title: 'No brick types',
                    message: 'Add a brick type above to get started.',
                  );
                }
                return Column(
                  children: items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.code} · ${item.isPaver ? 'Paver' : 'Fly ash'}',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_canWrite) ...[
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: () => _startEdit(item),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: () => _delete(item),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.danger,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
