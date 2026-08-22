import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_widgets.dart';

class BrickSizesScreen extends ConsumerStatefulWidget {
  const BrickSizesScreen({super.key});

  @override
  ConsumerState<BrickSizesScreen> createState() => _BrickSizesScreenState();
}

class _BrickSizesScreenState extends ConsumerState<BrickSizesScreen> {
  final _nameController = TextEditingController();
  final _orderController = TextEditingController();
  int? _editingId;
  bool _isActive = true;
  bool _saving = false;

  bool get _canWrite =>
      ref.read(authProvider).value?.hasPermission('products.manage') ?? false;

  @override
  void dispose() {
    _nameController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _nameController.clear();
    _orderController.clear();
    setState(() {
      _editingId = null;
      _isActive = true;
    });
  }

  void _startEdit(Map<String, dynamic> item) {
    _nameController.text = item['name']?.toString() ?? '';
    _orderController.text = item['sort_order']?.toString() ?? '';
    setState(() {
      _editingId = item['id'] as int;
      _isActive = item['is_active'] as bool? ?? true;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a size or thickness name.')),
      );
      return;
    }
    setState(() => _saving = true);
    final payload = {
      'name': name,
      'sort_order': int.tryParse(_orderController.text.trim()) ?? 0,
      'is_active': _isActive,
    };
    try {
      if (_editingId == null) {
        await ref.read(apiClientProvider).createBrickSize(payload);
      } else {
        await ref
            .read(apiClientProvider)
            .updateBrickSize(_editingId!, payload);
      }
      _resetForm();
      ref.invalidate(brickSizesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editingId == null ? 'Size added.' : 'Size updated.',
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

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${item['name']}?'),
        content: const Text('This size will no longer be selectable for products or designs.'),
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
          .deleteBrickSize(item['id'] as int);
      ref.invalidate(brickSizesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item['name']} deleted.')),
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

  @override
  Widget build(BuildContext context) {
    final sizes = ref.watch(brickSizesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Thickness / Sizes')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(brickSizesProvider);
          await ref.read(brickSizesProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            if (_canWrite) ...[
              FormSection(
                title: _editingId == null ? 'Add size / thickness' : 'Edit size / thickness',
                subtitle: 'These sizes are available in product and design pickers.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Size / Thickness',
                        hintText: 'e.g. 60mm',
                        prefixIcon: Icon(Icons.straighten_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _orderController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Sort order',
                        prefixIcon: Icon(Icons.sort_outlined),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      title: const Text(
                        'Active',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      value: _isActive,
                      onChanged: (value) => setState(() => _isActive = value),
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
                            label: Text(_saving ? 'Saving' : 'Save size'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
            ],
            const SectionHeading(title: 'Saved sizes'),
            const SizedBox(height: 12),
            sizes.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorState(
                message: 'Sizes are unavailable.',
                onRetry: () => ref.invalidate(brickSizesProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    title: 'No sizes yet',
                    message: 'Add a size above to make it available in pickers.',
                  );
                }
                return Column(
                  children: items.map((item) {
                    final active = item['is_active'] as bool? ?? true;
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
                                    item['name']?.toString() ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Order ${item['sort_order'] ?? 0} · ${active ? 'Active' : 'Inactive'}',
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
