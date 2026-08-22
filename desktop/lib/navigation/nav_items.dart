import 'package:flutter/material.dart';

class NavItem {
  const NavItem({
    required this.label,
    required this.path,
    required this.icon,
    this.permission,
  });

  final String label;
  final String path;
  final IconData icon;
  final String? permission;
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
    permission: 'reports.view',
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
    permission: 'masters.view',
  ),
  NavItem(
    label: 'Roles',
    path: '/roles',
    icon: Icons.admin_panel_settings_outlined,
    permission: 'roles.manage',
  ),
];
