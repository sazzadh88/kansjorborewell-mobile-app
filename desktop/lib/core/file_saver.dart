import 'dart:convert';

import 'file_saver_stub.dart'
    if (dart.library.js_interop) 'file_saver_web.dart'
    if (dart.library.io) 'file_saver_io.dart';

/// Saves or downloads CSV file with [fileName] and [content]
Future<String> saveCsvFile(String fileName, String content) async {
  return saveFilePlatform(fileName, utf8.encode(content), 'text/csv');
}
