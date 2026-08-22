import 'package:flutter/material.dart';
import 'package:core/core.dart';

class NavItem {
  const NavItem({
    required this.label,
    required this.path,
    required this.icon,
    this.permission,
    this.anyOf = const [],
  });

  final String label;
  final String path;
  final IconData icon;
  final String? permission;

  /// Alternative permissions — if the user has ANY of these, the item shows.
  final List<String> anyOf;

  bool allowedFor(UserModel? user) {
    if (permission == null && anyOf.isEmpty) return true;
    if (permission != null && (user?.hasPermission(permission!) ?? false)) {
      return true;
    }
    return anyOf.any((p) => user?.hasPermission(p) ?? false);
  }
}

const navItems = <NavItem>[
  NavItem(
    label: 'Dashboard',
    path: '/dashboard',
    icon: Icons.dashboard_outlined,
    permission: 'dashboard.view',
  ),
  NavItem(
    label: 'Production',
    path: '/production',
    icon: Icons.precision_manufacturing_outlined,
    permission: 'production.view',
  ),
  NavItem(
    label: 'Dispatch',
    path: '/dispatch',
    icon: Icons.local_shipping_outlined,
    permission: 'dispatch.view',
  ),
  NavItem(
    label: 'Stock ledger',
    path: '/ledger',
    icon: Icons.receipt_long_outlined,
    anyOf: ['reports.view', 'dispatch.view'],
  ),
  NavItem(
    label: 'Inventory',
    path: '/inventory',
    icon: Icons.inventory_2_outlined,
    permission: 'inventory.view',
  ),
  NavItem(
    label: 'Striking group',
    path: '/striking-groups',
    icon: Icons.group_work_outlined,
    permission: 'striking.view',
  ),
  NavItem(
    label: 'Loading group',
    path: '/loading-groups',
    icon: Icons.groups_2_outlined,
    permission: 'loading.view',
  ),
  NavItem(
    label: 'Reports',
    path: '/reports',
    icon: Icons.bar_chart_outlined,
    permission: 'reports.view',
  ),
  NavItem(
    label: 'Masters',
    path: '/masters',
    icon: Icons.folder_copy_outlined,
    anyOf: ['masters.view', 'products.view', 'staff.manage'],
  ),
  NavItem(
    label: 'Roles',
    path: '/roles',
    icon: Icons.admin_panel_settings_outlined,
    permission: 'roles.manage',
  ),
  NavItem(
    label: 'Settings',
    path: '/settings',
    icon: Icons.settings_outlined,
  ),
];

