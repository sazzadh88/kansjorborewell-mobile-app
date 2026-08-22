import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_widgets.dart';

class ProductionFormScreen extends ConsumerStatefulWidget {
  const ProductionFormScreen({this.entry, super.key});

  final ProductionRecord? entry;

  @override
  ConsumerState<ProductionFormScreen> createState() => _ProductionFormState();
}

class _ProductionFormState extends ConsumerState<ProductionFormScreen> {
  final _quantityController = TextEditingController();
  final _remarksController = TextEditingController();
  int? _brickTypeId;
  int? _machineId;
  int? _designId;
  bool _saving = false;
  bool _refreshing = false;

  bool get editing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _brickTypeId = entry?.brickTypeId == 0 ? null : entry?.brickTypeId;
    _machineId = entry?.machineId == 0 ? null : entry?.machineId;
    _designId = entry?.designId;
    _quantityController.text = entry?.quantity.toString() ?? '';
    _remarksController.text = entry?.remarks ?? '';
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _refreshMasters() async {
    setState(() => _refreshing = true);
    ref.invalidate(brickTypesProvider);
    ref.invalidate(machinesProvider);
    ref.invalidate(designsProvider);
    await Future.wait([
      ref.read(brickTypesProvider.future),
      ref.read(machinesProvider.future),
      ref.read(designsProvider.future),
    ]);
    if (mounted) {
      setState(() => _refreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brick and machine lists refreshed.')),
      );
    }
  }

  Future<void> _save() async {
    final quantity = int.tryParse(_quantityController.text.trim());
    if (_brickTypeId == null ||
        _machineId == null ||
        quantity == null ||
        quantity < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a brick type, machine, and valid quantity.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final payload = {
      'production_date':
          widget.entry?.date ??
          DateTime.now().toIso8601String().substring(0, 10),
      'machine_id': _machineId,
      'brick_type_id': _brickTypeId,
      if (_designId != null) 'design_id': _designId,
      'quantity_produced': quantity,
      'remarks': _remarksController.text.trim(),
    };
    try {
      if (editing) {
        await ref
            .read(apiClientProvider)
            .updateProduction(widget.entry!.id, payload);
      } else {
        await ref.read(apiClientProvider).createProduction(payload);
      }
      if (mounted) {
        ref.invalidate(dashboardProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              editing
                  ? 'Production output updated.'
                  : 'Production output saved.',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } on DioException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bricks = ref.watch(brickTypesProvider);
    final machines = ref.watch(machinesProvider);
    final designs = ref.watch(designsProvider);
    final selectedBrick = bricks.asData?.value
        .where((item) => item.id == _brickTypeId)
        .firstOrNull;
    final showDesign = selectedBrick?.isPaver ?? false;
    return FactoryShell(
      currentIndex: 1,
      title: editing ? 'Edit output' : 'Add output',
      action: IconButton(
        onPressed: _refreshing ? null : _refreshMasters,
        icon: _refreshing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.sync_rounded),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Text(
              editing ? 'Edit production output' : 'Add production output',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 5),
            Text(
              'Use live factory master data to keep the ledger accurate.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            FormSection(
              title: 'Output details',
              subtitle: editing
                  ? 'Changing this output reverses and reapplies recipe stock safely.'
                  : 'Recipe materials and finished stock update after saving.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  bricks.when(
                    loading: () => const MasterPickerLoading(
                      label: 'brick types',
                      icon: Icons.view_module_outlined,
                    ),
                    error: (error, _) => ErrorState(
                      message: 'Brick types are unavailable.',
                      onRetry: () => ref.invalidate(brickTypesProvider),
                    ),
                    data: (items) => DropdownButtonFormField<int>(
                      initialValue: _brickTypeId,
                      decoration: const InputDecoration(
                        labelText: 'Brick type',
                        prefixIcon: Icon(Icons.view_module_outlined),
                      ),
                      items: items
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _brickTypeId = value),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (showDesign)
                    designs.when(
                      loading: () => const MasterPickerLoading(
                        label: 'designs',
                        icon: Icons.design_services_outlined,
                      ),
                      error: (error, _) => ErrorState(
                        message: 'Designs are unavailable.',
                        onRetry: () => ref.invalidate(designsProvider),
                      ),
                      data: (items) => DropdownButtonFormField<int?>(
                        initialValue: _designId,
                        decoration: const InputDecoration(
                          labelText: 'Design',
                          helperText: 'Applicable to paver blocks only',
                          prefixIcon: Icon(Icons.design_services_outlined),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('None'),
                          ),
                          ...items.map(
                            (item) => DropdownMenuItem<int?>(
                              value: item.id,
                              child: Text('${item.name} · ${item.size}'),
                            ),
                          ),
                        ],
                        onChanged: (value) => setState(() => _designId = value),
                      ),
                    ),
                  const SizedBox(height: 14),
                  machines.when(
                    loading: () => const MasterPickerLoading(
                      label: 'machines',
                      icon: Icons.precision_manufacturing_outlined,
                    ),
                    error: (error, _) => ErrorState(
                      message: 'Machines are unavailable.',
                      onRetry: () => ref.invalidate(machinesProvider),
                    ),
                    data: (items) => DropdownButtonFormField<int>(
                      initialValue: _machineId,
                      decoration: const InputDecoration(
                        labelText: 'Machine',
                        prefixIcon: Icon(
                          Icons.precision_manufacturing_outlined,
                        ),
                      ),
                      items: items
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text('${item.name} · ${item.code}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _machineId = value),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Quantity produced',
                      suffixText: 'PCS',
                      prefixIcon: Icon(Icons.numbers_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _remarksController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Shift notes (optional)',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(
                      editing
                          ? 'Update production output'
                          : 'Save production output',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
