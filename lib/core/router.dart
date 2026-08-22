import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/staff_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/dispatch/dispatch_form_screen.dart' as dispatch_form;
import '../features/dispatch/dispatch_list_screen.dart' as dispatch_list;
import '../features/production/production_form_screen.dart' as production_form;
import '../features/production/production_list_screen.dart' as production_list;
import '../features/inventory/inventory_report_screen.dart';
import '../features/inventory/inventory_screen.dart';
import '../features/groups/striking_groups_screen.dart';
import '../features/groups/loading_groups_screen.dart';
import '../features/masters/master_management_screen.dart';
import '../features/masters/brick_types_screen.dart';
import '../features/masters/brick_sizes_screen.dart';
import '../features/masters/design_patterns_screen.dart';
import '../features/admin/roles_screen.dart';
import '../features/reports/gst_report_screen.dart';
import '../features/reports/dispatch_dues_screen.dart';
import '../features/profile/profile_edit_screen.dart';
import '../features/profile/profile_screen.dart';
import 'api_client.dart';
import 'providers.dart';

/// Mirrors the backend `perm:` middleware in routes/api.php.
final Map<String, String> routePermissions = {
  '/production': 'production.view',
  '/production/new': 'production.create',
  '/dispatch': 'dispatch.view',
  '/dispatch/new': 'dispatch.create',
  '/inventory': 'inventory.view',
  '/inventory/report': 'inventory.report',
  '/striking-groups': 'striking.view',
  '/loading-groups': 'loading.view',
  '/admin/staff': 'staff.manage',
  '/admin/roles': 'roles.manage',
  '/reports/gst': 'reports.view',
  '/reports/dispatch-dues': 'dispatch.view',
  '/masters/brick-types': 'products.view',
  '/masters/brick-sizes': 'products.view',
  '/masters/design-patterns': 'products.view',
  '/masters/parties': 'masters.view',
  '/masters/vehicles': 'masters.view',
  '/masters/drivers': 'masters.view',
};

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);
  final authNotifier = ref.read(authProvider.notifier);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: _AuthRefresh(ref),
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isSplash = location == '/splash';
      final isLogin = location == '/login';

      if (!authNotifier.hasBootstrapped) {
        return isSplash ? null : '/splash';
      }
      if (auth.value == null) {
        return isLogin ? null : '/login';
      }
      if (isSplash || isLogin) return '/dashboard';

      final requiredPermission = routePermissions[location];
      if (requiredPermission != null &&
          !(auth.value!.hasPermission(requiredPermission))) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/production',
        builder: (context, state) => const production_list.ProductionScreen(),
      ),
      GoRoute(
        path: '/production/new',
        builder: (context, state) => production_form.ProductionFormScreen(
          entry: state.extra is ProductionRecord
              ? state.extra as ProductionRecord
              : null,
        ),
      ),
      GoRoute(
        path: '/dispatch',
        builder: (context, state) => const dispatch_list.DispatchScreen(),
      ),
      GoRoute(
        path: '/dispatch/new',
        builder: (context, state) => dispatch_form.DispatchFormScreen(
          entry: state.extra is DispatchRecord
              ? state.extra as DispatchRecord
              : null,
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: '/admin/staff',
        builder: (context, state) => const StaffScreen(),
      ),
      GoRoute(
        path: '/admin/roles',
        builder: (context, state) => const RolesScreen(),
      ),
      GoRoute(
        path: '/reports/gst',
        builder: (context, state) => const GstReportScreen(),
      ),
      GoRoute(
        path: '/reports/dispatch-dues',
        builder: (context, state) => const DispatchDuesScreen(),
      ),
      GoRoute(
        path: '/inventory',
        builder: (context, state) => const InventoryScreen(),
      ),
      GoRoute(
        path: '/inventory/report',
        builder: (context, state) => const InventoryReportScreen(),
      ),
      GoRoute(
        path: '/striking-groups',
        builder: (context, state) => const StrikingGroupsScreen(),
      ),
      GoRoute(
        path: '/loading-groups',
        builder: (context, state) => const LoadingGroupsScreen(),
      ),
      GoRoute(
        path: '/masters/brick-types',
        builder: (context, state) => const BrickTypesScreen(),
      ),
      GoRoute(
        path: '/masters/brick-sizes',
        builder: (context, state) => const BrickSizesScreen(),
      ),
      GoRoute(
        path: '/masters/design-patterns',
        builder: (context, state) => const DesignPatternsScreen(),
      ),
      GoRoute(
        path: '/masters/parties',
        builder: (context, state) => const MasterManagementScreen(
          resource: 'parties',
          title: 'Parties',
          fields: ['name', 'mobile', 'address'],
        ),
      ),
      GoRoute(
        path: '/masters/vehicles',
        builder: (context, state) => const MasterManagementScreen(
          resource: 'vehicles',
          title: 'Vehicles',
          fields: ['registration_number', 'type'],
        ),
      ),
      GoRoute(
        path: '/masters/drivers',
        builder: (context, state) => const MasterManagementScreen(
          resource: 'drivers',
          title: 'Drivers',
          fields: ['name', 'mobile', 'license_number'],
        ),
      ),
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text(state.error.toString()))),
  );
});

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}
