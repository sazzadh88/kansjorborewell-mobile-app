import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_widgets.dart';

class DesignPatternsScreen extends ConsumerStatefulWidget {
  const DesignPatternsScreen({super.key});

  @override
  ConsumerState<DesignPatternsScreen> createState() =>
      _DesignPatternsScreenState();
}

class _DesignPatternsScreenState extends ConsumerState<DesignPatternsScreen> {
  final _nameController = TextEditingController();
  final _colorsController = TextEditingController();
  int? _editingId;
  String? _size;
  bool _isActive = true;
  bool _saving = false;

  bool get _canWrite =>
      ref.read(authProvider).value?.hasPermission('products.manage') ?? false;

  @override
  void dispose() {
    _nameController.dispose();
    _colorsController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _nameController.clear();
    _colorsController.clear();
    setState(() {
      _editingId = null;
      _size = null;
      _isActive = true;
    });
  }

  void _startEdit(DesignModel item) {
    _nameController.text = item.name;
    _colorsController.text = item.colors.join(', ');
    setState(() {
      _editingId = item.id;
      _size = item.size;
      _isActive = item.isActive;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _size == null || _size!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a design name and choose a thickness.')),
      );
      return;
    }
    final colors = _colorsController.text
        .split(',')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
    setState(() => _saving = true);
    final payload = {
      'name': name,
      'size': _size,
      'colors': colors,
      'is_active': _isActive,
    };
    try {
      if (_editingId == null) {
        await ref.read(apiClientProvider).createDesign(payload);
      } else {
        await ref
            .read(apiClientProvider)
            .updateDesign(_editingId!, payload);
      }
      _resetForm();
      ref.invalidate(designsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editingId == null ? 'Design added.' : 'Design updated.',
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

  Future<void> _delete(DesignModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${item.name}?'),
        content: const Text('Designs used in production entries cannot be deleted.'),
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
      await ref.read(apiClientProvider).deleteDesign(item.id);
      ref.invalidate(designsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item.name} deleted.')),
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
    final designs = ref.watch(designsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Design patterns')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(designsProvider);
          await ref.read(designsProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            if (_canWrite) ...[
              FormSection(
                title: _editingId == null ? 'Add design pattern' : 'Edit design pattern',
                subtitle: 'These patterns appear in the production entry design picker.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Design pattern',
                        hintText: 'e.g. Zigzag, I-Shape',
                        prefixIcon: Icon(Icons.texture_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ref.watch(brickSizesProvider).when(
                      loading: () => const SizedBox(height: 20),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (sizes) => DropdownButtonFormField<String>(
                        initialValue: _size,
                        decoration: const InputDecoration(
                          labelText: 'Thickness / Size',
                          prefixIcon: Icon(Icons.straighten_outlined),
                        ),
                        items: sizes
                            .map((s) => DropdownMenuItem<String>(
                                  value: s['name']?.toString() ?? '',
                                  child: Text(s['name']?.toString() ?? ''),
                                ))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _size = value),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _colorsController,
                      decoration: const InputDecoration(
                        labelText: 'Available colors',
                        hintText: 'Comma separated, e.g. Grey, Red',
                        prefixIcon: Icon(Icons.palette_outlined),
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
                            label: Text(_saving ? 'Saving' : 'Save design'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
            ],
            const SectionHeading(title: 'Saved designs'),
            const SizedBox(height: 12),
            designs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorState(
                message: 'Designs are unavailable.',
                onRetry: () => ref.invalidate(designsProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    title: 'No designs yet',
                    message: 'Add a design pattern above to use it in production.',
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
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.size} · ${item.isActive ? 'Active' : 'Inactive'}',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: item.colors
                                        .map(
                                          (c) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.accentTint,
                                              borderRadius: BorderRadius.circular(99),
                                            ),
                                            child: Text(
                                              c,
                                              style: const TextStyle(
                                                color: AppColors.accentDark,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
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
