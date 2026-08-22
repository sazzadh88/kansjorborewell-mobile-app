import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<String> saveFilePlatform(
  String fileName,
  Uint8List bytes,
  String mimeType,
) async {
  Directory? dir;
  try {
    dir = await getDownloadsDirectory();
    if (dir != null) {
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file.path;
    }
  } catch (_) {
    // Fall through to documents directory.
  }

  final documents = await getApplicationDocumentsDirectory();
  final file = File('${documents.path}/$fileName');
  await file.writeAsBytes(bytes);
  return file.path;
}
