import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_widgets.dart';

class RolesScreen extends ConsumerStatefulWidget {
  const RolesScreen({super.key});

  @override
  ConsumerState<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends ConsumerState<RolesScreen> {
  final _nameController = TextEditingController();
  bool _saving = false;
  int? _editingRoleId;
  Set<String> _draftPermissions = {};

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a role name.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      if (_editingRoleId == null) {
        await api.createRole(name, _draftPermissions.toList());
      } else {
        await api.updateRole(_editingRoleId!, name);
        await api.syncRolePermissions(
          _editingRoleId!,
          _draftPermissions.toList(),
        );
      }
      _resetForm();
      ref.invalidate(manageRolesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editingRoleId == null ? 'Role created.' : 'Role updated.',
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

  Future<void> _delete(RoleModel role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${role.name}?'),
        content: const Text(
          'This role cannot be deleted while staff are assigned to it.',
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
      await ref.read(apiClientProvider).deleteRole(role.id);
      ref.invalidate(manageRolesProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${role.name} deleted.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      }
    }
  }

  Widget _permissionTile(
    List<PermissionModel> allPermissions,
    PermissionModel permission,
  ) {
    final enabled = _draftPermissions.contains(permission.name);
    return CheckboxListTile(
      value: enabled,
      onChanged: (checked) {
        setState(() {
          if (checked == true) {
            _draftPermissions.add(permission.name);
          } else {
            _draftPermissions.remove(permission.name);
          }
        });
      },
      title: Text(permission.label),
      subtitle: Text(permission.name, style: const TextStyle(fontSize: 12)),
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(manageRolesProvider);
    final permissions = ref.watch(permissionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Roles & permissions')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(manageRolesProvider);
          await ref.read(manageRolesProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            FormSection(
              title: _editingRoleId == null ? 'Add role' : 'Edit role',
              subtitle: _editingRoleId == null
                  ? 'Create a role and choose the pages and actions it can use.'
                  : 'Rename this role and adjust its permissions.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Role name',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  permissions.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => Text(
                      'Permissions unavailable: ${apiErrorMessage(error)}',
                    ),
                    data: (items) {
                      final groups = <String, List<PermissionModel>>{};
                      for (final permission in items) {
                        groups
                            .putIfAbsent(permission.group, () => [])
                            .add(permission);
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          for (final entry in groups.entries) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 2),
                              child: Text(
                                entry.key,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(color: AppColors.accent),
                              ),
                            ),
                            ...entry.value.map(
                              (p) => _permissionTile(items, p),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (_editingRoleId != null) ...[
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
                          label: Text(_saving ? 'Saving' : 'Save role'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const SectionHeading(title: 'Existing roles'),
            const SizedBox(height: 12),
            roles.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorState(
                message: 'Roles are unavailable.',
                onRetry: () => ref.invalidate(manageRolesProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    title: 'No roles',
                    message: 'Add a role above to get started.',
                  );
                }
                return Column(
                  children: items.map((role) {
                    final isAdmin = role.name == 'admin';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    role.name.toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${role.permissions.length} permissions · ${role.usersCount} staff',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isAdmin) ...[
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: () => _startEdit(role),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: () => _delete(role),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.danger,
                                ),
                              ),
                            ] else
                              const Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: Text(
                                  'Full access',
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
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
