import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:mobile/core/providers.dart';
import 'package:mobile/features/dashboard/dashboard_screen.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<UserModel?> build() async => const UserModel(
    id: 1,
    name: 'Test User',
    mobile: '9999999999',
    role: 'admin',
    permissions: {'products.view', 'production.view', 'dispatch.view'},
  );
}

void main() {
  test('DashboardSummary.fromJson parses string numbers safely', () {
    final json = {
      'date': '2026-08-21',
      'production_qty': '15000',
      'sale_qty': '5000',
      'brick_types': [
        {
          'id': '1',
          'name': 'Fly Ash 9x4x3',
          'code': 'FA-943',
          'current_stock': '25000',
          'reorder_level': '5000',
        },
        {
          'id': 2,
          'name': 'Solid Block',
          'code': 'SB-100',
          'current_stock': -10,
          'reorder_level': 0,
        },
      ],
    };

    final summary = DashboardSummary.fromJson(json);
    expect(summary.date, '2026-08-21');
    expect(summary.productionQty, 15000);
    expect(summary.saleQty, 5000);
    expect(summary.brickTypes.length, 2);
    expect(summary.brickTypes[0].currentStock, 25000);
    expect(summary.brickTypes[1].currentStock, -10);
    expect(summary.brickTypes[1].reorderLevel, 0);
  });

  testWidgets('DashboardScreen renders safely with empty user and edge data', (
    tester,
  ) async {
    final mockSummary = DashboardSummary.fromJson({
      'date': '2026-08-21',
      'production_qty': 0,
      'sale_qty': 0,
      'brick_types': [
        {
          'id': 1,
          'name': 'Brick A',
          'code': 'BA',
          'current_stock': 0,
          'reorder_level': 0,
        },
      ],
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith((ref) async => mockSummary),
          authProvider.overrideWith(_FakeAuthNotifier.new),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Overview'), findsWidgets);
    expect(find.text('Factory control room'), findsOneWidget);
    expect(find.text('Brick A'), findsOneWidget);
  });
}
