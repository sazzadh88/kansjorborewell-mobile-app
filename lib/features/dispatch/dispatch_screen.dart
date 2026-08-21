import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_widgets.dart';

class DispatchFormScreen extends ConsumerStatefulWidget {
  const DispatchFormScreen({this.entry, super.key});

  final DispatchRecord? entry;

  @override
  ConsumerState<DispatchFormScreen> createState() => _DispatchFormState();
}

class _DispatchFormState extends ConsumerState<DispatchFormScreen> {
  final _quantityController = TextEditingController();
  final _freightController = TextEditingController();
  int? _brickTypeId;
  int? _partyId;
  int? _vehicleId;
  int? _driverId;
  bool _freightPaid = false;
  bool _saving = false;
  bool _refreshing = false;

  bool get editing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _brickTypeId = entry?.brickTypeId == 0 ? null : entry?.brickTypeId;
    _partyId = entry?.partyId == 0 ? null : entry?.partyId;
    _vehicleId = entry?.vehicleId == 0 ? null : entry?.vehicleId;
    _driverId = entry?.driverId;
    _quantityController.text = entry?.quantity.toString() ?? '';
    _freightController.text = entry?.freightAmount?.toString() ?? '';
    _freightPaid = entry?.freightPaid ?? false;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _freightController.dispose();
    super.dispose();
  }

  Future<void> _refreshMasters() async {
    setState(() => _refreshing = true);
    ref.invalidate(brickTypesProvider);
    ref.invalidate(partiesProvider);
    ref.invalidate(vehiclesProvider);
    ref.invalidate(driversProvider);
    await Future.wait([
      ref.read(brickTypesProvider.future),
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
    final quantity = int.tryParse(_quantityController.text.trim());
    final freight = double.tryParse(_freightController.text.trim()) ?? 0;
    if (_brickTypeId == null ||
        _partyId == null ||
        _vehicleId == null ||
        quantity == null ||
        quantity < 1 ||
        freight < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose brick, party, vehicle, and a valid quantity.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final payload = {
      'dispatch_date':
          widget.entry?.date ??
          DateTime.now().toIso8601String().substring(0, 10),
      'brick_type_id': _brickTypeId,
      'quantity_loaded': quantity,
      'party_id': _partyId,
      'vehicle_id': _vehicleId,
      'driver_id': _driverId,
      'freight_amount': freight,
      'freight_paid': _freightPaid,
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
    final parties = ref.watch(partiesProvider);
    final vehicles = ref.watch(vehiclesProvider);
    final drivers = ref.watch(driversProvider);
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
              'Link the load to live party, vehicle, driver, and product masters.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            FormSection(
              title: 'Shipment details',
              subtitle: editing
                  ? 'Stock and freight payment records are safely recalculated.'
                  : 'Finished stock updates when the load is saved.',
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
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Quantity loaded',
                      suffixText: 'PCS',
                      prefixIcon: Icon(Icons.numbers_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _freightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Freight amount',
                      prefixText: '₹ ',
                      prefixIcon: Icon(Icons.currency_rupee_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    title: const Text(
                      'Freight paid immediately',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Create payment record with this dispatch',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    value: _freightPaid,
                    onChanged: (value) => setState(() => _freightPaid = value),
                  ),
                  const SizedBox(height: 20),
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
