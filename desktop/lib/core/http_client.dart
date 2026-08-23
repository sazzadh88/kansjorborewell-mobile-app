import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/services.dart';

Future<SecurityContext> buildTrustedContext() async {
  final ctx = SecurityContext(withTrustedRoots: true);
  for (final asset in [
    'assets/certs/isrg-root-x1.pem',
    'assets/certs/isrg-root-x2.pem',
  ]) {
    try {
      final bytes = await rootBundle.load(asset);
      ctx.setTrustedCertificatesBytes(bytes.buffer.asUint8List());
    } catch (_) {}
  }
  return ctx;
}

IOHttpClientAdapter buildTrustedAdapter(SecurityContext context) =>
    IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient(context: context);
        client.badCertificateCallback = null;
        return client;
      },
    );
