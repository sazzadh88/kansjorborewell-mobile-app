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
import '../features/masters/master_management_screen.dart';
import '../features/profile/profile_edit_screen.dart';
import '../features/profile/profile_screen.dart';
import 'models.dart';
import 'providers.dart';

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
      return isSplash || isLogin ? '/dashboard' : null;
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
        path: '/inventory',
        builder: (context, state) => const InventoryScreen(),
      ),
      GoRoute(
        path: '/inventory/report',
        builder: (context, state) => const InventoryReportScreen(),
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
