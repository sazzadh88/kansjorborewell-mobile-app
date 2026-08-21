import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  ApiClient({Dio? dio, FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage(),
      dio = dio ?? _buildDio() {
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
  final FlutterSecureStorage _storage;

  static Dio _buildDio() => Dio(
    BaseOptions(
      baseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'https://app.kansjorborewell.in/api',
      ),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
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
  }) async => paginatedResource(
    _query('/production-entries', from: from, to: to, page: page),
  );

  Future<PaginatedResponse> listDispatch({
    String? from,
    String? to,
    int page = 1,
  }) async =>
      paginatedResource(_query('/dispatches', from: from, to: to, page: page));

  String _query(String path, {String? from, String? to, required int page}) {
    final params = <String, String>{'page': '$page', 'per_page': '20'};
    if (from != null && to != null) {
      params['from'] = from;
      params['to'] = to;
    }
    return '$path?${params.entries.map((entry) => '${entry.key}=${entry.value}').join('&')}';
  }

  Future<List<Map<String, dynamic>>> staff() async => listResource('/staff');

  Future<List<Map<String, dynamic>>> roles() async =>
      listResource('/staff/roles');

  Future<void> createStaff(Map<String, dynamic> payload) async =>
      dio.post('/staff', data: payload);

  Future<void> updateStaff(int id, Map<String, dynamic> payload) async =>
      dio.patch('/staff/$id', data: payload);

  Future<void> deleteStaff(int id) async => dio.delete('/staff/$id');

  Future<void> updateProfile(Map<String, dynamic> payload) async =>
      dio.patch('/me', data: payload);

  Future<void> createMaster(
    String resource,
    Map<String, dynamic> payload,
  ) async => dio.post('/$resource', data: payload);

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
  }) async => paginatedResource(
    _query('/reports/inventory', from: from, to: to, page: page),
  );

  Future<String> exportInventoryCsv({
    required String from,
    required String to,
  }) async {
    final response = await dio.get(
      '/reports/inventory/export?from=$from&to=$to',
      options: Options(responseType: ResponseType.plain),
    );
    return response.data.toString();
  }

  Future<String> exportCsv(
    String resource, {
    required String from,
    required String to,
  }) async {
    final response = await dio.get(
      '/$resource/export?from=$from&to=$to',
      options: Options(responseType: ResponseType.plain),
    );
    return response.data.toString();
  }

  Future<void> updateMaster(
    String resource,
    int id,
    Map<String, dynamic> payload,
  ) async => dio.patch('/$resource/$id', data: payload);

  Future<void> deleteMaster(String resource, int id) async {
    await dio.delete('/$resource/$id');
  }

  Future<String> saveCsvToDownloads(String fileName, String content) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final path = await _downloadsChannel.invokeMethod<String>('saveCsv', {
        'fileName': fileName,
        'content': content,
      });
      return path ?? fileName;
    }
    throw const ApiException(
      'CSV downloads are currently supported on Android.',
    );
  }

  static const _downloadsChannel = MethodChannel('jp_bricks/downloads');
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
      return 'API request failed (${error.response!.statusCode}).';
    }
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'The server took too long to respond. Check that the API is running and try again.',
      DioExceptionType.connectionError =>
        'Cannot reach the API. Check the server address and your network connection.',
      _ => 'The API request failed. Please try again.',
    };
  }
  return 'The API request failed. Please try again.';
}
