import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_widgets.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  static const _units = ['kg', 'bag', 'ton', 'litre', 'piece', 'Other'];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _customUnitController = TextEditingController();
  final _openingStockController = TextEditingController();
  final _reorderLevelController = TextEditingController();
  String _unit = _units.first;
  int? _editingId;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _customUnitController.dispose();
    _openingStockController.dispose();
    _reorderLevelController.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  String? _positiveNumber(String? value, {bool allowZero = true}) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null || (!allowZero && number <= 0) || number < 0) {
      return allowZero
          ? 'Enter zero or a positive number'
          : 'Enter a positive number';
    }
    return null;
  }

  String get _resolvedUnit =>
      _unit == 'Other' ? _customUnitController.text.trim() : _unit;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_unit == 'Other' && _customUnitController.text.trim().isEmpty) {
      setState(() {});
      return;
    }

    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'unit': _resolvedUnit,
      'reorder_level': double.parse(_reorderLevelController.text.trim()),
    };
    if (_editingId == null) {
      payload['current_stock'] = double.parse(
        _openingStockController.text.trim(),
      );
    }

    try {
      final api = ref.read(apiClientProvider);
      if (_editingId == null) {
        await api.createMaster('raw-materials', payload);
      } else {
        await api.updateMaster('raw-materials', _editingId!, payload);
      }
      _clearForm();
      ref.invalidate(rawMaterialsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editingId == null
                  ? 'Inventory item added.'
                  : 'Inventory item updated.',
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
    _nameController.clear();
    _customUnitController.clear();
    _openingStockController.clear();
    _reorderLevelController.clear();
    setState(() {
      _unit = _units.first;
      _editingId = null;
    });
  }

  void _startEdit(RawMaterialModel item) {
    _nameController.text = item.name;
    _reorderLevelController.text = _format(item.reorderLevel);
    _openingStockController.clear();
    if (_units.contains(item.unit)) {
      _unit = item.unit;
      _customUnitController.clear();
    } else {
      _unit = 'Other';
      _customUnitController.text = item.unit;
    }
    setState(() => _editingId = item.id);
  }

  String _format(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  Future<void> _stockIn(RawMaterialModel item) async {
    final quantityController = TextEditingController();
    final remarksController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Add ${item.name} stock'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: quantityController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) => _positiveNumber(value, allowZero: false),
                decoration: InputDecoration(
                  labelText: 'Quantity (${item.unit})',
                  prefixIcon: const Icon(Icons.add_box_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: remarksController,
                decoration: const InputDecoration(
                  labelText: 'Remarks (optional)',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Add stock'),
          ),
        ],
      ),
    );

    if (shouldSave != true) {
      quantityController.dispose();
      remarksController.dispose();
      return;
    }

    try {
      await ref.read(apiClientProvider).stockInRawMaterial(item.id, {
        'quantity': double.parse(quantityController.text.trim()),
        if (remarksController.text.trim().isNotEmpty)
          'remarks': remarksController.text.trim(),
      });
      ref.invalidate(rawMaterialsProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${item.name} stock updated.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      }
    } finally {
      quantityController.dispose();
      remarksController.dispose();
    }
  }

  Future<void> _stockOut(RawMaterialModel item) async {
    final quantityController = TextEditingController();
    final remarksController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Issue ${item.name} stock'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: quantityController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) => _positiveNumber(value, allowZero: false),
                decoration: InputDecoration(
                  labelText: 'Quantity (${item.unit})',
                  prefixIcon: const Icon(Icons.remove_circle_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: remarksController,
                decoration: const InputDecoration(
                  labelText: 'Reason or remarks',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Issue stock'),
          ),
        ],
      ),
    );
    if (shouldSave != true) {
      quantityController.dispose();
      remarksController.dispose();
      return;
    }
    try {
      await ref.read(apiClientProvider).stockOutRawMaterial(item.id, {
        'quantity': double.parse(quantityController.text.trim()),
        if (remarksController.text.trim().isNotEmpty)
          'remarks': remarksController.text.trim(),
      });
      ref.invalidate(rawMaterialsProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${item.name} stock issued.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      }
    } finally {
      quantityController.dispose();
      remarksController.dispose();
    }
  }

  Future<void> _delete(RawMaterialModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${item.name}?'),
        content: const Text(
          'This item cannot be deleted if it is already used in a recipe or transaction.',
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
      await ref.read(apiClientProvider).deleteMaster('raw-materials', item.id);
      ref.invalidate(rawMaterialsProvider);
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

  Widget _itemTile(RawMaterialModel item) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.isLowStock
                      ? AppColors.warningTint
                      : AppColors.accentTint,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: item.isLowStock
                      ? AppColors.warning
                      : AppColors.accentDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Reorder at ${_format(item.reorderLevel)} ${item.unit}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _format(item.currentStock),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    item.unit,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              if (item.isLowStock)
                const Expanded(
                  child: Text(
                    'Low stock',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else
                const Spacer(),
              IconButton(
                tooltip: 'Add stock',
                onPressed: () => _stockIn(item),
                icon: const Icon(Icons.add_box_outlined),
              ),
              IconButton(
                tooltip: 'Issue stock',
                onPressed: () => _stockOut(item),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              IconButton(
                tooltip: 'Edit',
                onPressed: () => _startEdit(item),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: () => _delete(item),
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final materials = ref.watch(rawMaterialsProvider);
    final editing = _editingId != null;
    return FactoryShell(
      currentIndex: 4,
      title: 'Inventory',
      action: Row(
        children: [
          IconButton(
            tooltip: 'Inventory report',
            onPressed: () => context.push('/inventory/report'),
            icon: const Icon(Icons.assessment_outlined),
          ),
          IconButton(
            tooltip: 'Refresh inventory',
            onPressed: () => ref.invalidate(rawMaterialsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(rawMaterialsProvider);
          await ref.read(rawMaterialsProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Text(
              'Production materials',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 5),
            Text(
              'Manage cement, sand, and every material used by production recipes.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            FormSection(
              title: editing ? 'Edit inventory item' : 'Add inventory item',
              subtitle: editing
                  ? 'Current stock stays unchanged while you edit its details.'
                  : 'Choose a unit or enter a custom unit under Other.',
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      validator: _required,
                      decoration: const InputDecoration(
                        labelText: 'Material name',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _unit,
                      decoration: const InputDecoration(
                        labelText: 'Unit type',
                        prefixIcon: Icon(Icons.straighten_outlined),
                      ),
                      items: _units
                          .map(
                            (unit) => DropdownMenuItem(
                              value: unit,
                              child: Text(unit),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _unit = value ?? _units.first),
                    ),
                    if (_unit == 'Other') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _customUnitController,
                        validator: (value) =>
                            _unit == 'Other' ? _required(value) : null,
                        decoration: const InputDecoration(
                          labelText: 'Custom unit name',
                          prefixIcon: Icon(Icons.edit_note_outlined),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (!editing) ...[
                      TextFormField(
                        controller: _openingStockController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: _positiveNumber,
                        decoration: const InputDecoration(
                          labelText: 'Opening stock',
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _reorderLevelController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _positiveNumber,
                      decoration: const InputDecoration(
                        labelText: 'Reorder level',
                        prefixIcon: Icon(Icons.warning_amber_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (editing) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _saving ? null : _clearForm,
                              child: const Text('Cancel edit'),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: Icon(
                              editing ? Icons.save_outlined : Icons.add,
                            ),
                            label: Text(
                              _saving
                                  ? 'Saving'
                                  : editing
                                  ? 'Save changes'
                                  : 'Add material',
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
            SectionHeading(
              title: 'Inventory balance',
              action: IconButton(
                onPressed: () => ref.invalidate(rawMaterialsProvider),
                icon: const Icon(Icons.refresh),
              ),
            ),
            const SizedBox(height: 12),
            materials.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorState(
                message: apiErrorMessage(error),
                onRetry: () => ref.invalidate(rawMaterialsProvider),
              ),
              data: (items) => items.isEmpty
                  ? const EmptyState(
                      title: 'No materials yet',
                      message:
                          'Add cement, sand, or another production material above.',
                    )
                  : Column(children: items.map(_itemTile).toList()),
            ),
          ],
        ),
      ),
    );
  }
}
