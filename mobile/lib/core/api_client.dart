import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

export 'package:core/core.dart';

class SecureTokenStore implements TokenStore {
  const SecureTokenStore();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

const _downloadsChannel = MethodChannel('jp_bricks/downloads');

Future<String> _saveCsvToDownloads(String fileName, String content) async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    final path = await _downloadsChannel.invokeMethod<String>('saveCsv', {
      'fileName': fileName,
      'content': content,
    });
    return path ?? fileName;
  }
  throw const ApiException('CSV downloads are currently supported on Android.');
}

ApiClient buildMobileApiClient() => ApiClient(
  baseUrl: const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://app.kansjorborewell.in/api',
    // defaultValue: 'http://192.168.0.40:8000/api',
  ),
  storage: const SecureTokenStore(),
  saveCsv: _saveCsvToDownloads,
);
