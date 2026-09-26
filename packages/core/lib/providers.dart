import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'models.dart';

/// Each app overrides this provider with its own configured [ApiClient].
final apiClientProvider = Provider<ApiClient>((ref) {
  throw StateError('apiClientProvider must be overridden by the host app.');
});

final authProvider = AsyncNotifierProvider<AuthNotifier, UserModel?>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<UserModel?> {
  bool _hasBootstrapped = false;
  bool get hasBootstrapped => _hasBootstrapped;

  @override
  Future<UserModel?> build() async {
    final api = ref.read(apiClientProvider);
    try {
      if (!await api.hasToken()) return null;
      final data = await api.me();
      return UserModel.fromJson(
        data['user'] as Map<String, dynamic>,
        permissions: (data['permissions'] as List?) ?? const [],
      );
    } catch (_) {
      await api.logout();
      return null;
    } finally {
      _hasBootstrapped = true;
    }
  }

  Future<void> login(String mobile, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final data = await ref.read(apiClientProvider).login(mobile, password);
      return UserModel.fromJson(
        data['user'] as Map<String, dynamic>,
        permissions: (data['permissions'] as List?) ?? const [],
      );
    });
  }

  Future<void> logout() async {
    await ref.read(apiClientProvider).logout();
    state = const AsyncData(null);
  }
}

final dashboardProvider = FutureProvider.autoDispose<DashboardSummary>((
  ref,
) async {
  final data = await ref.read(apiClientProvider).dashboard();
  return DashboardSummary.fromJson(data);
});

final brickTypesProvider = FutureProvider.autoDispose<List<BrickTypeModel>>((
  ref,
) async {
  final items = await ref.read(apiClientProvider).listResource('/brick-types');
  return items.map(BrickTypeModel.fromJson).toList();
});

final designsProvider = FutureProvider.autoDispose<List<DesignModel>>(
  (ref) => ref.read(apiClientProvider).designs(all: true),
);

final brickSizesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((
  ref,
) => ref.read(apiClientProvider).brickSizes());

final gstReportProvider = FutureProvider.autoDispose
    .family<GstReport, ({String? from, String? to})>((
      ref,
      query,
    ) async {
      return ref
          .read(apiClientProvider)
          .gstReport(from: query.from, to: query.to);
    });

final dispatchDuesProvider = FutureProvider.autoDispose<DispatchDues>(
  (ref) => ref.read(apiClientProvider).dispatchDues(),
);

final machinesProvider = FutureProvider.autoDispose<List<MachineModel>>((
  ref,
) async {
  final items = await ref.read(apiClientProvider).listResource('/machines');
  return items.map(MachineModel.fromJson).toList();
});

final rawMaterialsProvider = FutureProvider.autoDispose<List<RawMaterialModel>>(
  (ref) async {
    final items = await ref
        .read(apiClientProvider)
        .listResource('/raw-materials');
    return items.map(RawMaterialModel.fromJson).toList();
  },
);

final inventoryReportProvider = FutureProvider.autoDispose
    .family<PaginatedInventory, ({String? from, String? to, int page})>((
      ref,
      query,
    ) async {
      final response = await ref
          .read(apiClientProvider)
          .inventoryReport(from: query.from, to: query.to, page: query.page);
      return PaginatedInventory(
        items: response.items.map(InventoryTransactionModel.fromJson).toList(),
        currentPage: response.currentPage,
        lastPage: response.lastPage,
        total: response.total,
      );
    });

final vehiclesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.read(apiClientProvider).listResource('/vehicles'),
);
final driversProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.read(apiClientProvider).listResource('/drivers'),
);
final partiesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.read(apiClientProvider).listResource('/parties'),
);

final productionRecordsProvider = FutureProvider.autoDispose
    .family<PaginatedProduction, ({String? from, String? to, int page})>((
      ref,
      query,
    ) async {
      final response = await ref
          .read(apiClientProvider)
          .listProduction(from: query.from, to: query.to, page: query.page);
      return PaginatedProduction(
        items: response.items.map(ProductionRecord.fromJson).toList(),
        currentPage: response.currentPage,
        lastPage: response.lastPage,
        total: response.total,
      );
    });

final dispatchRecordsProvider = FutureProvider.autoDispose
    .family<PaginatedDispatch, ({String? from, String? to, int page})>((
      ref,
      query,
    ) async {
      final response = await ref
          .read(apiClientProvider)
          .listDispatch(from: query.from, to: query.to, page: query.page);
      return PaginatedDispatch(
        items: response.items.map(DispatchRecord.fromJson).toList(),
        currentPage: response.currentPage,
        lastPage: response.lastPage,
        total: response.total,
      );
    });

final strikingGroupsProvider = FutureProvider.autoDispose
    .family<PaginatedStrikingGroups, ({String? from, String? to, int page})>((
      ref,
      query,
    ) async {
      final response = await ref
          .read(apiClientProvider)
          .listStrikingGroups(from: query.from, to: query.to, page: query.page);
      return PaginatedStrikingGroups(
        items: response.items.map(StrikingGroupRecord.fromJson).toList(),
        currentPage: response.currentPage,
        lastPage: response.lastPage,
        total: response.total,
      );
    });

final loadingGroupsProvider = FutureProvider.autoDispose
    .family<PaginatedLoadingGroups, ({String? from, String? to, int page})>((
      ref,
      query,
    ) async {
      final response = await ref
          .read(apiClientProvider)
          .listLoadingGroups(from: query.from, to: query.to, page: query.page);
      return PaginatedLoadingGroups(
        items: response.items.map(LoadingGroupRecord.fromJson).toList(),
        currentPage: response.currentPage,
        lastPage: response.lastPage,
        total: response.total,
      );
    });

final staffProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.read(apiClientProvider).staff(),
);
final rolesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.read(apiClientProvider).staffRoles(),
);
final manageRolesProvider = FutureProvider.autoDispose<List<RoleModel>>(
  (ref) => ref.read(apiClientProvider).manageRoles(),
);
final permissionsProvider = FutureProvider.autoDispose<List<PermissionModel>>(
  (ref) => ref.read(apiClientProvider).permissions(),
);
