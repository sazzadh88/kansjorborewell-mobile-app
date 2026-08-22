import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';

import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/production_screen.dart';
import '../screens/dispatch_screen.dart';
import '../screens/ledger_screen.dart';
import '../screens/inventory_screen.dart';
import '../screens/striking_groups_screen.dart';
import '../screens/loading_groups_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/masters_screen.dart';
import '../screens/roles_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);
  final authNotifier = ref.read(authProvider.notifier);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: _AuthRefresh(ref),
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isLogin = location == '/login';

      if (!authNotifier.hasBootstrapped) return null;
      if (auth.value == null) {
        return isLogin ? null : '/login';
      }
      if (isLogin) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => const NoTransitionPage(child: LoginScreen()),
      ),
      GoRoute(
        path: '/dashboard',
        pageBuilder: (context, state) => const NoTransitionPage(child: DashboardScreen()),
      ),
      GoRoute(
        path: '/production',
        pageBuilder: (context, state) => const NoTransitionPage(child: ProductionScreen()),
      ),
      GoRoute(
        path: '/dispatch',
        pageBuilder: (context, state) => const NoTransitionPage(child: DispatchScreen()),
      ),
      GoRoute(
        path: '/ledger',
        pageBuilder: (context, state) => const NoTransitionPage(child: LedgerScreen()),
      ),
      GoRoute(
        path: '/inventory',
        pageBuilder: (context, state) => const NoTransitionPage(child: InventoryScreen()),
      ),
      GoRoute(
        path: '/striking-groups',
        pageBuilder: (context, state) => const NoTransitionPage(child: StrikingGroupsScreen()),
      ),
      GoRoute(
        path: '/loading-groups',
        pageBuilder: (context, state) => const NoTransitionPage(child: LoadingGroupsScreen()),
      ),
      GoRoute(
        path: '/reports',
        pageBuilder: (context, state) => const NoTransitionPage(child: ReportsScreen()),
      ),
      GoRoute(
        path: '/masters',
        pageBuilder: (context, state) => const NoTransitionPage(child: MastersScreen()),
      ),
      GoRoute(
        path: '/roles',
        pageBuilder: (context, state) => const NoTransitionPage(child: RolesScreen()),
      ),
    ],
  );
});

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}
