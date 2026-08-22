import 'dart:typed_data';

Future<String> saveFilePlatform(
  String fileName,
  Uint8List bytes,
  String mimeType,
) async {
  throw UnsupportedError('Saving files is not supported on this platform.');
}
