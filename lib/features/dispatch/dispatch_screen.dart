import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_widgets.dart';

class DispatchFormScreen extends ConsumerStatefulWidget {
  const DispatchFormScreen({this.entry, super.key});

  final DispatchRecord? entry;

  @override
  ConsumerState<DispatchFormScreen> createState() => _DispatchFormState();
}

class _DispatchLine {
  _DispatchLine({this.brickTypeId, this.designId, String? quantity})
      : qtyCtrl = TextEditingController(text: quantity ?? '');

  int? brickTypeId;
  int? designId;
  final TextEditingController qtyCtrl;

  void dispose() => qtyCtrl.dispose();
}

class _DispatchFormState extends ConsumerState<DispatchFormScreen> {
  final _freightController = TextEditingController();
  final _collectedController = TextEditingController();
  final List<_DispatchLine> _lines = [];
  int? _partyId;
  int? _vehicleId;
  int? _driverId;
  String? _paymentMode;
  bool _markPaid = false;
  bool _saving = false;
  bool _refreshing = false;

  bool get editing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _partyId = entry?.partyId == 0 ? null : entry?.partyId;
    _vehicleId = entry?.vehicleId == 0 ? null : entry?.vehicleId;
    _driverId = entry?.driverId;
    _freightController.text = entry?.freightAmount?.toString() ?? '';
    _paymentMode = entry?.paymentMode;
    _markPaid = entry?.paymentStatus == 'paid';
    if (entry != null && entry.items.isNotEmpty) {
      for (final item in entry.items) {
        _lines.add(
          _DispatchLine(
            brickTypeId: item.brickTypeId == 0 ? null : item.brickTypeId,
            designId: item.designId,
            quantity: '${item.quantity}',
          ),
        );
      }
    } else {
      _lines.add(
        _DispatchLine(
          brickTypeId: entry?.brickTypeId == 0 ? null : entry?.brickTypeId,
          designId: entry?.designId,
          quantity: entry != null ? '${entry.quantity}' : null,
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    _freightController.dispose();
    _collectedController.dispose();
    super.dispose();
  }

  Future<void> _refreshMasters() async {
    setState(() => _refreshing = true);
    ref.invalidate(brickTypesProvider);
    ref.invalidate(designsProvider);
    ref.invalidate(partiesProvider);
    ref.invalidate(vehiclesProvider);
    ref.invalidate(driversProvider);
    await Future.wait([
      ref.read(brickTypesProvider.future),
      ref.read(designsProvider.future),
      ref.read(partiesProvider.future),
      ref.read(vehiclesProvider.future),
      ref.read(driversProvider.future),
    ]);
    if (mounted) {
      setState(() => _refreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispatch master lists refreshed.')),
      );
    }
  }

  Future<void> _save() async {
    final freight = double.tryParse(_freightController.text.trim()) ?? 0;
    final collected = double.tryParse(_collectedController.text.trim()) ?? 0;
    final bricks = ref.read(brickTypesProvider).asData?.value ?? [];
    final stockOf = (int? id) => bricks
        .where((b) => b.id == id)
        .firstOrNull
        ?.currentStock;
    final items = <Map<String, dynamic>>[];
    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      final qty = int.tryParse(line.qtyCtrl.text.trim());
      if (line.brickTypeId == null || qty == null || qty < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Item ${i + 1}: choose a product and a valid quantity.',
            ),
          ),
        );
        return;
      }
      if (!editing) {
        final stock = stockOf(line.brickTypeId);
        if (stock != null && qty > stock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Item ${i + 1}: only $stock pcs in stock.',
              ),
            ),
          );
          return;
        }
      }
      items.add({
        'brick_type_id': line.brickTypeId,
        if (line.designId != null) 'design_id': line.designId,
        'quantity': qty,
      });
    }
    if (_partyId == null || _vehicleId == null || freight < 0 || collected < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choose party, vehicle, and valid freight and collection.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final total = items.fold<int>(
      0,
      (sum, item) => sum + (item['quantity'] as int),
    );
    final payload = {
      'dispatch_date':
          widget.entry?.date ??
          DateTime.now().toIso8601String().substring(0, 10),
      'items': items,
      // Legacy-compatible header mirrors the first line.
      'brick_type_id': items.first['brick_type_id'],
      if (items.first['design_id'] != null)
        'design_id': items.first['design_id'],
      'quantity_loaded': total,
      'party_id': _partyId,
      'vehicle_id': _vehicleId,
      'driver_id': _driverId,
      'freight_amount': freight,
      if (!editing && collected > 0) 'collected_amount': collected,
      if (editing) 'mark_paid': _markPaid,
      if (_paymentMode != null) 'payment_mode': _paymentMode,
    };
    try {
      if (editing) {
        await ref
            .read(apiClientProvider)
            .updateDispatch(widget.entry!.id, payload);
      } else {
        await ref.read(apiClientProvider).createDispatch(payload);
      }
      if (mounted) {
        ref.invalidate(dashboardProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(editing ? 'Dispatch updated.' : 'Dispatch saved.'),
          ),
        );
        Navigator.pop(context);
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

  Widget _rawDropdown(
    String label,
    int? value,
    List<Map<String, dynamic>> items,
    String field,
    IconData icon,
    ValueChanged<int?> onChanged,
  ) => DropdownButtonFormField<int>(
    initialValue: value,
    decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    items: items
        .map(
          (item) => DropdownMenuItem(
            value: item['id'] as int,
            child: Text(item[field]?.toString() ?? 'Unnamed'),
          ),
        )
        .toList(),
    onChanged: onChanged,
  );

  @override
  Widget build(BuildContext context) {
    final bricks = ref.watch(brickTypesProvider);
    final designs = ref.watch(designsProvider);
    final parties = ref.watch(partiesProvider);
    final vehicles = ref.watch(vehiclesProvider);
    final drivers = ref.watch(driversProvider);
    final totalQty = _lines.fold<int>(
      0,
      (sum, line) => sum + (int.tryParse(line.qtyCtrl.text.trim()) ?? 0),
    );
    final lockedPaid = editing && widget.entry?.paymentStatus == 'paid';
    return FactoryShell(
      currentIndex: 2,
      title: editing ? 'Edit load' : 'Create load',
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
              editing ? 'Edit dispatch load' : 'Create dispatch load',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 5),
            Text(
              'Add one or more products to a single load. Stock is shown under each product.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            FormSection(
              title: 'Items · $totalQty pcs',
              subtitle: editing
                  ? 'Stock and freight payment records are safely recalculated.'
                  : 'Finished stock updates when the load is saved.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...List.generate(_lines.length, (index) {
                    final line = _lines[index];
                    return _LineCard(
                      index: index,
                      line: line,
                      bricks: bricks,
                      designs: designs,
                      canRemove: _lines.length > 1,
                      onChanged: () => setState(() {}),
                      onRemove: () => setState(() {
                        line.dispose();
                        _lines.removeAt(index);
                      }),
                    );
                  }),
                  OutlinedButton.icon(
                    onPressed: () => setState(
                      () => _lines.add(_DispatchLine()),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add item'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FormSection(
              title: 'Shipment details',
              subtitle:
                  'Link the load to live party, vehicle, and driver masters.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  parties.when(
                    loading: () => const MasterPickerLoading(
                      label: 'parties',
                      icon: Icons.storefront_outlined,
                    ),
                    error: (error, _) => ErrorState(
                      message:
                          'Parties are unavailable. Add or refresh a party from Profile.',
                      onRetry: () => ref.invalidate(partiesProvider),
                    ),
                    data: (items) => _rawDropdown(
                      'Receiving party',
                      _partyId,
                      items,
                      'name',
                      Icons.storefront_outlined,
                      (value) => setState(() => _partyId = value),
                    ),
                  ),
                  const SizedBox(height: 14),
                  vehicles.when(
                    loading: () => const MasterPickerLoading(
                      label: 'vehicles',
                      icon: Icons.local_shipping_outlined,
                    ),
                    error: (error, _) => ErrorState(
                      message:
                          'Vehicles are unavailable. Add or refresh a vehicle from Profile.',
                      onRetry: () => ref.invalidate(vehiclesProvider),
                    ),
                    data: (items) => _rawDropdown(
                      'Vehicle',
                      _vehicleId,
                      items,
                      'registration_number',
                      Icons.local_shipping_outlined,
                      (value) => setState(() => _vehicleId = value),
                    ),
                  ),
                  const SizedBox(height: 14),
                  drivers.when(
                    loading: () => const MasterPickerLoading(
                      label: 'drivers',
                      icon: Icons.badge_outlined,
                    ),
                    error: (error, _) => ErrorState(
                      message:
                          'Drivers are unavailable. Add or refresh a driver from Profile.',
                      onRetry: () => ref.invalidate(driversProvider),
                    ),
                    data: (items) => _rawDropdown(
                      'Driver (optional)',
                      _driverId,
                      items,
                      'name',
                      Icons.badge_outlined,
                      (value) => setState(() => _driverId = value),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _freightController,
                    keyboardType: TextInputType.number,
                    enabled: !editing,
                    decoration: const InputDecoration(
                      labelText: 'Freight amount',
                      prefixText: '₹ ',
                      prefixIcon: Icon(Icons.currency_rupee_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!editing)
                    TextField(
                      controller: _collectedController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Collected on delivery',
                        prefixText: '₹ ',
                        helperText: 'Books straight into receipts (oldest dues first)',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                    ),
                  if (!editing) const SizedBox(height: 14),
                  DropdownButtonFormField<String?>(
                    initialValue: _paymentMode,
                    decoration: const InputDecoration(
                      labelText: 'Collection mode',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'online', child: Text('Online')),
                    ],
                    onChanged: lockedPaid
                        ? null
                        : (value) => setState(() => _paymentMode = value),
                  ),
                  if (editing)
                    Builder(
                      builder: (context) {
                        final entry = widget.entry;
                        final freight = double.tryParse(
                              _freightController.text.trim(),
                            ) ??
                            (entry?.freightAmount ?? 0);
                        final recorded = entry?.allocPaid ?? 0;
                        final flaggedPaid = entry?.paymentStatus == 'paid';
                        if (freight <= 0) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'No freight on this load — marking paid only updates the status.',
                            ),
                          );
                        }
                        if (!flaggedPaid && recorded >= freight) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Already fully covered by payment records — no need to mark paid.',
                            ),
                          );
                        }
                        final due = (freight - recorded) < 0
                            ? 0.0
                            : freight - recorded;
                        final locked = flaggedPaid;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  locked
                                      ? 'Mark as paid (locked)'
                                      : 'Mark as paid',
                                ),
                                subtitle: Text(
                                  'Freight ₹ $freight · recorded paid ₹ $recorded · due ₹ $due',
                                ),
                                value: _markPaid,
                                enabled: !locked,
                                onChanged: locked
                                    ? null
                                    : (value) => setState(
                                          () => _markPaid = value ?? false,
                                        ),
                              ),
                              if (locked)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFBEB),
                                    border: Border.all(
                                      color: const Color(0xFFFDE68A),
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'This load is marked paid — payment details (status, freight, mode) are locked. Later edits never touch payments; only other details remain editable. To adjust money, use Payments (Receive).',
                                    style: TextStyle(
                                      color: Color(0xFF92400E),
                                      fontSize: 12,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              if (!locked && _markPaid)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFBEB),
                                    border: Border.all(
                                      color: const Color(0xFFFDE68A),
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    due > 0
                                        ? 'Saving will create a payment record of ₹$due for this load (remarks ‘reconciled’), visible under Payments. Partial dues work the same — only the pending amount is recorded. Once paid, later edits won\u2019t touch payments.'
                                        : 'Nothing is due on this load (old data) — only the status is updated, no payment data is changed.',
                                    style: const TextStyle(
                                      color: Color(0xFF92400E),
                                      fontSize: 12,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  if (editing)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Money changes for saved loads go through Dispatch Due → Receive.',
                      ),
                    ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(
                      editing ? 'Update dispatch load' : 'Save dispatch load',
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

class _LineCard extends ConsumerWidget {
  const _LineCard({
    required this.index,
    required this.line,
    required this.bricks,
    required this.designs,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _DispatchLine line;
  final AsyncValue<List<BrickTypeModel>> bricks;
  final AsyncValue<List<DesignModel>> designs;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedBrick = bricks.asData?.value
        .where((item) => item.id == line.brickTypeId)
        .firstOrNull;
    final showDesign = selectedBrick?.isPaver ?? false;
    final stock = selectedBrick?.currentStock;
    final qty = int.tryParse(line.qtyCtrl.text.trim());
    final over = stock != null && qty != null && qty > stock;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Item ${index + 1}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                if (canRemove)
                  TextButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Remove'),
                  ),
              ],
            ),
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
                initialValue: line.brickTypeId,
                decoration: const InputDecoration(
                  labelText: 'Product',
                  prefixIcon: Icon(Icons.view_module_outlined),
                ),
                items: items
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(
                          '${item.name} · ${item.currentStock} in stock',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  line.brickTypeId = value;
                  line.designId = null;
                  onChanged();
                },
              ),
            ),
            if (line.brickTypeId != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  stock == null
                      ? 'Current stock: —'
                      : 'Current stock: $stock pcs',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: over ? Colors.red : AppColors.muted,
                    fontWeight: over ? FontWeight.w700 : null,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: line.qtyCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                labelText: 'Quantity',
                suffixText: 'PCS',
                prefixIcon: const Icon(Icons.numbers_outlined),
                errorText: over ? 'Only $stock pcs in stock' : null,
              ),
              onChanged: (_) => onChanged(),
            ),
            if (showDesign) ...[
              const SizedBox(height: 12),
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
                  initialValue: line.designId,
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
                  onChanged: (value) {
                    line.designId = value;
                    onChanged();
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
