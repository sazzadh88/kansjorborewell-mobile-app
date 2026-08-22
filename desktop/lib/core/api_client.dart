import 'package:core/core.dart';

import 'file_saver.dart';
import 'token_store.dart';

/// Reads API base URL from the compile-time environment variable `API_BASE_URL`.
/// Defaults to local server for dev or production URL.
String desktopApiBaseUrl() {
  const fromDefine = String.fromEnvironment('API_BASE_URL');
  if (fromDefine.isNotEmpty) return fromDefine;
  return 'http://127.0.0.1:8000/api';
}

ApiClient buildDesktopApiClient() => ApiClient(
  baseUrl: desktopApiBaseUrl(),
  storage: const SharedPreferencesTokenStore(),
  saveCsv: (fileName, content) => saveCsvFile(fileName, content),
);
