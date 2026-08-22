import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

import '../widgets/desk_page.dart';
import '../theme/desk_theme.dart';

enum _MasterTab { products, sizes, designs, users, parties, vehicles, drivers }

class MastersScreen extends ConsumerStatefulWidget {
  const MastersScreen({super.key});

  @override
  ConsumerState<MastersScreen> createState() => _MastersScreenState();
}

class _MastersScreenState extends ConsumerState<MastersScreen> {
  _MasterTab _tab = _MasterTab.products;
  String _search = '';

  bool get _canManageProducts =>
      ref.watch(authProvider).value?.hasPermission('products.manage') ?? false;
  bool get _canManageStaff =>
      ref.watch(authProvider).value?.hasPermission('staff.manage') ?? false;
  bool get _canManageMasters =>
      ref.watch(authProvider).value?.hasPermission('masters.manage') ?? false;

  Future<void> _openMasterRecordDialog(
    String title,
    List<({String field, String label, bool required})> fields,
    Map<String, dynamic>? item,
    String resource,
    VoidCallback onSaved,
  ) async {
    final controllers = <String, TextEditingController>{
      for (final f in fields) f.field: TextEditingController(text: item?[f.field]?.toString() ?? ''),
    };

    final saved = await _formDialog(
      title: title,
      icon: Icons.folder_outlined,
      children: [
        for (final f in fields)
          _DialogField(controller: controllers[f.field]!, label: f.label),
      ],
    );

    if (saved == null) return;
    for (final f in fields) {
      if (f.required && controllers[f.field]!.text.trim().isEmpty) {
        _toast('${f.label} is required.', error: true);
        return;
      }
    }

    final payload = <String, dynamic>{
      for (final f in fields)
        f.field: controllers[f.field]!.text.trim(),
    };
    try {
      final api = ref.read(apiClientProvider);
      if (item == null) {
        await api.createMaster(resource, payload);
      } else {
        await api.updateMaster(resource, item['id'] as int, payload);
      }
      onSaved();
    } catch (e) {
      _toast(apiErrorMessage(e), error: true);
    }
  }

  Future<void> _openPartyDialog([Map<String, dynamic>? item]) => _openMasterRecordDialog(
    item == null ? 'New party' : 'Edit party',
    const [
      (field: 'name', label: 'Name', required: true),
      (field: 'mobile', label: 'Mobile', required: false),
      (field: 'address', label: 'Address', required: false),
    ],
    item,
    'parties',
    () {
      ref.invalidate(partiesProvider);
      _toast(item == null ? 'Party created.' : 'Party updated.');
    },
  );

  Future<void> _openVehicleDialog([Map<String, dynamic>? item]) => _openMasterRecordDialog(
    item == null ? 'New vehicle' : 'Edit vehicle',
    const [
      (field: 'registration_number', label: 'Registration number', required: true),
      (field: 'type', label: 'Type', required: false),
    ],
    item,
    'vehicles',
    () {
      ref.invalidate(vehiclesProvider);
      _toast(item == null ? 'Vehicle created.' : 'Vehicle updated.');
    },
  );

  Future<void> _openDriverDialog([Map<String, dynamic>? item]) => _openMasterRecordDialog(
    item == null ? 'New driver' : 'Edit driver',
    const [
      (field: 'name', label: 'Name', required: true),
      (field: 'mobile', label: 'Mobile', required: false),
      (field: 'license_number', label: 'License number', required: false),
    ],
    item,
    'drivers',
    () {
      ref.invalidate(driversProvider);
      _toast(item == null ? 'Driver created.' : 'Driver updated.');
    },
  );

  Future<void> _openBrickSizeDialog([Map<String, dynamic>? item]) async {
    final nameCtrl = TextEditingController(text: item?['name']?.toString() ?? '');
    final orderCtrl =
        TextEditingController(text: item?['sort_order']?.toString() ?? '0');
    bool isActive = item?['is_active'] as bool? ?? true;

    final saved = await _formDialog(
      title: item == null ? 'New thickness / size' : 'Edit thickness / size',
      icon: Icons.straighten_outlined,
      children: [
        _DialogField(controller: nameCtrl, label: 'Size / Thickness', hint: 'e.g. 60mm'),
        _DialogField(controller: orderCtrl, label: 'Sort order', numeric: true),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Active'),
          value: isActive,
          onChanged: (val) => isActive = val,
        ),
      ],
    );

    if (saved == null) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      _toast('Size name is required.', error: true);
      return;
    }
    final payload = <String, dynamic>{
      'name': name,
      'sort_order': int.tryParse(orderCtrl.text.trim()) ?? 0,
      'is_active': isActive,
    };
    try {
      final api = ref.read(apiClientProvider);
      if (item == null) {
        await api.createBrickSize(payload);
      } else {
        await api.updateBrickSize((item['id'] as num).toInt(), payload);
      }
      ref.invalidate(brickSizesProvider);
      _toast(item == null ? 'Size created.' : 'Size updated.');
    } catch (e) {
      _toast(apiErrorMessage(e), error: true);
    }
  }

  Future<void> _openBrickTypeDialog([BrickTypeModel? item]) async {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final codeCtrl = TextEditingController(text: item?.code ?? '');
    final stockCtrl =
        TextEditingController(text: item != null ? '${item.currentStock}' : '0');
    final reorderCtrl =
        TextEditingController(text: item != null ? '${item.reorderLevel}' : '500');

    final sizes = await ref.read(brickSizesProvider.future);
    String? size = item?.size;
    bool isPaver = item?.isPaver ?? false;

    final saved = await _formDialog(
      title: item == null ? 'New brick type' : 'Edit brick type',
      icon: Icons.view_module_outlined,
      children: [
        _DialogField(controller: nameCtrl, label: 'Name', hint: 'e.g. Fly Ash Brick 9x4x3'),
        Row(
          children: [
            Expanded(child: _DialogField(controller: codeCtrl, label: 'Code', hint: 'FA-943')),
            const SizedBox(width: 12),
            Expanded(
              child: StatefulBuilder(
                builder: (ctx, setInner) => DropdownButtonFormField<String>(
                  initialValue: size,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Size / Thickness (Optional)',
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('None'),
                    ),
                    ...sizes.map((s) => DropdownMenuItem<String>(
                          value: s['name']?.toString() ?? '',
                          child: Text(s['name']?.toString() ?? ''),
                        )),
                  ],
                  onChanged: (val) => setInner(() => size = val),
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(child: _DialogField(controller: stockCtrl, label: 'Current stock (pcs)', numeric: true)),
            const SizedBox(width: 12),
            Expanded(child: _DialogField(controller: reorderCtrl, label: 'Reorder level', numeric: true)),
          ],
        ),
        StatefulBuilder(
          builder: (ctx, setInner) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Paver block'),
            value: isPaver,
            onChanged: (val) => setInner(() => isPaver = val),
          ),
        ),
      ],
    );

    if (saved == null) return;
    final name = nameCtrl.text.trim();
    final code = codeCtrl.text.trim();
    if (name.isEmpty || code.isEmpty) {
      _toast('Name and code are required.', error: true);
      return;
    }
    final payload = <String, dynamic>{
      'name': name,
      'code': code,
      'is_paver': isPaver,
      'reorder_level': int.tryParse(reorderCtrl.text.trim()) ?? 0,
      if (size != null && size!.isNotEmpty) 'size': size else 'size': null,
    };
    try {
      final api = ref.read(apiClientProvider);
      if (item == null) {
        payload['current_stock'] = int.tryParse(stockCtrl.text.trim()) ?? 0;
        await api.createMaster('brick-types', payload);
      } else {
        await api.updateMaster('brick-types', item.id, payload);
      }
      ref.invalidate(brickTypesProvider);
      _toast(item == null ? 'Brick type created.' : 'Brick type updated.');
    } catch (e) {
      _toast(apiErrorMessage(e), error: true);
    }
  }

  Future<void> _openDesignDialog([DesignModel? item]) async {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final colorsCtrl =
        TextEditingController(text: item != null ? item.colors.join(', ') : 'Grey, Red');
    final sizes = await ref.read(brickSizesProvider.future);
    String size = item?.size ?? (sizes.isEmpty ? '' : sizes.first['name']?.toString() ?? '');
    bool isActive = item?.isActive ?? true;

    final saved = await _formDialog(
      title: item == null ? 'New paver design' : 'Edit paver design',
      icon: Icons.texture_outlined,
      children: [
        _DialogField(controller: nameCtrl, label: 'Design pattern', hint: 'e.g. Zigzag, I-Shape'),
        StatefulBuilder(
          builder: (ctx, setInner) => DropdownButtonFormField<String>(
            initialValue: size,
            decoration: const InputDecoration(labelText: 'Thickness / Size'),
            items: sizes
                .map((s) => DropdownMenuItem(
                      value: s['name']?.toString() ?? '',
                      child: Text(s['name']?.toString() ?? ''),
                    ))
                .toList(),
            onChanged: (val) => setInner(() => size = val ?? ''),
          ),
        ),
        _DialogField(controller: colorsCtrl, label: 'Available colors', hint: 'Comma separated'),
        StatefulBuilder(
          builder: (ctx, setInner) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Active'),
            value: isActive,
            onChanged: (val) => setInner(() => isActive = val),
          ),
        ),
      ],
    );

    if (saved == null) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty || size.isEmpty) {
      _toast('Design name and thickness are required.', error: true);
      return;
    }
    final colors = colorsCtrl.text
        .split(',')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
    final payload = {'name': name, 'size': size, 'colors': colors, 'is_active': isActive};
    try {
      final api = ref.read(apiClientProvider);
      if (item == null) {
        await api.createDesign(payload);
      } else {
        await api.updateDesign(item.id, payload);
      }
      ref.invalidate(designsProvider);
      _toast(item == null ? 'Design created.' : 'Design updated.');
    } catch (e) {
      _toast(apiErrorMessage(e), error: true);
    }
  }

  Future<void> _openUserDialog([Map<String, dynamic>? user]) async {
    final roles = await ref.read(rolesProvider.future);
    int? roleId = user?['role'] is Map
        ? (user?['role']['id'] as num?)?.toInt()
        : roles.firstOrNull?['id'] as int?;
    final nameCtrl = TextEditingController(text: user?['name']?.toString() ?? '');
    final mobileCtrl = TextEditingController(text: user?['mobile']?.toString() ?? '');
    final emailCtrl = TextEditingController(text: user?['email']?.toString() ?? '');
    final passwordCtrl = TextEditingController();

    final saved = await _formDialog(
      title: user == null ? 'New user' : 'Edit user',
      icon: Icons.person_outline,
      children: [
        _DialogField(controller: nameCtrl, label: 'Full name'),
        _DialogField(controller: mobileCtrl, label: 'Mobile (login ID)', numeric: true),
        _DialogField(controller: emailCtrl, label: 'Email (optional)'),
        StatefulBuilder(
          builder: (ctx, setInner) => DropdownButtonFormField<int>(
            initialValue: roleId,
            decoration: const InputDecoration(labelText: 'Role'),
            items: roles
                .map((r) => DropdownMenuItem(
                      value: (r['id'] as num).toInt(),
                      child: Text(r['name'].toString()),
                    ))
                .toList(),
            onChanged: (val) => setInner(() => roleId = val),
          ),
        ),
        _DialogField(
          controller: passwordCtrl,
          label: user == null ? 'Password' : 'New password (leave blank to keep)',
          obscure: true,
        ),
      ],
    );

    if (saved == null) return;
    final name = nameCtrl.text.trim();
    final mobile = mobileCtrl.text.trim();
    if (name.isEmpty || mobile.isEmpty || roleId == null) {
      _toast('Name, mobile, and role are required.', error: true);
      return;
    }
    final password = passwordCtrl.text.trim();
    if (user == null && password.length < 6) {
      _toast('Password must be at least 6 characters.', error: true);
      return;
    }
    final payload = <String, dynamic>{
      'name': name,
      'mobile': mobile,
      if (emailCtrl.text.trim().isNotEmpty) 'email': emailCtrl.text.trim(),
      'role_id': roleId,
      if (password.isNotEmpty) 'password': password,
    };
    try {
      final api = ref.read(apiClientProvider);
      if (user == null) {
        await api.createStaff(payload);
      } else {
        await api.updateStaff((user['id'] as num).toInt(), payload);
      }
      ref.invalidate(staffProvider);
      _toast(user == null ? 'User created.' : 'User updated.');
    } catch (e) {
      _toast(apiErrorMessage(e), error: true);
    }
  }

  Future<void> _confirmDelete({
    required String title,
    required String message,
    required Future<void> Function() action,
    required VoidCallback onDone,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: DeskColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await action();
      onDone();
      _toast('$title done.');
    } catch (e) {
      _toast(apiErrorMessage(e), error: true);
    }
  }

  Future<bool?> _formDialog({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: DeskColors.primaryTint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: DeskColors.primary),
            ),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontSize: 17)),
          ],
        ),
        content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final child in children) ...[child, const SizedBox(height: 12)]]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogCtx, true), child: const Text('Save')),
        ],
      ),
    );
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? DeskColors.danger : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DeskPage(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Master data', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 4),
            Text(
              'Products, design patterns, and user accounts used across the factory',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: DeskColors.muted),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 220,
                      child: Container(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? DeskColors.canvasDark
                            : const Color(0xFFFAFBFC),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                              child: TextField(
                                onChanged: (v) => setState(() => _search = v.toLowerCase()),
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Search…',
                                  prefixIcon: const Icon(Icons.search, size: 17),
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            _CategoryTile(
                              selected: _tab == _MasterTab.products,
                              icon: Icons.view_module_outlined,
                              title: 'Products',
                              subtitle: 'Brick types & sizes',
                              onTap: () => setState(() => _tab = _MasterTab.products),
                            ),
                            _CategoryTile(
                              selected: _tab == _MasterTab.sizes,
                              icon: Icons.straighten_outlined,
                              title: 'Thickness / Sizes',
                              subtitle: 'Selectable sizes',
                              onTap: () => setState(() => _tab = _MasterTab.sizes),
                            ),
                            _CategoryTile(
                              selected: _tab == _MasterTab.designs,
                              icon: Icons.texture_outlined,
                              title: 'Design patterns',
                              subtitle: 'Paver patterns & colors',
                              onTap: () => setState(() => _tab = _MasterTab.designs),
                            ),
                            const Divider(height: 8),
                            _CategoryTile(
                              selected: _tab == _MasterTab.parties,
                              icon: Icons.storefront_outlined,
                              title: 'Parties',
                              subtitle: 'Dispatch buyers',
                              onTap: () => setState(() => _tab = _MasterTab.parties),
                            ),
                            _CategoryTile(
                              selected: _tab == _MasterTab.vehicles,
                              icon: Icons.local_shipping_outlined,
                              title: 'Vehicles',
                              subtitle: 'Dispatch vehicles',
                              onTap: () => setState(() => _tab = _MasterTab.vehicles),
                            ),
                            _CategoryTile(
                              selected: _tab == _MasterTab.drivers,
                              icon: Icons.badge_outlined,
                              title: 'Drivers',
                              subtitle: 'Dispatch drivers',
                              onTap: () => setState(() => _tab = _MasterTab.drivers),
                            ),
                            const Divider(height: 8),
                            _CategoryTile(
                              enabled: _canManageStaff,
                              selected: _tab == _MasterTab.users,
                              icon: Icons.person_outline,
                              title: 'Users',
                              subtitle: 'Accounts & roles',
                              onTap: () => setState(() => _tab = _MasterTab.users),
                            ),
                          ],
                        ),
                      ),
                    ),
                    VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
                    Expanded(
                      child: switch (_tab) {
                        _MasterTab.products => _buildProducts(),
                        _MasterTab.sizes => _buildSizes(),
                        _MasterTab.designs => _buildDesigns(),
                        _MasterTab.users => _canManageStaff
                            ? _buildUsers()
                            : const Center(child: Text('You do not have permission to manage users.')),
                        _MasterTab.parties => _buildParties(),
                        _MasterTab.vehicles => _buildVehicles(),
                        _MasterTab.drivers => _buildDrivers(),
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerBar(String title, String countLabel, {required VoidCallback onAdd, required String addLabel, required bool canAdd}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: DeskColors.primaryTint,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(countLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: DeskColors.primary)),
          ),
          const Spacer(),
          if (canAdd)
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 15),
              label: Text(addLabel),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
            ),
        ],
      ),
    );
  }

  Widget _buildProducts() {
    final bricks = ref.watch(brickTypesProvider);
    return bricks.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(apiErrorMessage(error))),
      data: (items) {
        final filtered = items
            .where((b) => _search.isEmpty || b.name.toLowerCase().contains(_search) || b.code.toLowerCase().contains(_search))
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerBar(
              'Products',
              '${filtered.length} of ${items.length}',
              onAdd: () => _openBrickTypeDialog(),
              addLabel: 'New product',
              canAdd: _canManageProducts,
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 28,
                  columns: const [
                    DataColumn(label: Text('PRODUCT')),
                    DataColumn(label: Text('CODE')),
                    DataColumn(label: Text('SIZE / THICKNESS')),
                    DataColumn(label: Text('KIND')),
                    DataColumn(label: Text('STOCK'), numeric: true),
                    DataColumn(label: Text('')),
                  ],
                  rows: filtered.map((b) => DataRow(cells: [
                    DataCell(Text(b.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(b.code)),
                    DataCell(b.size == null || b.size!.isEmpty
                        ? const Text('—')
                        : Chip(
                            label: Text(b.size!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: DeskColors.primaryTint,
                            side: BorderSide.none,
                          )),
                    DataCell(Text(b.isPaver ? 'Paver' : 'Fly ash')),
                    DataCell(Text('${b.currentStock} pcs', style: const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_canManageProducts) ...[
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          onPressed: () => _openBrickTypeDialog(b),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline, size: 16, color: DeskColors.danger),
                          onPressed: () => _confirmDelete(
                            title: 'Delete ${b.name}?',
                            message: 'Products used in production or dispatch cannot be deleted.',
                            action: () => ref.read(apiClientProvider).deleteMaster('brick-types', b.id),
                            onDone: () => ref.invalidate(brickTypesProvider),
                          ),
                        ),
                      ],
                    ])),
                  ])).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSizes() {
    final sizes = ref.watch(brickSizesProvider);
    return sizes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(apiErrorMessage(error))),
      data: (items) {
        final filtered = items
            .where((s) => _search.isEmpty || s['name'].toString().toLowerCase().contains(_search))
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerBar(
              'Thickness / Sizes',
              '${filtered.length} of ${items.length}',
              onAdd: () => _openBrickSizeDialog(),
              addLabel: 'New size',
              canAdd: _canManageProducts,
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 28,
                  columns: const [
                    DataColumn(label: Text('SIZE / THICKNESS')),
                    DataColumn(label: Text('SORT ORDER'), numeric: true),
                    DataColumn(label: Text('STATUS')),
                    DataColumn(label: Text('')),
                  ],
                  rows: filtered.map((s) => DataRow(cells: [
                    DataCell(Text(s['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(s['sort_order'].toString())),
                    DataCell(Chip(
                      label: Text(s['is_active'] == true ? 'Active' : 'Inactive', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: s['is_active'] == true
                          ? const Color(0xFFE7F6EC)
                          : const Color(0xFFF1F2F4),
                      side: BorderSide.none,
                    )),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_canManageProducts) ...[
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          onPressed: () => _openBrickSizeDialog(s),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline, size: 16, color: DeskColors.danger),
                          onPressed: () => _confirmDelete(
                            title: 'Delete ${s['name']}?',
                            message: 'Sizes already assigned to products or designs will show as removed.',
                            action: () => ref.read(apiClientProvider).deleteBrickSize((s['id'] as num).toInt()),
                            onDone: () => ref.invalidate(brickSizesProvider),
                          ),
                        ),
                      ],
                    ])),
                  ])).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDesigns() {
    final designs = ref.watch(designsProvider);
    return designs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(apiErrorMessage(error))),
      data: (items) {
        final filtered = items.where((d) => _search.isEmpty || d.name.toLowerCase().contains(_search)).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerBar(
              'Design patterns',
              '${filtered.length} of ${items.length}',
              onAdd: () => _openDesignDialog(),
              addLabel: 'New design',
              canAdd: _canManageProducts,
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 28,
                  columns: const [
                    DataColumn(label: Text('PATTERN')),
                    DataColumn(label: Text('THICKNESS')),
                    DataColumn(label: Text('COLORS')),
                    DataColumn(label: Text('')),
                  ],
                  rows: filtered.map((d) => DataRow(cells: [
                    DataCell(Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Chip(
                      label: Text(d.size, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: DeskColors.primaryTint,
                      side: BorderSide.none,
                    )),
                    DataCell(SizedBox(
                      width: 260,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: d.colors.map((c) => Chip(
                          label: Text(c, style: const TextStyle(fontSize: 10)),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          side: BorderSide(color: Theme.of(context).dividerColor),
                        )).toList(),
                      ),
                    )),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_canManageProducts) ...[
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          onPressed: () => _openDesignDialog(d),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline, size: 16, color: DeskColors.danger),
                          onPressed: () => _confirmDelete(
                            title: 'Delete ${d.name}?',
                            message: 'Designs used in production entries cannot be deleted.',
                            action: () => ref.read(apiClientProvider).deleteDesign(d.id),
                            onDone: () => ref.invalidate(designsProvider),
                          ),
                        ),
                      ],
                    ])),
                  ])).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildParties() {
    final parties = ref.watch(partiesProvider);
    return parties.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(apiErrorMessage(error))),
      data: (items) {
        final filtered = items
            .where((p) => _search.isEmpty || p['name'].toString().toLowerCase().contains(_search))
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerBar(
              'Parties',
              '${filtered.length} of ${items.length}',
              onAdd: () => _openPartyDialog(),
              addLabel: 'New party',
              canAdd: _canManageMasters,
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 28,
                  columns: const [
                    DataColumn(label: Text('NAME')),
                    DataColumn(label: Text('MOBILE')),
                    DataColumn(label: Text('ADDRESS')),
                    DataColumn(label: Text('')),
                  ],
                  rows: filtered.map((p) => DataRow(cells: [
                    DataCell(Text(p['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(p['mobile']?.toString() ?? '—')),
                    DataCell(Text(p['address']?.toString() ?? '—')),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_canManageMasters) ...[
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          onPressed: () => _openPartyDialog(p),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline, size: 16, color: DeskColors.danger),
                          onPressed: () => _confirmDelete(
                            title: 'Delete ${p['name']}?',
                            message: 'Parties used in dispatches cannot be deleted.',
                            action: () => ref.read(apiClientProvider).deleteMaster('parties', (p['id'] as num).toInt()),
                            onDone: () => ref.invalidate(partiesProvider),
                          ),
                        ),
                      ],
                    ])),
                  ])).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVehicles() {
    final vehicles = ref.watch(vehiclesProvider);
    return vehicles.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(apiErrorMessage(error))),
      data: (items) {
        final filtered = items
            .where((v) => _search.isEmpty || v['registration_number'].toString().toLowerCase().contains(_search))
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerBar(
              'Vehicles',
              '${filtered.length} of ${items.length}',
              onAdd: () => _openVehicleDialog(),
              addLabel: 'New vehicle',
              canAdd: _canManageMasters,
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 28,
                  columns: const [
                    DataColumn(label: Text('REGISTRATION')),
                    DataColumn(label: Text('TYPE')),
                    DataColumn(label: Text('')),
                  ],
                  rows: filtered.map((v) => DataRow(cells: [
                    DataCell(Text(v['registration_number']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(v['type']?.toString() ?? '—')),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_canManageMasters) ...[
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          onPressed: () => _openVehicleDialog(v),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline, size: 16, color: DeskColors.danger),
                          onPressed: () => _confirmDelete(
                            title: 'Delete ${v['registration_number']}?',
                            message: 'Vehicles used in dispatches cannot be deleted.',
                            action: () => ref.read(apiClientProvider).deleteMaster('vehicles', (v['id'] as num).toInt()),
                            onDone: () => ref.invalidate(vehiclesProvider),
                          ),
                        ),
                      ],
                    ])),
                  ])).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDrivers() {
    final drivers = ref.watch(driversProvider);
    return drivers.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(apiErrorMessage(error))),
      data: (items) {
        final filtered = items
            .where((d) => _search.isEmpty || d['name'].toString().toLowerCase().contains(_search))
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerBar(
              'Drivers',
              '${filtered.length} of ${items.length}',
              onAdd: () => _openDriverDialog(),
              addLabel: 'New driver',
              canAdd: _canManageMasters,
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 28,
                  columns: const [
                    DataColumn(label: Text('NAME')),
                    DataColumn(label: Text('MOBILE')),
                    DataColumn(label: Text('LICENSE')),
                    DataColumn(label: Text('')),
                  ],
                  rows: filtered.map((d) => DataRow(cells: [
                    DataCell(Text(d['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(d['mobile']?.toString() ?? '—')),
                    DataCell(Text(d['license_number']?.toString() ?? '—')),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_canManageMasters) ...[
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          onPressed: () => _openDriverDialog(d),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline, size: 16, color: DeskColors.danger),
                          onPressed: () => _confirmDelete(
                            title: 'Delete ${d['name']}?',
                            message: 'Drivers used in dispatches cannot be deleted.',
                            action: () => ref.read(apiClientProvider).deleteMaster('drivers', (d['id'] as num).toInt()),
                            onDone: () => ref.invalidate(driversProvider),
                          ),
                        ),
                      ],
                    ])),
                  ])).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUsers() {
    final staff = ref.watch(staffProvider);
    return staff.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(apiErrorMessage(error))),
      data: (users) {
        final meId = ref.watch(authProvider).value?.id;
        final filtered = users
            .where((u) => _search.isEmpty || u['name'].toString().toLowerCase().contains(_search) || u['mobile'].toString().contains(_search))
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerBar(
              'Users',
              '${filtered.length} of ${users.length}',
              onAdd: () => _openUserDialog(),
              addLabel: 'New user',
              canAdd: _canManageStaff,
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 28,
                  columns: const [
                    DataColumn(label: Text('USER')),
                    DataColumn(label: Text('MOBILE')),
                    DataColumn(label: Text('EMAIL')),
                    DataColumn(label: Text('ROLE')),
                    DataColumn(label: Text('')),
                  ],
                  rows: filtered.map((u) {
                    final role = u['role'] as Map?;
                    final isMe = meId != null && (u['id'] as num?)?.toInt() == meId;
                    return DataRow(cells: [
                      DataCell(Row(children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: DeskColors.primaryTint,
                          child: Text(
                            u['name'].toString().substring(0, 1).toUpperCase(),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: DeskColors.primary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(child: Text(u['name'].toString(), overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                        if (isMe) ...[
                          const SizedBox(width: 6),
                          const Text('(you)', style: TextStyle(fontSize: 11, color: DeskColors.muted)),
                        ],
                      ])),
                      DataCell(Text(u['mobile'].toString())),
                      DataCell(Text(u['email']?.toString().isNotEmpty == true ? u['email'].toString() : '—')),
                      DataCell(Chip(
                        label: Text(role?['name']?.toString() ?? 'No role', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: DeskColors.primaryTint,
                        side: BorderSide.none,
                      )),
                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                        if (!_isProtectedAdmin(role)) ...[
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            onPressed: () => _openUserDialog(u),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline, size: 16, color: DeskColors.danger),
                            onPressed: isMe
                                ? null
                                : () => _confirmDelete(
                                      title: 'Delete ${u['name']}?',
                                      message: 'This staff account will lose access immediately.',
                                      action: () => ref.read(apiClientProvider).deleteStaff((u['id'] as num).toInt()),
                                      onDone: () => ref.invalidate(staffProvider),
                                    ),
                          ),
                        ],
                      ])),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _isProtectedAdmin(Map? role) => role?['name']?.toString() == 'admin';
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final accent = enabled && selected;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: accent ? DeskColors.primaryTint : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: enabled ? onTap : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              child: Row(
                children: [
                  Icon(icon, size: 17, color: accent ? DeskColors.primary : DeskColors.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent ? DeskColors.primary : null)),
                        const SizedBox(height: 1),
                        Text(subtitle, style: const TextStyle(fontSize: 10.5, color: DeskColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.controller,
    required this.label,
    this.hint,
    this.numeric = false,
    this.obscure = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool numeric;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: numeric ? TextInputType.number : null,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}
