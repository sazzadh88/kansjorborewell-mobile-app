import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

import '../widgets/desk_page.dart';
import '../theme/desk_theme.dart';

class RolesScreen extends ConsumerStatefulWidget {
  const RolesScreen({super.key});

  @override
  ConsumerState<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends ConsumerState<RolesScreen> {
  final _nameController = TextEditingController();
  bool _saving = false;
  bool _refreshing = false;
  int? _editingRoleId;
  Set<String> _draftPermissions = {};

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _startEdit(RoleModel role) {
    setState(() {
      _editingRoleId = role.id;
      _nameController.text = role.name;
      _draftPermissions = {...role.permissions};
    });
  }

  void _resetForm() {
    _nameController.clear();
    setState(() {
      _editingRoleId = null;
      _draftPermissions = {};
    });
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: Card(child: Padding(padding: EdgeInsets.all(24), child: Row(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(width: 16), Text('Loading...')])))),
      );
    }
    ref.invalidate(manageRolesProvider);
    ref.invalidate(permissionsProvider);
    try {
      await Future.wait([
        ref.read(manageRolesProvider.future),
        ref.read(permissionsProvider.future),
      ]);
    } catch (_) {}
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _refreshing = false);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim().toLowerCase();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a role name.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      if (_editingRoleId == null) {
        await api.createRole(name, _draftPermissions.toList());
      } else {
        await api.updateRole(_editingRoleId!, name);
        await api.syncRolePermissions(_editingRoleId!, _draftPermissions.toList());
      }
      _resetForm();
      ref.invalidate(manageRolesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_editingRoleId == null ? 'Role created.' : 'Role updated.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(RoleModel role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${role.name}?'),
        content: const Text('This role cannot be deleted while staff are assigned to it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: DeskColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(apiClientProvider).deleteRole(role.id);
      ref.invalidate(manageRolesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Role deleted.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(manageRolesProvider);
    final permissions = ref.watch(permissionsProvider);

    return DeskPage(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Roles & permissions', style: Theme.of(context).textTheme.displaySmall),
                      const SizedBox(height: 4),
                      Text(
                        'Admin always has full access; other roles and permissions can be configured here',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: DeskColors.muted),
                      ),
                    ],
                  ),
                ),
                _refreshing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        tooltip: 'Refresh',
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh),
                      ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Card(
                      child: roles.when(skipLoadingOnReload: true, skipLoadingOnRefresh: true, 
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (error, _) => Center(child: Text(apiErrorMessage(error))),
                        data: (items) => SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Role')),
                              DataColumn(label: Text('Staff'), numeric: true),
                              DataColumn(label: Text('Permissions'), numeric: true),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: items.map((role) {
                              final isAdmin = role.name == 'admin';
                              final isSelected = role.id == _editingRoleId;
                              return DataRow(
                                selected: isSelected,
                                cells: [
                                  DataCell(Text(role.name.toUpperCase())),
                                  DataCell(Text('${role.usersCount}')),
                                  DataCell(Text('${role.permissions.length}')),
                                  DataCell(Text(isAdmin ? 'Full access (locked)' : 'Editable')),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (!isAdmin) ...[
                                          IconButton(
                                            tooltip: 'Edit permissions',
                                            icon: const Icon(Icons.edit_outlined, size: 16),
                                            onPressed: () => _startEdit(role),
                                          ),
                                          IconButton(
                                            tooltip: 'Delete role',
                                            icon: const Icon(Icons.delete_outline, size: 16, color: DeskColors.danger),
                                            onPressed: () => _delete(role),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 380,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: permissions.when(skipLoadingOnReload: true, skipLoadingOnRefresh: true, 
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (error, _) => Center(child: Text(apiErrorMessage(error))),
                          data: (perms) {
                            final grouped = <String, List<PermissionModel>>{};
                            for (final p in perms) {
                              grouped.putIfAbsent(p.group, () => []).add(p);
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _editingRoleId == null ? 'Create Role' : 'Edit Role Permissions',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Role Name (e.g. manager, accountant)',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Granted Permissions (${_draftPermissions.length})',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Theme.of(context).dividerColor),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: ListView(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      children: [
                                        for (final group in grouped.entries) ...[
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                                            child: Text(
                                              group.key.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                          for (final p in group.value)
                                            CheckboxListTile(
                                              dense: true,
                                              visualDensity: VisualDensity.compact,
                                              title: Text(p.label, style: const TextStyle(fontSize: 12)),
                                              subtitle: Text(p.name, style: const TextStyle(fontSize: 10)),
                                              value: _draftPermissions.contains(p.name),
                                              onChanged: (val) {
                                                setState(() {
                                                  if (val == true) {
                                                    _draftPermissions.add(p.name);
                                                  } else {
                                                    _draftPermissions.remove(p.name);
                                                  }
                                                });
                                              },
                                            ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    if (_editingRoleId != null)
                                      OutlinedButton(
                                        onPressed: _resetForm,
                                        child: const Text('Cancel'),
                                      ),
                                    if (_editingRoleId != null) const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: _saving ? null : _save,
                                        child: Text(_saving ? 'Saving...' : (_editingRoleId == null ? 'Create Role' : 'Save Changes')),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
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
