import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_widgets.dart';

class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _password = TextEditingController();
  int? _roleId;
  int? _editingId;
  bool _saving = false;

  bool get _editing => _editingId != null;

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _password.dispose();
    super.dispose();
  }

  void _resetForm() {
    _name.clear();
    _mobile.clear();
    _password.clear();
    setState(() {
      _editingId = null;
      _roleId = null;
    });
  }

  void _startEdit(Map<String, dynamic> person) {
    _name.text = person['name']?.toString() ?? '';
    _mobile.text = person['mobile']?.toString() ?? '';
    _password.clear();
    setState(() {
      _editingId = person['id'] as int;
      _roleId = (person['role'] as Map?)?['id'] as int?;
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final mobile = _mobile.text.trim();
    if (name.isEmpty || mobile.isEmpty || _roleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete staff name, mobile, and role.')),
      );
      return;
    }
    final password = _password.text.trim();
    if (!_editing && password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters.'),
        ),
      );
      return;
    }
    if (_editing && password.isNotEmpty && password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'name': name,
      'mobile': mobile,
      'role_id': _roleId,
      if (password.isNotEmpty) 'password': password,
    };
    try {
      final api = ref.read(apiClientProvider);
      if (_editing) {
        await api.updateStaff(_editingId!, payload);
      } else {
        await api.createStaff(payload);
      }
      _resetForm();
      ref.invalidate(staffProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editing ? 'Staff account updated.' : 'Staff account created.',
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

  Future<void> _delete(Map<String, dynamic> person) async {
    final name = person['name']?.toString() ?? 'this staff account';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete $name?'),
        content: const Text('This staff account will lose access immediately.'),
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
      await ref.read(apiClientProvider).deleteStaff(person['id'] as int);
      ref.invalidate(staffProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$name deleted.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      }
    }
  }

  bool _isAdmin(Map<String, dynamic> person) =>
      (person['role'] as Map?)?['name']?.toString() == 'admin';

  Widget _personTile(Map<String, dynamic> person) {
    final meId = ref.watch(authProvider).value?.id;
    final isMe = meId != null && (person['id'] as num?)?.toInt() == meId;
    final admin = _isAdmin(person);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.accentTint,
              child: Text(
                (person['name'] as String? ?? 'U')
                    .substring(0, 1)
                    .toUpperCase(),
                style: const TextStyle(
                  color: AppColors.accentDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          person['name'] as String? ?? 'Staff',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        const Text(
                          '(you)',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    person['mobile'] as String? ?? '',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (admin)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Text(
                  'ADMIN',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            else ...[
              IconButton(
                tooltip: 'Edit',
                onPressed: () => _startEdit(person),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: isMe ? 'You cannot delete your own account' : 'Delete',
                onPressed: isMe ? null : () => _delete(person),
                icon: Icon(
                  Icons.delete_outline,
                  color: isMe ? AppColors.muted : AppColors.danger,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(staffProvider);
    final roles = ref.watch(rolesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Staff management')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          FormSection(
            title: _editing ? 'Edit staff member' : 'Add staff member',
            subtitle: _editing
                ? 'Update this account\'s name, mobile, role, or password.'
                : 'Create accounts for operators, managers, and accountants.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _mobile,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    prefixIcon: Icon(Icons.phone_android_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: _editing
                        ? 'New password (leave blank to keep)'
                        : 'Temporary password',
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 12),
                roles.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) =>
                      Text('Roles unavailable: ${apiErrorMessage(error)}'),
                  data: (items) => DropdownButtonFormField<int>(
                    initialValue: _roleId,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    items: items
                        .map(
                          (role) => DropdownMenuItem(
                            value: role['id'] as int,
                            child: Text((role['name'] as String).toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _roleId = value),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    if (_editing) ...[
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
                        icon: Icon(
                          _editing
                              ? Icons.save_outlined
                              : Icons.person_add_alt_1,
                        ),
                        label: Text(
                          _saving
                              ? 'Saving'
                              : _editing
                              ? 'Save changes'
                              : 'Create staff account',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionHeading(title: 'Team'),
          const SizedBox(height: 12),
          staff.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ErrorState(
              message: 'Staff records are unavailable.',
              onRetry: () => ref.invalidate(staffProvider),
            ),
            data: (items) => Column(children: items.map(_personTile).toList()),
          ),
        ],
      ),
    );
  }
}
