import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
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
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty ||
        _mobile.text.trim().isEmpty ||
        _password.text.isEmpty ||
        _roleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete staff name, mobile, password, and role.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).createStaff({
        'name': _name.text.trim(),
        'mobile': _mobile.text.trim(),
        'password': _password.text,
        'role_id': _roleId,
      });
      _name.clear();
      _mobile.clear();
      _password.clear();
      ref.invalidate(staffProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Staff account created.')));
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

  Widget _personTile(Map<String, dynamic> person) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: AppCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.accentTint,
            child: Text(
              (person['name'] as String? ?? 'U').substring(0, 1).toUpperCase(),
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
                Text(
                  person['name'] as String? ?? 'Staff',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  person['mobile'] as String? ?? '',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            ((person['role'] as Map?)?['name'] as String? ?? 'staff')
                .toUpperCase(),
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );

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
            title: 'Add staff member',
            subtitle:
                'Create accounts for operators, managers, and accountants.',
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
                  decoration: const InputDecoration(
                    labelText: 'Temporary password',
                    prefixIcon: Icon(Icons.lock_outline),
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
                FilledButton.icon(
                  onPressed: _saving ? null : _create,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(
                    _saving ? 'Creating account' : 'Create staff account',
                  ),
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
