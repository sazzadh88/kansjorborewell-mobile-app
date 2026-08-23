import 'package:dio/dio.dart';

import 'models.dart';
import 'token_store.dart';

class ApiClient {
  ApiClient({
    required String baseUrl,
    required TokenStore storage,
    Dio? dio,
    Future<String> Function(String fileName, String content)? saveCsv,
  }) : _storage = storage,
       baseUrl = baseUrl,
       _saveCsv = saveCsv,
       dio = dio ?? _buildDio(baseUrl) {
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          options.headers['Accept'] = 'application/json';
          handler.next(options);
        },
      ),
    );
  }

  final Dio dio;
  final String baseUrl;
  final TokenStore _storage;
  final Future<String> Function(String fileName, String content)? _saveCsv;

  static Dio _buildDio(String baseUrl) => Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    ),
  );

  Future<Map<String, dynamic>> login(String mobile, String password) async {
    final response = await dio.post(
      '/login',
      data: {'mobile': mobile, 'password': password},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final token = data['token'];
    if (token is! String || token.isEmpty) {
      throw const ApiException(
        'The server returned an invalid login response.',
      );
    }
    await _storage.write(key: 'auth_token', value: token);
    return data;
  }

  Future<void> logout() async {
    try {
      await dio.post('/logout');
    } finally {
      await _storage.delete(key: 'auth_token');
    }
  }

  Future<bool> hasToken() async =>
      await _storage.read(key: 'auth_token') != null;

  Future<Map<String, dynamic>> me() async =>
      Map<String, dynamic>.from((await dio.get('/me')).data as Map);

  Future<Map<String, dynamic>> dashboard() async => Map<String, dynamic>.from(
    (await dio.get('/dashboard/summary')).data as Map,
  );

  Future<List<Map<String, dynamic>>> listResource(String path) async {
    final response = await dio.get(path);
    final raw = response.data;
    final items = raw is Map<String, dynamic> ? (raw['data'] ?? raw) : raw;
    if (items is! List) {
      throw const ApiException('The server returned an invalid list response.');
    }
    return items.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<PaginatedResponse> paginatedResource(String path) async {
    final response = await dio.get(path);
    final raw = Map<String, dynamic>.from(response.data as Map);
    final items = raw['data'];
    if (items is! List) {
      throw const ApiException(
        'The server returned an invalid paginated response.',
      );
    }
    final meta = raw['meta'] is Map
        ? Map<String, dynamic>.from(raw['meta'] as Map)
        : raw;
    return PaginatedResponse(
      items: items
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
      currentPage: (meta['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? 1,
      total: (meta['total'] as num?)?.toInt() ?? items.length,
    );
  }

  Future<void> createProduction(Map<String, dynamic> payload) async {
    await dio.post('/production-entries', data: payload);
  }

  Future<void> updateProduction(int id, Map<String, dynamic> payload) async {
    await dio.patch('/production-entries/$id', data: payload);
  }

  Future<void> deleteProduction(int id) async {
    await dio.delete('/production-entries/$id');
  }

  Future<void> createDispatch(Map<String, dynamic> payload) async {
    await dio.post('/dispatches', data: payload);
  }

  Future<void> updateDispatch(int id, Map<String, dynamic> payload) async {
    await dio.patch('/dispatches/$id', data: payload);
  }

  Future<void> deleteDispatch(int id) async {
    await dio.delete('/dispatches/$id');
  }

  Future<PaginatedResponse> listProduction({
    String? from,
    String? to,
    int page = 1,
    int perPage = 20,
  }) async => paginatedResource(
    _query('/production-entries', from: from, to: to, page: page, perPage: perPage),
  );

  Future<PaginatedResponse> listDispatch({
    String? from,
    String? to,
    int page = 1,
    int perPage = 20,
  }) async => paginatedResource(
    _query('/dispatches', from: from, to: to, page: page, perPage: perPage),
  );

  Future<PaginatedResponse> listStrikingGroups({
    String? from,
    String? to,
    int page = 1,
    int perPage = 20,
  }) async => paginatedResource(
    _query('/striking-groups', from: from, to: to, page: page, perPage: perPage),
  );

  Future<void> createStrikingGroup(Map<String, dynamic> payload) async {
    await dio.post('/striking-groups', data: payload);
  }

  Future<void> updateStrikingGroup(int id, Map<String, dynamic> payload) async {
    await dio.patch('/striking-groups/$id', data: payload);
  }

  Future<void> deleteStrikingGroup(int id) async {
    await dio.delete('/striking-groups/$id');
  }

  Future<PaginatedResponse> listLoadingGroups({
    String? from,
    String? to,
    int page = 1,
    int perPage = 20,
  }) async => paginatedResource(
    _query('/loading-groups', from: from, to: to, page: page, perPage: perPage),
  );

  Future<void> createLoadingGroup(Map<String, dynamic> payload) async {
    await dio.post('/loading-groups', data: payload);
  }

  Future<void> updateLoadingGroup(int id, Map<String, dynamic> payload) async {
    await dio.patch('/loading-groups/$id', data: payload);
  }

  Future<void> deleteLoadingGroup(int id) async {
    await dio.delete('/loading-groups/$id');
  }

  String _query(
    String path, {
    String? from,
    String? to,
    required int page,
    int perPage = 20,
  }) {
    final params = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
    };
    if (from != null && to != null) {
      params['from'] = from;
      params['to'] = to;
    }
    return '$path?${params.entries.map((entry) => '${entry.key}=${entry.value}').join('&')}';
  }

  Future<List<Map<String, dynamic>>> staff() async => listResource('/staff');

  Future<List<Map<String, dynamic>>> staffRoles() async =>
      listResource('/staff/roles');

  Future<List<DesignModel>> designs({String? size, bool all = false}) async {
    final query = [
      if (size != null) 'size=$size',
      if (all) 'all=1',
    ];
    final suffix = query.isEmpty ? '' : '?${query.join('&')}';
    final items = await listResource('/designs$suffix');
    return items.map(DesignModel.fromJson).toList();
  }

  Future<void> createDesign(Map<String, dynamic> payload) async =>
      dio.post('/designs', data: payload);

  Future<void> updateDesign(int id, Map<String, dynamic> payload) async =>
      dio.patch('/designs/$id', data: payload);

  Future<void> deleteDesign(int id) async => dio.delete('/designs/$id');

  Future<GstReport> gstReport({String? from, String? to}) async {
    final params = <String, String>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    final query = params.isEmpty ? '' : '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final response = await dio.get('/reports/gst$query');
    return GstReport.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<DispatchDues> dispatchDues() async {
    final response = await dio.get('/reports/dispatch-dues');
    return DispatchDues.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<List<RoleModel>> manageRoles() async {
    final items = await listResource('/roles');
    return items.map(RoleModel.fromJson).toList();
  }

  Future<List<PermissionModel>> permissions() async {
    final items = await listResource('/permissions');
    return items.map(PermissionModel.fromJson).toList();
  }

  Future<void> createRole(
    String name,
    List<String> permissions,
  ) async => dio.post('/roles', data: {'name': name, 'permissions': permissions});

  Future<void> updateRole(int id, String name) async =>
      dio.patch('/roles/$id', data: {'name': name});

  Future<void> deleteRole(int id) async => dio.delete('/roles/$id');

  Future<void> syncRolePermissions(
    int id,
    List<String> permissions,
  ) async => dio.put('/roles/$id/permissions', data: {'permissions': permissions});

  Future<void> createStaff(Map<String, dynamic> payload) async =>
      dio.post('/staff', data: payload);

  Future<void> updateStaff(int id, Map<String, dynamic> payload) async =>
      dio.patch('/staff/$id', data: payload);

  Future<void> deleteStaff(int id) async => dio.delete('/staff/$id');

  Future<List<Map<String, dynamic>>> brickSizes() async =>
      listResource('/brick-sizes');

  Future<void> createBrickSize(Map<String, dynamic> payload) async =>
      dio.post('/brick-sizes', data: payload);

  Future<void> updateBrickSize(int id, Map<String, dynamic> payload) async =>
      dio.patch('/brick-sizes/$id', data: payload);

  Future<void> deleteBrickSize(int id) async =>
      dio.delete('/brick-sizes/$id');

  Future<void> updateProfile(Map<String, dynamic> payload) async =>
      dio.patch('/me', data: payload);

  Future<void> createMaster(
    String resource,
    Map<String, dynamic> payload,
  ) async => dio.post('/$resource', data: payload);

  Future<void> updateMaster(
    String resource,
    int id,
    Map<String, dynamic> payload,
  ) async => dio.patch('/$resource/$id', data: payload);

  Future<void> deleteMaster(String resource, int id) async {
    await dio.delete('/$resource/$id');
  }

  Future<List<Map<String, dynamic>>> rawMaterials() async =>
      listResource('/raw-materials');

  Future<void> stockInRawMaterial(int id, Map<String, dynamic> payload) async =>
      dio.post('/raw-materials/$id/stock-in', data: payload);

  Future<void> stockOutRawMaterial(
    int id,
    Map<String, dynamic> payload,
  ) async => dio.post('/raw-materials/$id/stock-out', data: payload);

  Future<PaginatedResponse> inventoryReport({
    String? from,
    String? to,
    int page = 1,
    int perPage = 20,
  }) async => paginatedResource(
    _query('/reports/inventory', from: from, to: to, page: page, perPage: perPage),
  );

  Future<String> _exportCsv(String path, {required String from, required String to}) async {
    final response = await dio.get(
      '$path?from=$from&to=$to',
      options: Options(
        responseType: ResponseType.plain,
        validateStatus: (status) => status != null && status >= 200 && status < 400,
      ),
    );
    return response.data.toString();
  }

  Future<String> exportInventoryCsv({
    required String from,
    required String to,
  }) => _exportCsv('/reports/inventory/export', from: from, to: to);

  Future<String> exportGstCsv({
    required String from,
    required String to,
  }) => _exportCsv('/reports/gst/export', from: from, to: to);

  Future<String> exportCsv(
    String resource, {
    required String from,
    required String to,
  }) => _exportCsv('/$resource/export', from: from, to: to);

  Future<String> saveCsvToDownloads(String fileName, String content) async {
    final saver = _saveCsv;
    if (saver == null) {
      throw const ApiException(
        'CSV saving is not configured for this platform.',
      );
    }
    try {
      return await saver(fileName, content);
    } catch (_) {
      throw const ApiException(
        'The report was generated but could not be saved. '
        'Check that the app can write to your Downloads folder.',
      );
    }
  }
}

class PaginatedResponse {
  const PaginatedResponse({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<Map<String, dynamic>> items;
  final int currentPage;
  final int lastPage;
  final int total;
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

String apiErrorMessage(Object error) {
  if (error is ApiException) return error.message;
  if (error is DioException) {
    final responseData = error.response?.data;
    final responseMessage = responseData is Map
        ? responseData['message']
        : null;
    if (responseMessage is String && responseMessage.isNotEmpty) {
      return responseMessage;
    }
    if (error.response?.statusCode != null) {
      final statusCode = error.response!.statusCode;
      final body = error.response?.data;
      if (body is String && body.isNotEmpty && body.length < 500) {
        return 'API error ($statusCode): $body';
      }
      return 'API request failed ($statusCode).';
    }
    final underlying = error.error?.toString();
    final detail = underlying != null && underlying.isNotEmpty && underlying != 'null'
        ? ' ($underlying)'
        : '';
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'The server took too long to respond. Check that the API is running and try again.$detail',
      DioExceptionType.connectionError =>
        'Cannot reach the API. Check your internet connection or allow the app through Windows Firewall/Defender.$detail',
      _ => 'The API request failed. Please try again.$detail',
    };
  }
  return 'The API request failed. Please try again.';
}
