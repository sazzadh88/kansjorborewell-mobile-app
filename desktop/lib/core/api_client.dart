import 'package:core/core.dart';
import 'package:dio/dio.dart';

import 'file_saver.dart';
import 'http_client.dart';
import 'token_store.dart';

/// Reads API base URL from the compile-time environment variable `API_BASE_URL`.
/// Defaults to local server for dev or production URL.
String desktopApiBaseUrl() {
  const fromDefine = String.fromEnvironment('API_BASE_URL');
  if (fromDefine.isNotEmpty) return fromDefine;
  return 'https://app.kansjorborewell.in/api';
}

ApiClient buildDesktopApiClient({Dio? dio}) => ApiClient(
  baseUrl: desktopApiBaseUrl(),
  storage: const SharedPreferencesTokenStore(),
  dio: dio,
  saveCsv: (fileName, content) => saveCsvFile(fileName, content),
);

Future<ApiClient> buildTrustedDesktopApiClient() async {
  final ctx = await buildTrustedContext();
  final dio = Dio(
    BaseOptions(
      baseUrl: desktopApiBaseUrl(),
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      validateStatus: (status) => status != null && status >= 200 && status < 300,
    ),
  )..httpClientAdapter = buildTrustedAdapter(ctx);
  return buildDesktopApiClient(dio: dio);
}
